#!/bin/bash
# PostToolUse hook: format edited web files with repo-local Biome, then report checks.
# Non-blocking: prints feedback for the agent, but never mutates via lint fixes.

set -u

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || true)
[[ -z "$file_path" ]] && exit 0
[[ -f "$file_path" ]] || exit 0

project_dir=${CLAUDE_PROJECT_DIR:-$(pwd)}
cd "$project_dir" 2>/dev/null || exit 0

biome_bin() {
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
  if [[ -n "$repo_root" && -x "$repo_root/node_modules/.bin/biome" ]]; then
    printf '%s\n' "$repo_root/node_modules/.bin/biome"
    return 0
  fi

  if [[ -x "./node_modules/.bin/biome" ]]; then
    printf '%s\n' "./node_modules/.bin/biome"
    return 0
  fi

  command -v biome 2>/dev/null || true
}

lint_feedback() {
  local result
  result=$("$@" 2>&1) || {
    [[ -n "$result" ]] && printf '\nBiome issues in %s:\n%s\n\n' "$file_path" "$(printf '%s' "$result" | head -40)" >&2
  }
}

case "${file_path##*.}" in
  ts|tsx|js|jsx|mjs|cjs|astro|json|jsonc|css)
    biome_cmd=$(biome_bin)
    [[ -n "$biome_cmd" ]] || exit 0
    "$biome_cmd" format --write "$file_path" >/dev/null 2>&1 || true
    lint_feedback "$biome_cmd" check "$file_path"
    ;;
esac

exit 0
