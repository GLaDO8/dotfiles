#!/usr/bin/env bash
#
# Common utilities for validation scripts
# Provides logging, colors, and JSON output helpers
#

# Colors for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

# Output mode: "text" or "json"
OUTPUT_MODE="${OUTPUT_MODE:-text}"

# Validation results storage (for JSON output)
declare -a VALIDATION_RESULTS=()
CURRENT_CATEGORY=""

# ============================================================================
# Logging Functions
# ============================================================================

log_info() {
    if [[ "$OUTPUT_MODE" == "text" ]]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_success() {
    if [[ "$OUTPUT_MODE" == "text" ]]; then
        echo -e "${GREEN}[OK]${NC} $1"
    fi
}

log_warn() {
    if [[ "$OUTPUT_MODE" == "text" ]]; then
        echo -e "${YELLOW}[WARN]${NC} $1"
    fi
}

log_error() {
    if [[ "$OUTPUT_MODE" == "text" ]]; then
        echo -e "${RED}[ERROR]${NC} $1"
    fi
}

log_fix() {
    if [[ "$OUTPUT_MODE" == "text" ]]; then
        echo -e "${CYAN}[FIX]${NC} $1"
    fi
}

# ============================================================================
# Section Headers
# ============================================================================

print_section() {
    local title="$1"
    CURRENT_CATEGORY="$title"
    if [[ "$OUTPUT_MODE" == "text" ]]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "${BLUE}$title${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
}

# ============================================================================
# Result Tracking (for JSON output)
# ============================================================================

# Add a validation result
# Usage: add_result "status" "item" "message" "auto_fixable"
add_result() {
    local status="$1"      # ok, warn, error
    local item="$2"        # what was checked
    local message="$3"     # description
    local fixable="${4:-false}"  # can be auto-fixed?

    # Escape JSON strings
    item=$(echo "$item" | sed 's/"/\\"/g' | tr '\n' ' ')
    message=$(echo "$message" | sed 's/"/\\"/g' | tr '\n' ' ')

    local result="{\"category\":\"$CURRENT_CATEGORY\",\"status\":\"$status\",\"item\":\"$item\",\"message\":\"$message\",\"auto_fixable\":$fixable}"
    VALIDATION_RESULTS+=("$result")
}

# Output all results as JSON
output_json() {
    echo "{"
    echo "  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
    echo "  \"dotfiles_dir\": \"$DOTFILES_DIR\","
    echo "  \"results\": ["

    local first=true
    for result in "${VALIDATION_RESULTS[@]}"; do
        if $first; then
            first=false
        else
            echo ","
        fi
        echo -n "    $result"
    done

    echo ""
    echo "  ],"

    # Summary counts
    local ok_count=0
    local warn_count=0
    local error_count=0

    for result in "${VALIDATION_RESULTS[@]}"; do
        if [[ "$result" == *'"status":"ok"'* ]]; then
            ((ok_count++))
        elif [[ "$result" == *'"status":"warn"'* ]]; then
            ((warn_count++))
        elif [[ "$result" == *'"status":"error"'* ]]; then
            ((error_count++))
        fi
    done

    echo "  \"summary\": {"
    echo "    \"ok\": $ok_count,"
    echo "    \"warn\": $warn_count,"
    echo "    \"error\": $error_count,"
    echo "    \"total\": $((ok_count + warn_count + error_count))"
    echo "  }"
    echo "}"
}

# ============================================================================
# Utility Functions
# ============================================================================

# Check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Get the real path of a symlink
get_symlink_target() {
    if [[ -L "$1" ]]; then
        readlink "$1"
    else
        echo ""
    fi
}

# Create backup of a file
backup_file() {
    local file="$1"
    local backup_dir="${2:-$HOME/.dotfiles-backup}"

    if [[ -e "$file" ]] && [[ ! -L "$file" ]]; then
        mkdir -p "$backup_dir"
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local filename=$(basename "$file")
        cp "$file" "$backup_dir/${filename}.${timestamp}.bak"
        log_info "Backed up $file to $backup_dir/${filename}.${timestamp}.bak"
        return 0
    fi
    return 1
}

# Ensure parent directory exists
ensure_parent_dir() {
    local file="$1"
    local parent=$(dirname "$file")
    if [[ ! -d "$parent" ]]; then
        mkdir -p "$parent"
        log_info "Created directory: $parent"
    fi
}
