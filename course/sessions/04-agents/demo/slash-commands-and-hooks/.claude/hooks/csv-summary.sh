#!/usr/bin/env bash

set -u

payload=$(cat)
file_path=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_response.filePath // ""')

case "$file_path" in
  *.csv) ;;
  *) exit 0 ;;
esac

if [ ! -f "$file_path" ]; then
  exit 0
fi

header=$(head -n 1 "$file_path")
if printf '%s' "$header" | grep -q ';'; then
  columns=$(printf '%s\n' "$header" | awk -F';' '{print NF}')
  delimiter=';'
else
  columns=$(printf '%s\n' "$header" | awk -F',' '{print NF}')
  delimiter=','
fi

message="CSV проверен: $(basename "$file_path"), столбцов: $columns, разделитель: $delimiter"
jq -n --arg message "$message" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$message}}'
