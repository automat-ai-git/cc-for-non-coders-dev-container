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
| `~/switch-model.sh subscription` | Claude по подписке |
| `~/switch-model.sh glm` | GLM (Z.AI) напрямую |
| `~/switch-model.sh ollama <модель>` | Ollama напрямую (v0.14+) |
| `~/switch-model.sh lmstudio` | LM Studio напрямую (v0.4.1+) |
| `~/switch-model.sh` | Показать текущий режим |
| `source ~/.claude/.env && claude` | Применить переключение и запустить |

## Режимы работы

Контейнер поддерживает четыре режима.

### Claude по подписке

```bash
~/switch-model.sh subscription
source ~/.claude/.env && claude login   # первый раз — авторизация
source ~/.claude/.env && claude         # потом просто запуск
```

### GLM (Z.AI)

```bash
~/switch-model.sh glm
source ~/.claude/.env && claude
```

### Ollama (локальные модели)

```bash
~/switch-model.sh ollama qwen3:32b
source ~/.claude/.env && claude
```

### LM Studio (Windows GPU)

```bash
~/switch-model.sh lmstudio
source ~/.claude/.env && claude
```

### Проверить текущий режим

```bash
~/switch-model.sh
```

> `source ~/.claude/.env` нужен чтобы текущий терминал подхватил новые настройки без перезапуска. Новые терминалы подхватывают изменения автоматически.
