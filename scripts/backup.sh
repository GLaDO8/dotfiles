#!/usr/bin/env bash
#
# backup.sh — Interactive dotfiles backup with discovery
#
# Syncs configs from the system into the dotfiles repo, discovers new
# packages/apps/configs, and offers to commit and push changes.
#
# Usage:
#   scripts/backup.sh              # Interactive full backup
#   scripts/backup.sh --quick      # Non-interactive: sync configs + commit
#   scripts/backup.sh --scout      # Only run discovery (no sync/commit)
#   scripts/backup.sh --no-commit  # Sync but don't commit/push
#   scripts/backup.sh --dry-run    # Preview mode — no changes
#   scripts/backup.sh --auto       # For autocommit daemon: quick sync, no push
#
set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCK_FILE="/tmp/dotfiles-autocommit.lock"

# Flags
DRY_RUN=false
QUICK_MODE=false
SCOUT_ONLY=false
NO_COMMIT=false
AUTO_MODE=false

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --dry-run)    DRY_RUN=true ;;
        --quick)      QUICK_MODE=true ;;
        --scout)      SCOUT_ONLY=true ;;
        --no-commit)  NO_COMMIT=true ;;
        --auto)       AUTO_MODE=true; QUICK_MODE=true; NO_COMMIT=true ;;
        -h|--help)
            echo "Usage: scripts/backup.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --quick       Non-interactive: sync configs + commit"
            echo "  --scout       Only run discovery (no sync/commit)"
            echo "  --no-commit   Sync but don't commit/push"
            echo "  --dry-run     Preview mode — no changes"
            echo "  --auto        For autocommit daemon: quick sync, no push"
            echo "  -h, --help    Show this help"
            exit 0
            ;;
    esac
done

# ============================================================================
# Source libraries
# ============================================================================

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/gum.sh"
source "$SCRIPT_DIR/lib/backup-config.sh"
source "$SCRIPT_DIR/lib/backup-brew.sh"
source "$SCRIPT_DIR/lib/backup-scout.sh"

# ============================================================================
# Lock management (shared with autocommit daemon)
# ============================================================================

acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid
        pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            gum_log "warn" "Another instance is running (PID $pid), exiting"
            return 1
        fi
        rm -f "$LOCK_FILE"
    fi
    echo $$ > "$LOCK_FILE"
    return 0
}

release_lock() {
    rm -f "$LOCK_FILE"
}

# ============================================================================
# Step 1 — Config Sync
# ============================================================================

step_sync_configs() {
    gum_header "Config Sync"

    # Show change detection report
    report_config_changes

    echo ""
    gum_log "info" "Syncing tracked configs..."
    sync_configs "$DRY_RUN"

    echo ""
    gum_log "info" "Syncing Claude Code configs..."
    sync_claude_configs "$DRY_RUN"
}

# ============================================================================
# Step 2 — Discovery Summary
# ============================================================================

step_discovery() {
    gum_header "Backup Scout"

    local new_brews="" new_casks="" new_apps="" new_mas="" new_configs=""
    local brew_count=0 cask_count=0 app_count=0 mas_count=0 config_count=0
    local duplicates="" dup_count=0

    # Run discovery with inline progress (stderr shows refreshing status)
    printf "  Scanning brew formulae" >&2
    new_brews=$(discover_new_brews) || new_brews=""
    printf '\r\033[K' >&2
    [[ -n "$new_brews" ]] && brew_count=$(echo "$new_brews" | wc -l | tr -d ' ')
    gum_log "info" "Brew formulae: $brew_count new"

    printf "  Scanning casks" >&2
    new_casks=$(discover_new_casks) || new_casks=""
    printf '\r\033[K' >&2
    [[ -n "$new_casks" ]] && cask_count=$(echo "$new_casks" | wc -l | tr -d ' ')
    gum_log "info" "Casks: $cask_count new"

    printf "  Scanning /Applications" >&2
    new_apps=$(discover_new_apps) || new_apps=""
    printf '\r\033[K' >&2
    [[ -n "$new_apps" ]] && app_count=$(echo "$new_apps" | wc -l | tr -d ' ')
    gum_log "info" "Apps: $app_count new"

    printf "  Scanning Mac App Store" >&2
    new_mas=$(discover_new_mas) || new_mas=""
    printf '\r\033[K' >&2
    [[ -n "$new_mas" ]] && mas_count=$(echo "$new_mas" | wc -l | tr -d ' ')
    gum_log "info" "MAS apps: $mas_count new"

    printf "  Scanning ~/.config" >&2
    new_configs=$(scout_new_configs) || new_configs=""
    printf '\r\033[K' >&2
    [[ -n "$new_configs" ]] && config_count=$(echo "$new_configs" | wc -l | tr -d ' ')
    gum_log "info" "Configs: $config_count new"

    duplicates=$(detect_brewfile_duplicates 2>/dev/null) || duplicates=""
    [[ -n "$duplicates" ]] && dup_count=$(echo "$duplicates" | wc -l | tr -d ' ')

    # Show summary
    echo ""
    echo "┌─ Discovery Summary ─────────────────────┐"
    echo "│                                          │"
    printf "│  %-3d new brew formulae                   │\n" "$brew_count"
    printf "│  %-3d new casks                           │\n" "$cask_count"
    printf "│  %-3d new apps in /Applications           │\n" "$app_count"
    printf "│  %-3d new Mac App Store apps              │\n" "$mas_count"
    printf "│  %-3d untracked configs in ~/.config      │\n" "$config_count"
    [[ "$dup_count" -gt 0 ]] && printf "│  %-3d duplicate Brewfile entries           │\n" "$dup_count"
    echo "│                                          │"
    echo "└──────────────────────────────────────────┘"
    echo ""

    local total=$((brew_count + cask_count + app_count + mas_count + config_count))
    if (( total == 0 && dup_count == 0 )); then
        gum_log "info" "Everything is tracked — nothing new found"
        return 0
    fi

    # Iterate through each non-empty category sequentially
    local category
    for category in \
        "Brew formulae ($brew_count)" \
        "Casks ($cask_count)" \
        "Apps ($app_count)" \
        "MAS apps ($mas_count)" \
        "Configs ($config_count)" \
        "Brewfile duplicates ($dup_count)"; do

        # Extract the count from the label — skip if zero
        local count
        count=$(echo "$category" | grep -oE '[0-9]+' | tail -1)
        (( count == 0 )) && continue

        step_drilldown "$category" "$new_brews" "$new_casks" "$new_apps" "$new_mas" "$new_configs" "$duplicates"
    done
}

