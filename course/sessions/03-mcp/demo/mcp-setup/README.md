# Демо: настройка MCP-серверов

## Что показываем

Подключаем к Claude Code Filesystem и Tavily, проверяем область действия и права. Google Drive оставлен как продвинутый пример: официальный сервер Google находится в Developer Preview и требует предварительной настройки Google Cloud.

Время: 15–20 минут на два основных сервера и проверку.

## Где хранится конфигурация

Не добавляйте MCP-серверы в `.claude/settings.json`.

- `--scope local` — только текущий проект на этом компьютере; запись в `~/.claude.json`.
- `--scope project` — общий конфиг проекта в `.mcp.json`; Claude попросит подтвердить доверие.
- `--scope user` — личный сервер для всех проектов; запись в `~/.claude.json`.

Для курса используем CLI: он снижает риск ошибки в JSON. Проверка: `claude mcp list` в терминале и `/mcp` внутри Claude Code.

## Шаг 1. Filesystem: локальный доступ к папкам

Создайте тестовую папку и подставьте её абсолютный путь:

```bash
mkdir -p "$HOME/Documents/mcp-demo"
claude mcp add --transport stdio --scope project filesystem -- \
  npx -y @modelcontextprotocol/server-filesystem \
  "$HOME/Documents/mcp-demo"
```

Проверка внутри Claude Code:

```text
Покажи разрешённые папки Filesystem MCP. Создай в тестовой папке файл hello.txt с одной строкой и прочитай его обратно.
```

Важно: сервер разрешает операции только внутри переданных папок. Не используйте для демо домашний каталог целиком.

## Шаг 2. Tavily: удалённый веб-поиск

Рекомендуемый вариант — удалённый HTTP-сервер с OAuth, без ключа в URL и файлах:

```bash
claude mcp add --transport http --scope user tavily \
  https://mcp.tavily.com/mcp
```

Затем запустите Claude Code, откройте `/mcp`, выберите Tavily и завершите авторизацию. Тест:

```text
Через Tavily найди две свежие официальные публикации Anthropic о Claude Code. Для каждой дай заголовок, дату и прямую ссылку.
```

Если OAuth недоступен, используйте локальный сервер и передайте ключ через `--env`, не вставляя реальное значение в учебные файлы:

```bash
claude mcp add --transport stdio --scope user \
  --env TAVILY_API_KEY=YOUR_KEY_HERE tavily-local -- \
  npx -y tavily-mcp@latest
```

## Шаг 3. Google Drive: только подготовленное продвинутое демо

Пакет `@modelcontextprotocol/server-gdrive` архивирован и не должен использоваться в новом занятии. Официальный сервер Google Drive доступен по адресу `https://drivemcp.googleapis.com/mcp/v1`, но на июль 2026 года находится в Developer Preview.

Для него нужны:

1. доступ к Google Workspace Developer Preview;
2. проект Google Cloud с включённым Drive MCP API;
3. OAuth/ADC и billing/quota project;
4. короткоживущий access token или поддерживаемый OAuth-поток клиента.

Файл `google-drive-config.json` показывает форму HTTP-конфига с переменными окружения, но не является готовой авторизацией. Если окружение не подготовлено заранее, пропустите Google Drive на живом занятии.

## Файлы-примеры

- `filesystem-config.json` — проектный stdio-сервер с ограниченными папками.
- `tavily-config.json` — удалённый Tavily без секрета в файле.
- `google-drive-config.json` — продвинутый шаблон официального Google Drive MCP.

## Проверка и удаление

```bash
claude mcp list
claude mcp get filesystem
claude mcp remove filesystem
```

Внутри Claude Code используйте `/mcp`: там видны статус, число инструментов и авторизация.

## Частые проблемы

| Проблема | Что проверить |
|---|---|
| Сервер не стартует | `node --version`, `npx --version`, абсолютный путь и существование папки |
| Сервер добавлен не туда | Повторите команду с явным `--scope project` или `--scope user` |
| Tavily просит авторизацию | Откройте `/mcp`, выберите сервер и завершите OAuth |
| Конфиг проекта не загружается | Подтвердите доверие к `.mcp.json` |
| Google Drive отвечает 401/403 | Проверьте участие в Preview, Cloud project, scopes и access token |
