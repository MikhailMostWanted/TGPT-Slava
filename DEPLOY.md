# Развёртывание TGPT Slava на собственном VPS

Документ для Славы или его Codex. Никаких зависимостей от инфраструктуры Михаила. Все ниже — **рекомендации для нового VPS под контролем Славы**. Ничего из этого не выполняется автоматически в GitHub.

## 0. Предварительные условия

- Linux VPS (рекомендуется Ubuntu 24.04), рабочие SSH и доступ в интернет к Telegram/GitHub; желательно минимум 1 ГБ RAM плюс память для ОС.
- Docker Engine, Docker Compose v2, Docker Buildx (команды `docker version`, `docker compose version`, `docker buildx version`). При отсутствии — установить из официальной инструкции https://docs.docker.com/engine/install/ubuntu/.
- Свой домен с A/AAAA-записью на VPS и работающим HTTPS. Если настроен IPv6 AAAA, соответствующий сервер должен быть доступен по IPv6.
- Свой GitHub-аккаунт, GitHub OAuth App и Telegram API credentials (не BotFather token).
- Никаких перенесённых сессий, конфигураций и ключей другого человека.

## 1. Скачивание и сборка

```bash
git clone https://github.com/MikhailMostWanted/TGPT-Slava.git
cd TGPT-Slava
sudo install -d -m 700 -o 10001 -g 10001 config data
bash scripts/build.sh local
```

Внутри контейнера пользователь UID/GID `10001:10001`. Каталоги создаются до входа. Не запускать контейнер от root ради обхода ошибок доступа. Сервис `reader` слушает только `127.0.0.1:18765` на хосте, не публикует Telegram наружу.

## 2. Приватная настройка

В https://my.telegram.org → **API development tools** выпусти собственные `api_id` (число) и `api_hash` (32 шестнадцатеричных символа).

В https://github.com/settings/developers → **OAuth Apps** → **New OAuth App**:
- Application name: `TGPT Slava` (или произвольное).
- Homepage URL: `https://ТВОЙ-ДОМЕН`.
- Authorization callback URL: `https://ТВОЙ-ДОМЕН/auth/callback`.
- Сохрани Client ID и Client Secret только приватно. Не передавай их в ChatGPT или GitHub issues.

Узнай **числовой GitHub ID своего аккаунта**:
- `gh api user --jq .id` (если авторизован GitHub CLI), или
- открой `https://api.github.com/users/ТВОЙ_ЛОГИН` и посмотри поле `id`.

Далее:

```bash
docker compose run --rm -it setup init
docker compose run --rm -it setup login
```

`init` спросит публичный HTTPS URL **без /mcp**, api_id, api_hash, OAuth ID/secret, собственный numeric GitHub ID, часовой пояс и разрешение на чтение чатов. Выбирая доступ ко всем чатам, ты открываешь ИИ все обычные облачные переписки аккаунта: сознательно подтверждай этот выбор; по умолчанию доступ ограничен. Для ограничения отдельных чатов введи их numeric ID после определения.

`login` спросит телефон с кодом страны, одноразовый код из Telegram/SMS и, при необходимости, пароль двухэтапной защиты; ввод происходит скрыто **в твоём терминале VPS**. После входа убедись, что вошёл именно в свой аккаунт, и подтвердите это. Код и пароль не передавать Codex текстом. Сессия сохранится в `data/telegram.session`.

Если требуется повторный логин, сначала `docker compose stop reader`; затем `docker compose run --rm -it setup login` и снова запусти `reader`. Одновременное использование одной сессии двумя процессами запрещено.

## 3. HTTPS: выбор ОДНОГО варианта

**Вариант А: чистый VPS, порты 80/443 свободны.** Укажи свой домен в `.env`:

```bash
cp .env.example .env
nano .env
# замени MCP_DOMAIN=tgpt.example.com на реальный домен
docker compose --profile https up -d reader caddy
docker compose --profile https ps
```

Caddy получает сертификат автоматически при корректном DNS и доступных 80/443. Убедись, что они открыты в согласованном firewall VPS. Не поднимай Caddy вторым экземпляром поверх существующего.

**Вариант Б: уже есть HTTPS Caddy/Nginx на хосте.** Не запускай сервис `caddy` из Compose. Направь существующий прокси для своего отдельного домена на `http://127.0.0.1:18765` (проброс в Compose уже ограничен loopback). Запусти `docker compose up -d reader`. Не включай URL access logs с OAuth-кодами.

