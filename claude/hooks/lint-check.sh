#!/bin/bash
# PostToolUse hook: auto-format & lint edited files
# Non-blocking: prints feedback for Claude to fix in subsequent edits

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
[[ -z "$file_path" ]] && exit 0

cd "${CLAUDE_PROJECT_DIR:-$(pwd)}" || exit 0

has() { command -v "$1" &>/dev/null; }

# Run lint; print errors as feedback but never block the edit
lint() {
  local result
  result=$("$@" 2>&1) || {
    [[ -n "$result" ]] && printf '\nLint issues in %s:\n%s\n\n' "$file_path" "$(echo "$result" | head -20)" >&2
  }
}

# Advisory: flag inline styles in component files (prefer Tailwind v4 utilities)
check_inline_styles() {
  local matches
  matches=$(grep -nE 'style=(\{|")' "$file_path" 2>/dev/null | grep -v '^\s*//' | head -5)
  [[ -n "$matches" ]] && printf '\nNote: Inline styles in %s (prefer Tailwind v4 utilities unless not supported):\n%s\n\n' "$file_path" "$matches" >&2
}

case "${file_path##*.}" in
  ts|tsx|js|jsx|mjs|cjs)
    has biome || exit 0
    biome format --write "$file_path" 2>/dev/null
    lint biome check --fix "$file_path"
    ;;
  py)
    has ruff || exit 0
    ruff format "$file_path" 2>/dev/null
    lint ruff check --fix "$file_path"
    ;;
  rs)
    has cargo || exit 0
    lint cargo clippy --message-format=short -- -D warnings
    ;;
  go)
    has gofmt && gofmt -w "$file_path" 2>/dev/null
    has golangci-lint && lint golangci-lint run "$file_path"
    ;;
esac

# Check for inline styles in web component files
case "${file_path##*.}" in
  tsx|jsx|astro) check_inline_styles ;;
esac

exit 0
