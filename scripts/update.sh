#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
exec 9>.update.lock
flock -n 9 || { echo 'Another update is running'; exit 1; }
# Operator must first git pull --ff-only. Do not reset their local changes.
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || { echo 'Tracked files have local changes'; exit 1; }
version="$(git rev-parse --short=12 HEAD)"
image="tgpt-slava:$version"
previous=''
if [[ -f .runtime.env ]]; then
  previous="$(sed -n 's/^TGPT_IMAGE=//p' .runtime.env)"
fi
if [[ -z "$previous" ]]; then
  cid="$(docker compose ps -q reader)"
  if [[ -n "$cid" ]]; then previous="$(docker inspect --format '{{.Config.Image}}' "$cid")"; fi
fi
# An identical update must not discard the older rollback image.
if [[ "$previous" == "$image" ]]; then
  TGPT_IMAGE="$image" docker compose up -d --no-deps --wait --wait-timeout 120 reader
  echo 'This revision is already installed. Rollback image preserved.'
  exit 0
fi
bash scripts/build.sh "$version"
if ! TGPT_IMAGE="$image" docker compose up -d --no-deps --wait --wait-timeout 120 reader; then
  if [[ "$previous" =~ ^tgpt-slava:[a-zA-Z0-9_.-]+$ ]]; then
    TGPT_IMAGE="$previous" docker compose up -d --no-deps reader
  fi
  echo 'Update failed; previous image kept. Inspect service health.'
  exit 1
fi
umask 077
printf 'TGPT_IMAGE=%s\n' "$image" > .runtime.env.tmp
mv .runtime.env.tmp .runtime.env
# Never prune shared Docker volumes/images/caches. Only remove our own old tags.
while IFS= read -r tag; do
  [[ "$tag" == "$image" || "$tag" == "$previous" ]] && continue
  [[ "$tag" =~ ^tgpt-slava:[a-zA-Z0-9_.-]+$ ]] || continue
  docker image rm "$tag" || true
 done < <(docker image ls --filter label=io.tgpt.app=tgpt-slava --format '{{.Repository}}:{{.Tag}}')
echo 'Updated. Current and previous images kept. Other projects were not touched.'
