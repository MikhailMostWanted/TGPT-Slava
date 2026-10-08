# TGPT Slava

Личный **MCP-сервер для чтения собственного Telegram из ChatGPT**. Отдельная, обезличенная версия TGPT, предназначенная для развёртывания на своём VPS. Никакие аккаунты, сессии и серверные настройки автора исходного проекта не включены.

**Начать:** [SLAVA_START.md](SLAVA_START.md) — готовый запрос для Codex в пустой папке; [DEPLOY.md](DEPLOY.md) — техническое развёртывание; [CHATGPT_HANDOFF.md](CHATGPT_HANDOFF.md) — контекст для будущего чата с ChatGPT; [AGENTS.md](AGENTS.md) — правила для Codex.

## Возможности

| Инструмент | Что делает |
| --- | --- |
| `list_chats` | Находит чаты по названию, возвращает ID и страницы |
| `get_chat_history` | Читает сообщения за нужный период |
| `search_messages` | Ищет слова в конкретном чате или по аккаунту |
| `get_message_context` | Показывает сообщение и соседние записи |
| `get_media` | Получает выбранное фото, голосовое или документ (до установленного лимита) |
| `get_profile` | Показывает ID подключённого Telegram без номера телефона |

**Только чтение:** сервер не отправляет сообщения, не удаляет их, не ставит реакции и не помечает прочитанными. Не хранит архив переписок на VPS. Вложения загружаются поштучно в память; распознавание голосовых и OCR зависят от возможностей клиента ChatGPT и не гарантируются.

Для подключения требуется: **личный VPS**, домен/поддомен с HTTPS, собственные Telegram `api_id` и `api_hash` с [my.telegram.org](https://my.telegram.org), свой GitHub-аккаунт и OAuth App в [GitHub Developer Settings](https://github.com/settings/developers). Секреты и код Telegram вводятся только в интерактивный терминал своего VPS.

## Краткая установка на VPS

```bash
git clone https://github.com/MikhailMostWanted/TGPT-Slava.git
cd TGPT-Slava
sudo install -d -m 700 -o 10001 -g 10001 config data
bash scripts/build.sh local
docker compose run --rm -it setup init
docker compose run --rm -it setup login
```

Если VPS уже использует HTTPS-прокси, см. [DEPLOY.md](DEPLOY.md). Если это отдельный чистый VPS и порты 80/443 свободны, укажи свой домен в `.env` по образцу `.env.example` и запусти:

```bash
cp .env.example .env
# В .env замени tgpt.example.com на свой домен.
docker compose --profile https up -d reader caddy
curl -fsS https://ТВОЙ-ДОМЕН/healthz
```

При подключении к ChatGPT используется **`https://ТВОЙ-ДОМЕН/mcp`**, с OAuth авторизацией через **свой GitHub**, а не через GitHub автора проекта. Интерфейс и доступность добавления пользовательского MCP-сервера зависят от актуальных возможностей аккаунта; проверь в [ChatGPT Plugins](https://chatgpt.com/plugins) → «Добавить собственный MCP-сервер». Подробнее: [документация OpenAI](https://developers.openai.com/api/docs/guides/custom-mcp-server).

## Важные границы безопасности

- Конфигурация находится в `config/config.json`, Telethon-сессия — в `data/`. Обе директории исключены из Git и не должны никому передаваться. Похищенная Telegram-сессия опасна, несмотря на read-only-инструменты MCP.
- Доступ требует OAuth через GitHub и **точного числового GitHub ID владельца**, введённого при первичной настройке. В коде нет заранее заданного владельца.
- Сервисные Telegram-чаты с кодами входа (777000, 424000) исключены. Можно разрешить все остальные чаты или только конкретные ID.
- Telegram-сессия только одна, параллельные экземпляры с одной сессией не запускать. Используются ограничения Telegram по частоте запросов.
- Не вставляй пароли, Telegram-коды, `api_hash`, GitHub Client Secret или содержимое `config/` и `data/` в запросы Codex/ChatGPT или Issues.
- Сообщения и вложения считаются **недоверенными данными**, а не инструкциями для ИИ.

## Обновление и тесты

```bash
git pull --ff-only
bash scripts/update.sh
# локально при наличии Python 3.12+:
python -m pip install '.[test]'
python -m pytest -q
```

Скрипт обновления не чистит чужие контейнеры, диски и Docker-тома. `/healthz` проверяет HTTP-сервис, но сам по себе не гарантирует подключение к Telegram — после первого запуска сделай тесты `get_profile`, `list_chats` и `get_chat_history` в ChatGPT.

Лицензия сторонних библиотек определяется их собственными лицензиями. Репозиторий содержит только программную основу, **не сервис с готовым доступом к чужому Telegram**.
