#!/bin/bash
# Global PostToolUse hook: Run linting on edited files
# BLOCKING - prevents edits from completing until lint errors are fixed
# Automatically detects project type and runs appropriate linter

# Read the tool input from stdin
input=$(cat)

# Extract file path from tool input
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Skip if no file path
if [[ -z "$file_path" ]]; then
  exit 0
fi

# Get the project directory
project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Function to check if a linter is applicable
is_js_ts_project() {
  [[ -f "$project_dir/package.json" ]] && \
    ([[ -f "$project_dir/eslint.config.mjs" ]] || \
     [[ -f "$project_dir/eslint.config.js" ]] || \
     [[ -f "$project_dir/.eslintrc" ]] || \
     [[ -f "$project_dir/.eslintrc.json" ]] || \
     [[ -f "$project_dir/.eslintrc.js" ]] || \
     grep -q '"eslint"' "$project_dir/package.json" 2>/dev/null)
}

is_python_project() {
  [[ -f "$project_dir/pyproject.toml" ]] || \
  [[ -f "$project_dir/setup.py" ]] || \
  [[ -f "$project_dir/requirements.txt" ]] || \
  [[ -f "$project_dir/ruff.toml" ]] || \
  [[ -f "$project_dir/.flake8" ]]
}

is_rust_project() {
  [[ -f "$project_dir/Cargo.toml" ]]
}

is_go_project() {
  [[ -f "$project_dir/go.mod" ]]
}

# Run appropriate linter based on file type and project
run_lint() {
  local file="$1"
  local ext="${file##*.}"

  case "$ext" in
    ts|tsx|js|jsx|mjs|cjs)
      if is_js_ts_project; then
        cd "$project_dir" && npx eslint "$file" --format compact 2>&1
        return $?
      fi
      ;;
    py)
      if is_python_project; then
        if command -v ruff &>/dev/null && [[ -f "$project_dir/ruff.toml" || -f "$project_dir/pyproject.toml" ]]; then
          cd "$project_dir" && ruff check "$file" 2>&1
          return $?
        elif command -v flake8 &>/dev/null; then
          cd "$project_dir" && flake8 "$file" 2>&1
          return $?
        fi
      fi
      ;;
    rs)
      if is_rust_project && command -v cargo &>/dev/null; then
        cd "$project_dir" && cargo clippy --message-format=short -- -D warnings 2>&1 | head -30
        return $?
      fi
      ;;
    go)
      if is_go_project && command -v golangci-lint &>/dev/null; then
        cd "$project_dir" && golangci-lint run "$file" 2>&1
        return $?
      fi
      ;;
  esac

  # No applicable linter found
  return 0
}

# Check if file type is lintable
ext="${file_path##*.}"
case "$ext" in
  ts|tsx|js|jsx|mjs|cjs|py|rs|go)
    ;;
  *)
    # Not a lintable file type
    exit 0
    ;;
esac

# Run the linter
result=$(run_lint "$file_path")
exit_code=$?

if [[ $exit_code -ne 0 ]] && [[ -n "$result" ]]; then
  # Check if there are actual errors (not just warnings) for JS/TS
  has_errors=0
  if [[ "${file_path##*.}" =~ ^(ts|tsx|js|jsx|mjs|cjs)$ ]]; then
    has_errors=$(echo "$result" | grep -c " Error - " || echo "0")
  else
    # For other languages, any non-zero exit is an error
    has_errors=1
  fi

  # Output to stderr (shown to Claude)
  echo "" >&2
  echo "❌ Lint issues in $file_path:" >&2
  echo "$result" | head -20 >&2

  if [[ $(echo "$result" | wc -l) -gt 20 ]]; then
    echo "... and more issues" >&2
  fi
  echo "" >&2

  # Block on errors
  if [[ "$has_errors" -gt 0 ]]; then
    echo "🛑 Fix lint errors before continuing." >&2
    exit 2
  fi
fi

exit 0