# ============================================================================
# Step 3 — Category Drill-Down
# ============================================================================

step_drilldown() {
    local category="$1"
    local new_brews="$2"
    local new_casks="$3"
    local new_apps="$4"
    local new_mas="$5"
    local new_configs="$6"
    local duplicates="$7"

    echo ""
    gum_log "info" "Reviewing: $category"

    case "$category" in
        "Brew formulae"*)
            local items=()
            while IFS= read -r item; do
                [[ -n "$item" ]] && items+=("$item")
            done <<< "$new_brews"

            local selected
            selected=$(gum_filter "Select formulae to add to Brewfile:" "${items[@]}") || true
            if [[ -n "$selected" ]]; then
                local to_add=()
                while IFS= read -r item; do
                    [[ -n "$item" ]] && to_add+=("${item%% — *}")
                done <<< "$selected"

                if [[ "$DRY_RUN" == "true" ]]; then
                    gum_log "info" "[DRY-RUN] Would add ${#to_add[@]} formulae to Brewfile"
                else
                    update_brewfile "brew" "${to_add[@]}"
                fi
            fi
            ;;

        "Casks"*)
            local items=()
            while IFS= read -r item; do
                [[ -n "$item" ]] && items+=("$item")
            done <<< "$new_casks"

            local selected
            selected=$(gum_filter "Select casks to add to Brewfile:" "${items[@]}") || true
            if [[ -n "$selected" ]]; then
                local to_add=()
                while IFS= read -r item; do
                    [[ -n "$item" ]] && to_add+=("${item%% — *}")
                done <<< "$selected"

                if [[ "$DRY_RUN" == "true" ]]; then
                    gum_log "info" "[DRY-RUN] Would add ${#to_add[@]} casks to Brewfile"
                else
                    update_brewfile "cask" "${to_add[@]}"
                fi
            fi
            ;;

        "Apps"*)
            local items=()
            while IFS= read -r item; do
                [[ -n "$item" ]] && items+=("$item")
            done <<< "$new_apps"

            local selected
            selected=$(gum_filter "Select apps to add as casks:" "${items[@]}") || true
            if [[ -n "$selected" ]]; then
                local to_add=()
                while IFS= read -r item; do
                    [[ -n "$item" ]] && to_add+=("${item%% — *}")
                done <<< "$selected"

                if [[ "$DRY_RUN" == "true" ]]; then
                    gum_log "info" "[DRY-RUN] Would add ${#to_add[@]} app casks to Brewfile"
                else
                    update_brewfile "cask" "${to_add[@]}"
                fi
            fi
            ;;

        "MAS apps"*)
            local items=()
            while IFS= read -r item; do
                [[ -n "$item" ]] && items+=("$item")
            done <<< "$new_mas"

            local selected
            selected=$(gum_filter "Select MAS apps to add to Brewfile:" "${items[@]}") || true
            if [[ -n "$selected" ]]; then
                local to_add=()
                while IFS= read -r item; do
                    [[ -n "$item" ]] && to_add+=("$item")
                done <<< "$selected"

                if [[ "$DRY_RUN" == "true" ]]; then
                    gum_log "info" "[DRY-RUN] Would add ${#to_add[@]} MAS apps to Brewfile"
                else
                    update_brewfile "mas" "${to_add[@]}"
                fi
            fi
            ;;

        "Configs"*)
            local items=()
            while IFS= read -r item; do
                [[ -n "$item" ]] && items+=("$item")
            done <<< "$new_configs"

            local selected
            selected=$(gum_filter "Select configs to start tracking:" "${items[@]}") || true
            if [[ -n "$selected" ]]; then
                while IFS= read -r config_name; do
                    [[ -z "$config_name" ]] && continue
                    local src="$HOME/.config/$config_name"
                    local dest="$DOTFILES_DIR/config/$config_name"

                    if [[ "$DRY_RUN" == "true" ]]; then
                        gum_log "info" "[DRY-RUN] Would copy $src → $dest"
                    else
                        cp -R "$src" "$dest"
                        gum_log "info" "Copied: $config_name → config/$config_name"
                        gum_log "warn" "Remember to add symlink entries to install.sh and symlinks.sh"
                    fi
                done <<< "$selected"
            fi
            ;;

        "Brewfile duplicates"*)
            echo "Duplicate entries found:"
            echo "$duplicates"
            echo ""
            if gum_confirm "Remove duplicates from Brewfile?"; then
                if [[ "$DRY_RUN" == "true" ]]; then
                    gum_log "info" "[DRY-RUN] Would remove duplicate Brewfile entries"
                else
                    # Remove duplicate lines (keep first occurrence)
                    local tmpfile
                    tmpfile=$(mktemp)
                    awk '!seen[$0]++' "$DOTFILES_DIR/Brewfile" > "$tmpfile"
                    mv "$tmpfile" "$DOTFILES_DIR/Brewfile"
                    gum_log "info" "Removed duplicate entries from Brewfile"
                fi
            fi
            ;;
    esac
}

