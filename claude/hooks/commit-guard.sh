#!/bin/bash
# PreToolUse: block git add/commit of secret files
input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // empty')
[[ -z "$cmd" ]] && exit 0

# Only intercept git commands
echo "$cmd" | grep -qE '^\s*git (add|commit)' || exit 0

# Check for broad git add patterns
if echo "$cmd" | grep -qE 'git add (-A|\.|--all)'; then
  project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  danger_files=$(cd "$project_dir" 2>/dev/null && git status --porcelain 2>/dev/null | grep -iE '\.env(\..*)?$|\.pem$|\.key$|\.secret$|credentials|service.account' | head -5)
  if [[ -n "$danger_files" ]]; then
    echo "BLOCK: 'git add -A/.' would stage secret files:" >&2
    echo "$danger_files" >&2
    echo "Stage specific files by name instead." >&2
    exit 2
  fi
fi

# Check for explicitly adding secret files
if echo "$cmd" | grep -qiE 'git add.*\.env(\.[a-z]+)?|git add.*\.(pem|key|secret)|git add.*credentials|git add.*service.account'; then
  echo "BLOCK: attempting to stage a secrets file" >&2
  exit 2
fi

exit 0