**Вариант В: прокси живёт в Docker.** Его `127.0.0.1` — не хост. Сделай отдельный приватный network и Compose override или добавь контейнер reader в существующую сеть прокси. Назначь уникальное имя `tgpt-slava` и проксируй на `tgpt-slava:8000`; не публикуй 8000 наружу, не монтируй Docker socket и чужие volumes. Сохрани override локально и всегда используй при обновлении.

## 4. Проверки

```bash
docker compose ps
docker compose logs --tail=30 reader
curl -fsS http://127.0.0.1:18765/healthz
curl -fsS https://ТВОЙ-ДОМЕН/healthz
curl -fsS https://ТВОЙ-ДОМЕН/.well-known/oauth-authorization-server
curl -sS -o /dev/null -w '%{http_code}\n' -X POST \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' \
  https://ТВОЙ-ДОМЕН/mcp
```

Ожидания: `/healthz` возвращает `{"status":"ok"}`; OAuth discovery рекламирует `S256` и `registration_endpoint`; запрос MCP без OAuth получает **401**, а не список чатов. Не публикуй OAuth access logs или отладочные трассы.

## 5. Подключение ChatGPT

В веб-интерфейсе https://chatgpt.com/plugins нажми **+ → Добавить собственный MCP-сервер** (если пункт есть у твоего аккаунта).

- Имя: `TGPT Slava`.
- Адрес сервера: `https://ТВОЙ-ДОМЕН/mcp`.
- Аутентификация: **OAuth**, динамическая регистрация **DCR** (если предоставлен выбор; *не* «без авторизации»).
- Пройди перенаправление **через свой GitHub**, разреши `read:user`; установи/активируй созданный плагин.
- При ошибке redirect URI не ставь `*`: внеси **точный** callback ChatGPT в приватное поле `client_redirect_uris` внутри `config/config.json`, перезапусти reader. OAuth callback GitHub на `/auth/callback` менять не нужно.

Доступность пользовательских MCP и расположение настроек Plus могут изменяться. Если опции нет, проверь актуальные ограничения плана и инструкции https://developers.openai.com/api/docs/guides/custom-mcp-server. **Не отключай OAuth**, чтобы обойти ограничение.

Тест внутри ChatGPT: `get_profile`, затем `list_chats` и `get_chat_history` на одном безопасном чате, который выбрал владелец. Наличие работающего `/healthz` **не подтверждает** вход в Telegram и доступ ChatGPT.

## 6. Сервис, обновление, безопасность

```bash
docker compose ps
docker compose restart reader
git pull --ff-only
bash scripts/update.sh
```

Для обновления сохраняются текущий и предыдущий собственные образы; **другие** образы, volumes и кеши Docker не очищаются. Если используешь Compose override, зафиксируй `COMPOSE_FILE` локально до обновления.

Настройки: `config/config.json` с правами 600. Данные: `data/` с правами 700 (внутри Telegram-сессия и OAuth cache). Не отправляй файлы из этих папок в GitHub, Telegram, запросы к ИИ или открытые резервные копии. Для бэкапа отключи reader и используй зашифрованное хранилище. На VPS защищай SSH ключом и обновлениями ОС.

При компрометации: остановить reader, отозвать устройство в Telegram → Настройки → Устройства и GitHub OAuth grant; заменить OAuth секрет и ключ подписи, выполнить повторную авторизацию. Отзыв конкретной Telegram-сессии может потребовать повторного логина.

## 7. Если не работает

- `docker compose run --rm -it setup init` отказывает: проверить права `config/`, не переинициализировать поверх существующих секретов.
- `reader` не стартует: проверить сессию, состояние `docker compose ps`, DNS/прокси, не публикуя лог с секретами.
- 404 по `/mcp`: проверь URL и reverse proxy; путь должен сохраниться.
- HTTPS не получает сертификат: DNS A/AAAA, 80/443, firewall и не занят ли порт.
- OAuth-loop/403: числовой GitHub ID должен быть **твоим**, callback GitHub `/auth/callback`, ChatGPT callback должен быть в allowlist.
- Telegram FloodWait: дождись указанного срока; не пиши обходы лимитов.
- Нет чатов: список может быть ограничен настройками `allow_all_chats/allowed_chat_ids`, при этом Telegram-сессия может быть исправна.

Проверки CI запускаются на push/pull request и не требуют реальных аккаунтов. Финальное подтверждение готовности — только после ручного end-to-end теста владельцем на его VPS и в его ChatGPT.
