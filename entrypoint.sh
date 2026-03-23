#!/usr/bin/env bash
#
# entrypoint.sh — Container startup with API key management and auth gateway
#
# Architecture:
#   auth-gateway.py (:8080) → code-server (:8081) + File Browser (:9090)
#   Single login portal, then full access to IDE and file manager.
#
# Supports three modes via switch-api-key.sh:
#   zai     — Z.AI (GLM), primary key
#   backup  — Z.AI (GLM), backup key
#   claude  — Anthropic, real Claude

set -euo pipefail

# Initialize course directory from image if volume is empty (first run)
if [ -d /home/coder/.course-image ] && [ ! -f /home/coder/course/.initialized ]; then
    cp -a /home/coder/.course-image/. /home/coder/course/
    touch /home/coder/course/.initialized
fi

# Write Claude Code env config with the active API key (default: z.ai)
mkdir -p /home/coder/.claude
cat > /home/coder/.claude/.env << EOF
ANTHROPIC_AUTH_TOKEN=${GLM_API_KEY:-}
ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic
ANTHROPIC_DEFAULT_OPUS_MODEL=${GLM_OPUS_MODEL:-GLM-4.7}
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

# Helper script to switch provider and API key
cat > /home/coder/switch-api-key.sh << SWITCH
#!/usr/bin/env bash
ENV_FILE="/home/coder/.claude/.env"

case "\${1:-}" in
  zai)
    sed -i "s|^ANTHROPIC_AUTH_TOKEN=.*|ANTHROPIC_AUTH_TOKEN=${GLM_API_KEY}|" "\$ENV_FILE"
    sed -i "s|^ANTHROPIC_BASE_URL=.*|ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic|" "\$ENV_FILE"
    sed -i "s|^ANTHROPIC_DEFAULT_OPUS_MODEL=.*|ANTHROPIC_DEFAULT_OPUS_MODEL=${GLM_OPUS_MODEL:-GLM-4.7}|" "\$ENV_FILE"
    sed -i "s|^ANTHROPIC_DEFAULT_SONNET_MODEL=.*|ANTHROPIC_DEFAULT_SONNET_MODEL=${GLM_SONNET_MODEL:-GLM-4.7}|" "\$ENV_FILE"
    sed -i "s|^ANTHROPIC_DEFAULT_HAIKU_MODEL=.*|ANTHROPIC_DEFAULT_HAIKU_MODEL=${GLM_HAIKU_MODEL:-GLM-4.5-Air}|" "\$ENV_FILE"
    echo "Switched to Z.AI (GLM) — primary key"
    ;;
  backup)
    if [ -z "${GLM_API_KEY_BACKUP}" ]; then
      echo "Error: GLM_API_KEY_BACKUP is not set"
      exit 1
    fi
    sed -i "s|^ANTHROPIC_AUTH_TOKEN=.*|ANTHROPIC_AUTH_TOKEN=${GLM_API_KEY_BACKUP}|" "\$ENV_FILE"
    sed -i "s|^ANTHROPIC_BASE_URL=.*|ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic|" "\$ENV_FILE"
    sed -i "s|^ANTHROPIC_DEFAULT_OPUS_MODEL=.*|ANTHROPIC_DEFAULT_OPUS_MODEL=${GLM_OPUS_MODEL:-GLM-4.7}|" "\$ENV_FILE"
    sed -i "s|^ANTHROPIC_DEFAULT_SONNET_MODEL=.*|ANTHROPIC_DEFAULT_SONNET_MODEL=${GLM_SONNET_MODEL:-GLM-4.7}|" "\$ENV_FILE"
    sed -i "s|^ANTHROPIC_DEFAULT_HAIKU_MODEL=.*|ANTHROPIC_DEFAULT_HAIKU_MODEL=${GLM_HAIKU_MODEL:-GLM-4.5-Air}|" "\$ENV_FILE"
    echo "Switched to Z.AI (GLM) — backup key"
    ;;
  claude)
    if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
      echo "Error: ANTHROPIC_API_KEY is not set"
      exit 1
    fi
    sed -i "s|^ANTHROPIC_AUTH_TOKEN=.*|ANTHROPIC_AUTH_TOKEN=${ANTHROPIC_API_KEY}|" "\$ENV_FILE"
    sed -i "s|^ANTHROPIC_BASE_URL=.*|ANTHROPIC_BASE_URL=https://api.anthropic.com|" "\$ENV_FILE"
    sed -i "s|^ANTHROPIC_DEFAULT_OPUS_MODEL=.*|ANTHROPIC_DEFAULT_OPUS_MODEL=${ANTHROPIC_OPUS_MODEL:-claude-opus-4-6}|" "\$ENV_FILE"
    sed -i "s|^ANTHROPIC_DEFAULT_SONNET_MODEL=.*|ANTHROPIC_DEFAULT_SONNET_MODEL=${ANTHROPIC_SONNET_MODEL:-claude-sonnet-4-6}|" "\$ENV_FILE"
    sed -i "s|^ANTHROPIC_DEFAULT_HAIKU_MODEL=.*|ANTHROPIC_DEFAULT_HAIKU_MODEL=${ANTHROPIC_HAIKU_MODEL:-claude-haiku-4-5-20251001}|" "\$ENV_FILE"
    echo "Switched to Anthropic (real Claude)"
    ;;
  *)
    echo "Usage: ./switch-api-key.sh [zai|backup|claude]"
    echo ""
    CURRENT=\$(grep "^ANTHROPIC_AUTH_TOKEN=" "\$ENV_FILE" | cut -d= -f2)
    URL=\$(grep "^ANTHROPIC_BASE_URL=" "\$ENV_FILE" | cut -d= -f2)
    echo "Current provider: \$URL"
    echo "Current key:      \${CURRENT:0:8}..."
    ;;
esac

echo "Restart Claude Code (Ctrl+C, then 'claude') to apply."
SWITCH
chmod +x /home/coder/switch-api-key.sh

# Welcome banner in terminal
cat >> /home/coder/.bashrc << 'BANNER'

echo ""
echo -e "\033[1;36m  Claude Code: рабочая среда курса\033[0m"
echo -e "\033[0;37m  ─────────────────────────────────\033[0m"
echo -e "  Запустить Claude Code:  \033[1;32mclaude\033[0m"
echo -e "  Первое демо:            \033[0;33mcd sessions/01-setup/demo/financial-dashboard\033[0m"
echo -e "  Файловый менеджер:      \033[0;33m/files/\033[0m в адресной строке"
echo -e "  Переключить провайдер:  \033[0;33m./switch-api-key.sh [zai|backup|claude]\033[0m"
echo ""
BANNER

# Start File Browser in background (noauth + branding configured at build time in Dockerfile)
FB_DB="/home/coder/.config/filebrowser/filebrowser.db"
filebrowser --database "$FB_DB" > /tmp/filebrowser.log 2>&1 &

# Start code-server in background (internal, no auth — gateway handles auth)
code-server \
    --bind-addr 127.0.0.1:8081 \
    --auth none \
    --disable-telemetry \
    /home/coder/course > /tmp/code-server.log 2>&1 &

# Start auth gateway (single entry point on :8080)
exec python3 /home/coder/auth-gateway.py