# ============================================================================
# Step 4 — Commit & Push
# ============================================================================

step_commit() {
    gum_header "Commit & Push"

    cd "$DOTFILES_DIR"

    # Check for changes
    local changes
    changes=$(git diff --stat 2>/dev/null) || changes=""
    local untracked
    untracked=$(git ls-files --others --exclude-standard 2>/dev/null) || untracked=""

    if [[ -z "$changes" && -z "$untracked" ]]; then
        gum_log "info" "No changes to commit"
        return 0
    fi

    # Show diff summary
    echo ""
    git diff --stat 2>/dev/null || true
    if [[ -n "$untracked" ]]; then
        echo ""
        echo "Untracked files:"
        echo "$untracked" | while IFS= read -r f; do echo "  + $f"; done
    fi
    echo ""

    if [[ "$DRY_RUN" == "true" ]]; then
        gum_log "info" "[DRY-RUN] Would commit and push changes"
        return 0
    fi

    if ! gum_confirm "Commit and push changes?"; then
        gum_log "info" "Skipping commit"
        return 0
    fi

    # Build commit message
    local all_files
    all_files=$(printf '%s\n' "$(git diff --name-only 2>/dev/null)" "$untracked" | grep -v '^$' | sort -u)
    local file_count
    file_count=$(echo "$all_files" | wc -l | tr -d ' ')

    local commit_msg
    if (( file_count == 1 )); then
        commit_msg="backup: update $all_files"
    else
        commit_msg="backup: update $file_count files"
    fi

    git add -A
    git commit --no-gpg-sign -m "$commit_msg"
    gum_log "info" "Committed: $commit_msg"

    # Push
    if gum_confirm "Push to origin?"; then
        if git push origin master 2>/dev/null; then
            gum_log "info" "Pushed successfully"
        else
            gum_log "error" "Push failed — try again later"
        fi
    fi
}

# ============================================================================
# Step 5 — Validation (optional)
# ============================================================================

step_validate() {
    if [[ -x "$SCRIPT_DIR/validate.sh" ]]; then
        gum_log "info" "Running symlink validation..."
        "$SCRIPT_DIR/validate.sh" || true
    fi
}

# ============================================================================
# Main
# ============================================================================

main() {
    gum_header "Dotfiles Backup"

    if $DRY_RUN; then
        gum_log "warn" "DRY-RUN MODE — no changes will be made"
        echo ""
    fi

    # Acquire lock to prevent races with autocommit daemon
    if ! acquire_lock; then
        exit 1
    fi
    trap release_lock EXIT

    if $SCOUT_ONLY; then
        step_discovery
        return 0
    fi

    # Step 1: Always sync configs
    step_sync_configs

    # Step 2-3: Discovery + drill-down (skip in quick/auto mode)
    if ! $QUICK_MODE; then
        echo ""
        step_discovery
    fi

    # Step 4: Commit & push (skip with --no-commit)
    if ! $NO_COMMIT; then
        echo ""
        step_commit
    fi

    # Step 5: Validate (non-quick only)
    if ! $QUICK_MODE; then
        echo ""
        step_validate
    fi

    echo ""
    gum_log "info" "Backup complete"
}

main
