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

# Initialize course directory from image if volume is empty (first run)
if [ -d /home/coder/.course-image ] && [ ! -f /home/coder/course/.initialized ]; then
    cp -a /home/coder/.course-image/. /home/coder/course/
    touch /home/coder/course/.initialized
fi

# Write Claude Code env config with the active API key
# Модели берём из GLM_*_MODEL (не из ANTHROPIC_DEFAULT_*_MODEL — те не передаются в контейнер)
mkdir -p /home/coder/.claude
cat > /home/coder/.claude/.env << EOF
ANTHROPIC_AUTH_TOKEN=${ANTHROPIC_AUTH_TOKEN:-}
ANTHROPIC_BASE_URL=${ANTHROPIC_BASE_URL:-https://api.z.ai/api/anthropic}
ANTHROPIC_DEFAULT_OPUS_MODEL=${GLM_OPUS_MODEL:-GLM-5.1}
ANTHROPIC_DEFAULT_SONNET_MODEL=${GLM_SONNET_MODEL:-GLM-4.7}
ANTHROPIC_DEFAULT_HAIKU_MODEL=${GLM_HAIKU_MODEL:-GLM-4.5-Air}
API_TIMEOUT_MS=${API_TIMEOUT_MS:-3000000}
EOF

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

# Готовые профили: subscription и litellm
# При переключении просто копируем нужный в .claude/.env — ничего не теряется

cat > /home/coder/.claude/.env.subscription << 'EOF'
API_TIMEOUT_MS=3000000
EOF

cat > /home/coder/.claude/.env.litellm << EOF
ANTHROPIC_AUTH_TOKEN=${ANTHROPIC_AUTH_TOKEN:-}
ANTHROPIC_BASE_URL=${ANTHROPIC_BASE_URL:-http://litellm:4000}
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
# Это позволяет switch-model.sh работать: файл → export → process env → Claude Code
# set -a автоматически экспортирует все переменные из файла
cat >> /home/coder/.bashrc << 'ENVLOAD'

# Загрузка конфига Claude Code (модели, ключ, BASE_URL)
set -a
[ -f /home/coder/.claude/.env ] && source /home/coder/.claude/.env
set +a
ENVLOAD

# Welcome banner in terminal
cat >> /home/coder/.bashrc << 'BANNER'

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
BANNER

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
    code-server \
    --bind-addr 127.0.0.1:8081 \
    --auth none \
    --disable-telemetry \
    /home/coder/course > /tmp/code-server.log 2>&1 &

# Start auth gateway (single entry point on :8080)
exec python3 /home/coder/auth-gateway.py
