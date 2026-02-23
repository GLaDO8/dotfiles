#!/usr/bin/env bash
#
# backup-scout.sh — Config scouting functions
#
# Discovers new configuration directories in ~/.config/ and
# ~/Library/Application Support/ that aren't yet tracked in dotfiles.
#
# Sourced by the backup orchestrator. Not intended for direct execution.
#
# Requires:
#   - DOTFILES_DIR to be set by the caller
#   - common.sh to be sourced first
#

# Sourced-file safety: enable strict mode so errors in library functions
# propagate correctly to the caller.
set -euo pipefail

# ============================================================================
# scout_new_configs — Find untracked ~/.config directories
# ============================================================================
# Scans ~/.config/ for directories not already tracked under dotfiles config/.
# Echoes untracked directory names, one per line.

scout_new_configs() {
    local config_src="$HOME/.config"
    local config_dest="${DOTFILES_DIR:?DOTFILES_DIR must be set}/config"

    _scan_status "Scanning ~/.config directories..."

    if [[ ! -d "$config_src" ]]; then
        log_warn "$config_src does not exist"
        return 0
    fi

    # Get list of already-tracked config dirs
    local tracked=()
    if [[ -d "$config_dest" ]]; then
        local dir_name
        for dir_path in "$config_dest"/*/; do
            [[ -d "$dir_path" ]] || continue
            dir_name=$(basename "$dir_path")
            tracked+=("$dir_name")
        done
    fi

    # Scan ~/.config for directories
    local src_name
    for src_path in "$config_src"/*/; do
        [[ -d "$src_path" ]] || continue
        src_name=$(basename "$src_path")

        # Skip hidden directories
        [[ "$src_name" == .* ]] && continue

        # Check if already tracked
        local is_tracked=false
        local t
        for t in "${tracked[@]+"${tracked[@]}"}"; do
            if [[ "$t" == "$src_name" ]]; then
                is_tracked=true
                break
            fi
        done

        if ! $is_tracked; then
            echo "$src_name"
        fi
    done
    _scan_done
}

# ============================================================================
# scout_app_support — Check notable App Support dirs for configs
# ============================================================================
# Checks a curated list of ~/Library/Application Support/ directories for
# apps that commonly have user-editable configuration.
# Echoes found app names, one per line.

scout_app_support() {
    local app_support="$HOME/Library/Application Support"

    if [[ ! -d "$app_support" ]]; then
        log_warn "$app_support does not exist"
        return 0
    fi

    # Curated list of apps with notable configs in Application Support
    local candidates=(
        "Cursor"
        "Code"          # VS Code
        "Zed"
        "Claude"
        "Ghostty"
        "Raycast"
        "1Password"
        "Obsidian"
    )

    local candidate
    for candidate in "${candidates[@]}"; do
        if [[ -d "$app_support/$candidate" ]]; then
            echo "$candidate"
        fi
    done
}
