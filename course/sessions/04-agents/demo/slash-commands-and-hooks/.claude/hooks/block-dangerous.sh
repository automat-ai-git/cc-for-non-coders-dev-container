#!/usr/bin/env bash

set -u

payload=$(cat)
command=$(printf '%s' "$payload" | jq -r '.tool_input.command // ""')

if printf '%s' "$command" | grep -Eq '(^|[;&|[:space:]])(rm[[:space:]]+-[^[:space:]]*r[^[:space:]]*f|sudo([[:space:]]|$)|chmod[[:space:]]+777([[:space:]]|$))'; then
  echo "Заблокировано: команда содержит rm -rf, sudo или chmod 777." >&2
  exit 2
fi

exit 0
