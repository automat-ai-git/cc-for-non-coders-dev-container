#!/usr/bin/env bash
#
# entrypoint.sh — Container startup with API key management and auth gateway
#
# Architecture:
#   auth-gateway.py (:8080) → code-server (:8081) + File Browser (:9090)
#   Single login portal, then full access to IDE and file manager.
#
# Supports two API keys: primary (ANTHROPIC_AUTH_TOKEN) and backup
# (ANTHROPIC_AUTH_TOKEN_BACKUP). The switch-api-key command lets the
# instructor swap all containers to the backup key mid-session.

set -euo pipefail

LITELLM_URL=${LITELLM_URL:-http://host.docker.internal:4000}

# Initialize course directory from image if volume is empty (first run)
if [ -d /home/coder/.course-image ] && [ ! -f /home/coder/course/.initialized ]; then
    cp -a /home/coder/.course-image/. /home/coder/course/
    touch /home/coder/course/.initialized
fi

# Write Claude Code env config (only on first run — volume preserves user's choice)
mkdir -p /home/coder/.claude
if [ ! -f /home/coder/.claude/.env ]; then
    cat > /home/coder/.claude/.env << EOF
ANTHROPIC_AUTH_TOKEN=${ANTHROPIC_AUTH_TOKEN:-}
ANTHROPIC_BASE_URL=${LITELLM_URL}
ANTHROPIC_DEFAULT_OPUS_MODEL=${GLM_OPUS_MODEL:-GLM-5.1}
ANTHROPIC_DEFAULT_SONNET_MODEL=${GLM_SONNET_MODEL:-GLM-4.7}
ANTHROPIC_DEFAULT_HAIKU_MODEL=${GLM_HAIKU_MODEL:-GLM-4.5-Air}
API_TIMEOUT_MS=${API_TIMEOUT_MS:-3000000}
EOF
fi

# Настройка Plane MCP (если задан API ключ)
# Используем claude mcp add --scope user (settings.json mcpServers игнорируется Claude Code)
if [ -n "${PLANE_API_KEY:-}" ]; then
    claude mcp add plane \
        --scope user \
        -e PLANE_API_KEY="${PLANE_API_KEY}" \
        -e PLANE_WORKSPACE_SLUG="${PLANE_WORKSPACE_SLUG:-}" \
        -e PLANE_BASE_URL="${PLANE_BASE_URL:-}" \
        -- uvx plane-mcp-server stdio 2>/dev/null || true
    echo "✓ Plane MCP configured (workspace: ${PLANE_WORKSPACE_SLUG})"
fi

# Настройка SearXNG MCP (веб-поиск для локальных моделей)
if [ -n "${SEARXNG_URL:-}" ]; then
    claude mcp add searxng \
        --scope user \
        -e SEARXNG_URL="${SEARXNG_URL}" \
        -- mcp-searxng 2>/dev/null || true
    echo "✓ SearXNG MCP configured (${SEARXNG_URL})"
fi

# Helper script to switch API keys (writes to .claude/.env so Claude Code picks it up)
cat > /home/coder/switch-api-key.sh << 'SWITCH'
#!/usr/bin/env bash
ENV_FILE="/home/coder/.claude/.env"

if [ "${1:-}" = "backup" ] && [ -n "${ANTHROPIC_AUTH_TOKEN_BACKUP:-}" ]; then
    sed -i "s|^ANTHROPIC_AUTH_TOKEN=.*|ANTHROPIC_AUTH_TOKEN=${ANTHROPIC_AUTH_TOKEN_BACKUP}|" "$ENV_FILE"
    echo "Switched to BACKUP key in .claude/.env"
    echo "Restart Claude Code (Ctrl+C, then 'claude') to apply."
elif [ "${1:-}" = "primary" ] && [ -n "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
    sed -i "s|^ANTHROPIC_AUTH_TOKEN=.*|ANTHROPIC_AUTH_TOKEN=${ANTHROPIC_AUTH_TOKEN}|" "$ENV_FILE"
    echo "Switched to PRIMARY key in .claude/.env"
    echo "Restart Claude Code (Ctrl+C, then 'claude') to apply."
else
    echo "Usage: ./switch-api-key.sh [primary|backup]"
    echo ""
    CURRENT=$(grep ANTHROPIC_AUTH_TOKEN "$ENV_FILE" | head -1 | cut -d= -f2)
    echo "Current key: ${CURRENT:0:8}..."
    [ -n "${ANTHROPIC_AUTH_TOKEN_BACKUP:-}" ] && echo "Backup key: ${ANTHROPIC_AUTH_TOKEN_BACKUP:0:8}..." || echo "Backup key: not set"
fi
SWITCH
chmod +x /home/coder/switch-api-key.sh

# CLAUDE.md для домашней директории — Claude Code видит его из любой папки
cat > /home/coder/CLAUDE.md << 'CLAUDEMD'
# Рабочая среда курса

## Текущий режим и модели

Текущий конфиг: `~/.claude/.env`

Посмотреть текущие настройки:
```
~/switch-model.sh
```

## Переключение режима

```bash
~/switch-model.sh subscription   # Claude по подписке
~/switch-model.sh litellm        # LiteLLM-роутер
source ~/.claude/.env && claude   # применить и запустить
```

## Доступные модели через LiteLLM

В режиме litellm доступны три бэкенда. Проверить доступные модели:

```bash
# Все модели LiteLLM:
curl -s http://host.docker.internal:4000/v1/models | python3 -m json.tool

# Только Ollama:
curl -s http://host.docker.internal:11434/api/tags | python3 -c "import sys,json; [print(m['name']) for m in json.loads(sys.stdin.read())['models']]"
```

### Имена моделей для ~/.claude/.env

| Бэкенд | Формат имени | Примеры |
|--------|-------------|---------|
| GLM (Z.AI) | просто имя | `GLM-5.1`, `GLM-4.7`, `GLM-4.5-Air` |
| Ollama | `ollama/имя` | `ollama/qwen2.5:0.5b`, `ollama/deepseek-r1:7b` |
| llama-server (Windows) | `local/имя` | `local/any` |

### Как сменить модель

Отредактировать `~/.claude/.env` — поменять значения:
- `ANTHROPIC_DEFAULT_OPUS_MODEL` — модель для Opus-слота
- `ANTHROPIC_DEFAULT_SONNET_MODEL` — модель для Sonnet-слота (основная)
- `ANTHROPIC_DEFAULT_HAIKU_MODEL` — модель для Haiku-слота (быстрая)

После изменения: `source ~/.claude/.env && claude`

## Безопасность

Контейнер имеет доступ к Docker daemon через `/var/run/docker.sock`.
Запрещено без разрешения пользователя: `--privileged`, `--cap-add SYS_ADMIN`, монтирование корня хоста, `--network host`.
CLAUDEMD

# Готовые профили: subscription и litellm
# При переключении просто копируем нужный в .claude/.env — ничего не теряется

cat > /home/coder/.claude/.env.subscription << 'EOF'
API_TIMEOUT_MS=3000000
EOF

cat > /home/coder/.claude/.env.litellm << EOF
ANTHROPIC_AUTH_TOKEN=${ANTHROPIC_AUTH_TOKEN:-}
ANTHROPIC_BASE_URL=${LITELLM_URL}
ANTHROPIC_DEFAULT_OPUS_MODEL=${GLM_OPUS_MODEL:-GLM-5.1}
ANTHROPIC_DEFAULT_SONNET_MODEL=${GLM_SONNET_MODEL:-GLM-4.7}
ANTHROPIC_DEFAULT_HAIKU_MODEL=${GLM_HAIKU_MODEL:-GLM-4.5-Air}
API_TIMEOUT_MS=${API_TIMEOUT_MS:-3000000}
EOF

cat > /home/coder/switch-model.sh << 'SWITCH'
#!/usr/bin/env bash
ENV_FILE="/home/coder/.claude/.env"
DIR="/home/coder/.claude"

case "${1:-}" in
  subscription)
    cp "$DIR/.env.subscription" "$ENV_FILE"
    echo ""
    echo "  ✓ Режим: ПОДПИСКА Claude"
    echo "  Claude Code → api.anthropic.com (напрямую)"
    echo ""
    echo "  Если ещё не залогинен:"
    echo "    source ~/.claude/.env && claude login"
    echo ""
    echo "  Если уже залогинен:"
    echo "    source ~/.claude/.env && claude"
    echo ""
    ;;
  litellm)
    cp "$DIR/.env.litellm" "$ENV_FILE"
    echo ""
    echo "  ✓ Режим: LiteLLM-роутер"
    echo "  Claude Code → LiteLLM → GLM / Ollama / ..."
    echo ""
    echo "  Текущий конфиг:"
    grep -E "BASE_URL|MODEL" "$ENV_FILE" | sed 's/^/    /'
    echo ""
    echo "  Применить: source ~/.claude/.env && claude"
    echo ""
    ;;
  *)
    echo ""
    echo "  Использование: ~/switch-model.sh [subscription|litellm]"
    echo ""
    echo "  subscription  — Claude по подписке (api.anthropic.com)"
    echo "  litellm       — LiteLLM-роутер (GLM, Ollama, ...)"
    echo ""
    echo "  Текущий конфиг ~/.claude/.env:"
    cat "$ENV_FILE" | sed 's/^/    /'
    echo ""
    ;;
