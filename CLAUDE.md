# Рабочая среда курса

## Текущий режим и модели

Текущий конфиг: `~/.claude/.env`

Посмотреть текущие настройки:
~/switch-model.sh

## Переключение режима

```bash
~/switch-model.sh subscription           # Claude по подписке
~/switch-model.sh glm                    # GLM (Z.AI) напрямую
~/switch-model.sh ollama qwen3:32b       # Ollama напрямую (v0.14+)
~/switch-model.sh lmstudio               # LM Studio напрямую (v0.4.1+)
source ~/.claude/.env && claude          # применить и запустить
```

## Прямые подключения

Все режимы подключаются напрямую без прокси:

```
┌──────────────┬────────────────────────┬───────────────────────┐
│    Режим     │   Куда идут запросы    │       Протокол        │
├──────────────┼────────────────────────┼───────────────────────┤
│ subscription │ api.anthropic.com      │ Anthropic API         │
├──────────────┼────────────────────────┼───────────────────────┤
│ glm          │ api.z.ai/api/anthropic │ Anthropic-совместимый │
├──────────────┼────────────────────────┼───────────────────────┤
│ ollama       │ ollama:11434           │ Anthropic-совместимый │
├──────────────┼────────────────────────┼───────────────────────┤
│ lmstudio     │ $LMSTUDIO_URL          │ Anthropic-совместимый │
└──────────────┴────────────────────────┴───────────────────────┘
```

## Проверить модели Ollama

```bash
curl -s http://ollama:11434/api/tags | python3 -c "import sys,json; [print(m['name']) for m in json.loads(sys.stdin.read())['models']]"
```

## Безопасность

Контейнер имеет доступ к Docker daemon через `/var/run/docker.sock`.
Запрещено без разрешения пользователя: `--privileged`, `--cap-add SYS_ADMIN`, монтирование корня хоста, `--network host`.
