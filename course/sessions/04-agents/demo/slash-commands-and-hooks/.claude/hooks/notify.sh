#!/usr/bin/env bash

set -u

payload=$(cat)
message=$(printf '%s' "$payload" | jq -r '.message // "Claude Code требует внимания"')
title=$(printf '%s' "$payload" | jq -r '.title // "Claude Code"')

if command -v osascript >/dev/null 2>&1; then
  osascript -e 'on run argv' -e 'display notification (item 2 of argv) with title (item 1 of argv)' -e 'end run' -- "$title" "$message"
elif command -v notify-send >/dev/null 2>&1; then
  notify-send "$title" "$message"
fi
