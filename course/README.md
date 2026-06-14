# Claude Code: суперсила для НЕпрограммистов

Добро пожаловать на курс! Здесь собраны все материалы для практической работы.

## Структура

| Папка | Сессия | Тема |
|-------|--------|------|
| `sessions/01-setup/demo/` | 1 | Установка и первые задачи |
| `sessions/02-context-skills/demo/` | 2 | Контекст и навыки |
| `sessions/03-mcp/demo/` | 3 | Внешние сервисы (MCP) |
| `sessions/04-agents/demo/` | 4 | Агенты и подагенты |
| `sessions/05-agent-teams/demo/` | 5 | Команды агентов |

## Как начать

1. Откройте терминал (Ctrl+` или Terminal > New Terminal)
2. Перейдите в папку демо:
   ```
   cd sessions/01-setup/demo/financial-dashboard
   ```
3. Запустите Claude Code:
   ```
   claude
   ```

## Полезные команды

| Команда | Описание |
|---------|----------|
| `claude` | Запустить Claude Code |
| `cd sessions/01-setup/demo/...` | Перейти к демо |
| `cd ~/course` | Вернуться в корень |
| `~/switch-api-key.sh [primary\|backup]` | Переключить API-ключ |
| `~/switch-model.sh subscription` | Claude по подписке (api.anthropic.com) |
| `~/switch-model.sh litellm` | LiteLLM-роутер (GLM, Ollama, ...) |
| `~/switch-model.sh` | Показать текущий режим |
| `source ~/.claude/.env && claude` | Применить переключение и запустить |

## Режимы работы

Контейнер поддерживает два режима — по подписке Claude и через LiteLLM-роутер.

### Переключение на подписку Claude

```bash
~/switch-model.sh subscription
source ~/.claude/.env && claude login   # первый раз — авторизация
source ~/.claude/.env && claude         # потом просто запуск
```

### Переключение на LiteLLM-роутер

```bash
~/switch-model.sh litellm
source ~/.claude/.env && claude
```

### Проверить текущий режим

```bash
~/switch-model.sh
```

> `source ~/.claude/.env` нужен чтобы текущий терминал подхватил новые настройки без перезапуска. Новые терминалы подхватывают изменения автоматически.
