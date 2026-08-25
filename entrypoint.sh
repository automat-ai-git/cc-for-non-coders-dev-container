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
mkdir -p /home/coder/.claude
cat > /home/coder/.claude/.env << EOF
ANTHROPIC_AUTH_TOKEN=${ANTHROPIC_AUTH_TOKEN:-}
ANTHROPIC_BASE_URL=${ANTHROPIC_BASE_URL:-https://api.z.ai/api/anthropic}
ANTHROPIC_DEFAULT_OPUS_MODEL=${ANTHROPIC_DEFAULT_OPUS_MODEL:-GLM-5.3}
ANTHROPIC_DEFAULT_SONNET_MODEL=${ANTHROPIC_DEFAULT_SONNET_MODEL:-GLM-5.3}
ANTHROPIC_DEFAULT_HAIKU_MODEL=${ANTHROPIC_DEFAULT_HAIKU_MODEL:-GLM-4.5-Air}
API_TIMEOUT_MS=${API_TIMEOUT_MS:-3000000}
EOF

# ── Merge runtime env into ~/.claude/settings.json ──
# settings.json ships in the image without secrets: the API key and any
# per-deployment overrides are merged in here at startup. Claude Code reads
# its env from settings.json, so the key has to land in this file — writing
# .claude/.env alone is not enough. Idempotent, runs on every start.
python3 - << 'PYEOF'
import json, os

path = "/home/coder/.claude/settings.json"
with open(path) as f:
    settings = json.load(f)

env = settings.setdefault("env", {})
for key in (
    "ANTHROPIC_AUTH_TOKEN",
    "ANTHROPIC_BASE_URL",
    "ANTHROPIC_DEFAULT_OPUS_MODEL",
    "ANTHROPIC_DEFAULT_SONNET_MODEL",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL",
    "API_TIMEOUT_MS",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS",
):
    value = os.environ.get(key)
    if value:
        env[key] = value

with open(path, "w") as f:
    json.dump(settings, f, indent=2)
print("[entrypoint] settings.json env merged: " + ", ".join(sorted(env)))
PYEOF

# ── Seed ~/.claude.json to bypass first-run dialogs ──
# Without this, Claude Code blocks on: onboarding, "trust this API key?", and the
# per-folder "do you trust this folder?" dialog. We pre-accept all of them for the
# whole course tree so students get a clean, prompt-free first run. This file lives
# in the container's ephemeral layer, so it is regenerated on every container start.
set +e
CLAUDE_VER=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
[ -z "$CLAUDE_VER" ] && CLAUDE_VER="99.0.0"
python3 - "$CLAUDE_VER" "${ANTHROPIC_AUTH_TOKEN:-}" "${ANTHROPIC_AUTH_TOKEN_BACKUP:-}" <<'PYEOF'
import json, os, secrets, sys
ver, token, token_backup = sys.argv[1], sys.argv[2], sys.argv[3]
home = "/home/coder"

# Trust every directory in the course tree so no folder-trust prompt appears,
# wherever a student launches `claude` from.
trust_dirs = {home}
course = os.path.join(home, "course")
if os.path.isdir(course):
    for root, dirs, _ in os.walk(course):
        dirs[:] = [d for d in dirs if d not in (".git", "node_modules", ".venv", "__pycache__")]
        trust_dirs.add(root)

entry = {
    "hasTrustDialogAccepted": True,
    "hasClaudeMdExternalIncludesApproved": True,
    "hasClaudeMdExternalIncludesWarningShown": True,
    "projectOnboardingSeenCount": 1,
    "allowedTools": [], "mcpServers": {},
    "enabledMcpjsonServers": [], "disabledMcpjsonServers": [],
}
projects = {d: dict(entry) for d in sorted(trust_dirs)}

# Pre-approve the primary (and backup, if set) API key tails to skip the key-trust prompt.
approved = []
for t in (token, token_backup):
    if t:
        approved.append(t[-20:] if len(t) > 20 else t)

cj = {
    "numStartups": 184,
    "autoUpdaterStatus": "disabled",
    "userID": secrets.token_hex(32),
    "hasCompletedOnboarding": True,
    "hasTrustDialogAccepted": True,
    "lastOnboardingVersion": ver,
    "projects": projects,
    "customApiKeyResponses": {"approved": approved, "rejected": []},
}
with open(os.path.join(home, ".claude.json"), "w") as f:
    json.dump(cj, f, indent=2)
print(f"[entrypoint] .claude.json seeded: ver={ver}, trusted_dirs={len(projects)}, keys_approved={len(approved)}")
PYEOF
set -e

# Helper script to switch API keys. Updates both .claude/.env and
# .claude/settings.json — settings.json is the file Claude Code actually reads.
cat > /home/coder/switch-api-key.sh << 'SWITCH'
#!/usr/bin/env bash
ENV_FILE="/home/coder/.claude/.env"

apply_key() {
    sed -i "s|^ANTHROPIC_AUTH_TOKEN=.*|ANTHROPIC_AUTH_TOKEN=$1|" "$ENV_FILE"
    python3 - "$1" << 'PY'
import json, sys
path = "/home/coder/.claude/settings.json"
with open(path) as f:
    settings = json.load(f)
settings.setdefault("env", {})["ANTHROPIC_AUTH_TOKEN"] = sys.argv[1]
with open(path, "w") as f:
    json.dump(settings, f, indent=2)
PY
}

if [ "${1:-}" = "backup" ] && [ -n "${ANTHROPIC_AUTH_TOKEN_BACKUP:-}" ]; then
    apply_key "${ANTHROPIC_AUTH_TOKEN_BACKUP}"
    echo "Switched to BACKUP key"
    echo "Restart Claude Code (Ctrl+C, then 'claude') to apply."
elif [ "${1:-}" = "primary" ] && [ -n "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
    apply_key "${ANTHROPIC_AUTH_TOKEN}"
    echo "Switched to PRIMARY key"
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

# Welcome banner in terminal
cat >> /home/coder/.bashrc << 'BANNER'

echo ""
echo -e "\033[1;36m  Claude Code: рабочая среда курса\033[0m"
echo -e "\033[0;37m  ─────────────────────────────────\033[0m"
echo -e "  Запустить Claude Code:  \033[1;32mclaude\033[0m"
echo -e "  Первое демо:            \033[0;33mcd sessions/01-setup/demo/financial-dashboard\033[0m"
echo -e "  Файловый менеджер:      \033[0;33m/files/\033[0m в адресной строке"
echo -e "  Переключить API-ключ:   \033[0;33m./switch-api-key.sh [primary|backup]\033[0m"
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
