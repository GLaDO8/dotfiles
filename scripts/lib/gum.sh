#!/usr/bin/env bash
#
# gum.sh — Gum CLI wrapper with plain-bash fallbacks
#
# Provides pretty TUI functions via charmbracelet/gum when available,
# falling back gracefully to basic bash equivalents.
#
# Sourced by the backup orchestrator. Not intended for direct execution.
#

# Sourced-file safety: enable strict mode so errors in library functions
# propagate correctly to the caller.
set -euo pipefail

# ---------------------------------------------------------------------------
# Dependency: common.sh must be sourced first for color variables
# ---------------------------------------------------------------------------

if [[ -z "${RED:-}" ]]; then
    echo "ERROR: gum.sh requires common.sh to be sourced first" >&2
    return 1
fi

# ---------------------------------------------------------------------------
# Detect gum availability at source time
# ---------------------------------------------------------------------------

if command -v gum &>/dev/null; then
    export HAS_GUM=true
else
    export HAS_GUM=false
fi

# ============================================================================
# gum_confirm — Yes/no prompt
# ============================================================================
# Usage: gum_confirm "Are you sure?"
# Returns 0 for yes, 1 for no.

gum_confirm() {
    local prompt="${1:?gum_confirm requires a prompt}"

    if $HAS_GUM; then
        gum confirm "$prompt"
    else
        local answer
        read -r -p "$prompt [y/N] " answer
        [[ "$answer" =~ ^[Yy]$ ]]
    fi
}

# ============================================================================
# gum_choose — Single-select from a list
# ============================================================================
# Usage: gum_choose "Pick one:" "option1" "option2" "option3"
# Prints the selected option to stdout.

gum_choose() {
    local header="${1:?gum_choose requires a header}"
    shift
    local options=("$@")

    if (( ${#options[@]} == 0 )); then
        echo "ERROR: gum_choose requires at least one option" >&2
        return 1
    fi

    if $HAS_GUM; then
        printf '%s\n' "${options[@]}" | gum choose --header "$header"
    else
        echo "$header" >&2
        local PS3="Enter number: "
        local choice
        select choice in "${options[@]}"; do
            if [[ -n "$choice" ]]; then
                echo "$choice"
                return 0
            fi
            echo "Invalid selection. Try again." >&2
        done
    fi
}

# ============================================================================
# gum_filter — Multi-select from a list
# ============================================================================
# Usage: gum_filter "Select items:" "item1" "item2" "item3"
# Prints selected items to stdout, one per line.

gum_filter() {
    local header="${1:?gum_filter requires a header}"
    shift
    local items=("$@")

    if (( ${#items[@]} == 0 )); then
        echo "ERROR: gum_filter requires at least one item" >&2
        return 1
    fi

    if $HAS_GUM; then
        # Checkbox multi-select — items start unselected (discovery = opt-in)
        # Using gum choose (not gum filter) because Space toggles checkboxes.
        # gum filter captures Space for its search input, making checkboxes unusable.
        printf '%s\n' "${items[@]}" | gum choose --no-limit \
            --header "$header" \
            --show-help \
            --cursor.foreground="212" \
            --header.foreground="240" \
            --selected.foreground="212"
    else
        # Fallback: checkbox toggle (none selected by default)
        echo "$header" >&2
        echo "(Enter numbers to toggle, 'a' to select all, 'n' to select none, Enter to confirm)" >&2

        # Track selection state — none on by default
        local -a checked
        local i
        for i in "${!items[@]}"; do
            checked[$i]=0
        done

        while true; do
            # Render checkboxes
            echo "" >&2
            for i in "${!items[@]}"; do
                if (( checked[i] )); then
                    echo "  $((i + 1))) [x] ${items[$i]}" >&2
                else
                    echo "  $((i + 1))) [ ] ${items[$i]}" >&2
                fi
            done

            local input
            read -r -p "> " input

            # Confirm selection
            if [[ -z "$input" || "$input" == "done" ]]; then
                break
            fi

            # Select all / none
            if [[ "$input" == "a" ]]; then
                for i in "${!items[@]}"; do checked[$i]=1; done
                continue
            fi
            if [[ "$input" == "n" ]]; then
                for i in "${!items[@]}"; do checked[$i]=0; done
                continue
            fi

            # Toggle individual items
            for num in $input; do
                if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#items[@]} )); then
                    local idx=$((num - 1))
                    if (( checked[idx] )); then
                        checked[$idx]=0
                    else
                        checked[$idx]=1
                    fi
                else
                    echo "Invalid: $num" >&2
                fi
            done
        done

        # Output selected items
        for i in "${!items[@]}"; do
            (( checked[i] )) && echo "${items[$i]}"
        done
    fi
}

# ============================================================================
# gum_spin — Spinner while a command runs
# ============================================================================
# Usage: gum_spin "Doing something..." "sleep 5"
# Runs the command, showing a spinner if gum is available.

gum_spin() {
    local title="${1:?gum_spin requires a title}"
    local cmd="${2:?gum_spin requires a command}"

    if $HAS_GUM; then
        gum spin --title "$title" -- bash -c "$cmd"
    else
        echo -e "${BLUE}$title${NC}" >&2
        bash -c "$cmd"
    fi
}

# ============================================================================
# gum_header — Styled section header
# ============================================================================
# Usage: gum_header "Backup Manager"

gum_header() {
    local text="${1:?gum_header requires text}"

    if $HAS_GUM; then
        gum style --border double --padding "0 2" --margin "1 0" "$text"
    else
        local width=$(( ${#text} + 4 ))
        local border
        border=$(printf '═%.0s' $(seq 1 "$width"))
        echo ""
        echo "╔${border}╗"
        echo "║  ${text}  ║"
        echo "╚${border}╝"
        echo ""
    fi
}

# ============================================================================
# gum_log — Leveled log output
# ============================================================================
# Usage: gum_log "info" "Starting backup..."
# Levels: debug, info, warn, error

gum_log() {
    local level="${1:?gum_log requires a level}"
    local message="${2:?gum_log requires a message}"

    if $HAS_GUM; then
        gum log --level "$level" "$message"
    else
        case "$level" in
            debug) echo -e "${CYAN}[DEBUG]${NC} $message" ;;
            info)  echo -e "${BLUE}[INFO]${NC} $message" ;;
            warn)  echo -e "${YELLOW}[WARN]${NC} $message" ;;
            error) echo -e "${RED}[ERROR]${NC} $message" ;;
            *)     echo -e "${GREEN}[$level]${NC} $message" ;;
        esac
    fi
}