esac
SWITCH
chmod +x /home/coder/switch-model.sh

# Загружаем .claude/.env в каждом терминале как переменные окружения
# Защита от дублирования при рестартах контейнера
if ! grep -q '# CLAUDE_ENV_LOADER' /home/coder/.bashrc 2>/dev/null; then
cat >> /home/coder/.bashrc << 'ENVLOAD'

# CLAUDE_ENV_LOADER
set -a
[ -f /home/coder/.claude/.env ] && source /home/coder/.claude/.env
set +a

echo ""
echo -e "\033[1;36m  Claude Code: рабочая среда курса\033[0m"
echo -e "\033[0;37m  ─────────────────────────────────\033[0m"
echo -e "  Запустить Claude Code:  \033[1;32mclaude\033[0m"
echo -e "  Первое демо:            \033[0;33mcd sessions/01-setup/demo/financial-dashboard\033[0m"
echo -e "  Файловый менеджер:      \033[0;33m/files/\033[0m в адресной строке"
echo -e "  Переключить API-ключ:   \033[0;33m~/switch-api-key.sh [primary|backup]\033[0m"
echo -e "  Переключить режим:      \033[0;33m~/switch-model.sh [subscription|litellm]\033[0m"
echo -e "  Применить переключение: \033[0;33msource ~/.claude/.env && claude\033[0m"
echo ""
ENVLOAD
fi

# Start File Browser in background (noauth + branding configured at build time in Dockerfile)
FB_DB="/home/coder/.config/filebrowser/filebrowser.db"
filebrowser --database "$FB_DB" > /tmp/filebrowser.log 2>&1 &

# Start code-server in background (internal, no auth — gateway handles auth)
# Убираем ANTHROPIC_DEFAULT_*_MODEL из окружения code-server, чтобы Claude Code
# читал модели только из .claude/.env — иначе process env перебивает файл
# и switch-model.sh не работает (Node.js dotenv не перезаписывает уже заданные переменные)
env -u ANTHROPIC_DEFAULT_OPUS_MODEL \
    -u ANTHROPIC_DEFAULT_SONNET_MODEL \
    -u ANTHROPIC_DEFAULT_HAIKU_MODEL \
    -u ANTHROPIC_BASE_URL \
    -u ANTHROPIC_AUTH_TOKEN \
    code-server \
    --bind-addr 127.0.0.1:8081 \
    --auth none \
    --disable-telemetry \
    /home/coder/course > /tmp/code-server.log 2>&1 &

# Start auth gateway (single entry point on :8080)
exec python3 /home/coder/auth-gateway.py
