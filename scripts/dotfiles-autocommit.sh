#!/usr/bin/env bash
#
# dotfiles-autocommit.sh — Auto-commit and push dotfiles changes
#
# Usage:
#   dotfiles-autocommit.sh             # Run normally
#   dotfiles-autocommit.sh --dry-run   # Preview what would happen
#
set -euo pipefail

# === Configuration ===
DOTFILES_DIR="$HOME/dotfiles"
LOCK_FILE="/tmp/dotfiles-autocommit.lock"
LOG_FILE="$HOME/Library/Logs/dotfiles-autocommit.log"
LOG_MAX_BYTES=1048576  # 1MB
PUSH_TIMEOUT=30
REMOTE="origin"
BRANCH="master"
DRY_RUN=false

# Ensure launchd has a usable PATH and SSH agent (1Password)
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
OP_AGENT_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
export SSH_AUTH_SOCK="$OP_AGENT_SOCK"
# Force git to use the 1Password agent with the full expanded path —
# the ~/.ssh/config IdentityAgent ~ may not expand in launchd context
export GIT_SSH_COMMAND="ssh -o IdentityAgent='$OP_AGENT_SOCK'"

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
    esac
done

# === Logging ===
log() {
    local msg
    msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" >> "$LOG_FILE"
    if $DRY_RUN; then
        echo "$msg"
    fi
}

rotate_log() {
    if [[ -f "$LOG_FILE" ]]; then
        local size
        size=$(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)
        if (( size > LOG_MAX_BYTES )); then
            mv "$LOG_FILE" "${LOG_FILE}.old"
            log "Log rotated (previous log was ${size} bytes)"
        fi
    fi
}

# === Lock management ===
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid
        pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            log "Another instance is running (PID $pid), skipping"
            return 1
        fi
        # Stale lock — previous run crashed
        log "Removing stale lock (PID $pid no longer running)"
        rm -f "$LOCK_FILE"
    fi
    echo $$ > "$LOCK_FILE"
    return 0
}

release_lock() {
    rm -f "$LOCK_FILE"
}

# === Main logic ===
main() {
    rotate_log
    log "--- Run started (dry_run=$DRY_RUN) ---"

    if ! acquire_lock; then
        return 0
    fi
    trap release_lock EXIT

    cd "$DOTFILES_DIR"

    # Check for uncommitted changes
    local has_changes=false
    local changed_files
    changed_files=$(git diff --name-only 2>/dev/null || true)
    local staged_files
    staged_files=$(git diff --cached --name-only 2>/dev/null || true)
    local untracked_files
    untracked_files=$(git ls-files --others --exclude-standard 2>/dev/null || true)

    if [[ -n "$changed_files" || -n "$staged_files" || -n "$untracked_files" ]]; then
        has_changes=true
    fi

    if $has_changes; then
        # Build a descriptive commit message
        local all_files
        all_files=$(printf '%s\n' "$changed_files" "$staged_files" "$untracked_files" | grep -v '^$' | sort -u)
        local file_count
        file_count=$(echo "$all_files" | wc -l | tr -d ' ')

        local commit_msg
        if (( file_count == 1 )); then
            commit_msg="auto: update $all_files"
        else
            commit_msg="auto: update $file_count files"
        fi

        log "Changes detected ($file_count file(s)): $(echo "$all_files" | tr '\n' ' ')"

        if $DRY_RUN; then
            log "[DRY-RUN] Would: git add -A && git commit --no-gpg-sign -m '$commit_msg'"
        else
            git add -A
            git commit --no-gpg-sign -m "$commit_msg" >> "$LOG_FILE" 2>&1
            log "Committed: $commit_msg"
        fi
    else
        log "No uncommitted changes"
    fi

    # Check for unpushed commits (handles previous failed pushes too)
    local local_head remote_head
    local_head=$(git rev-parse HEAD 2>/dev/null || echo "")
    remote_head=$(git rev-parse "${REMOTE}/${BRANCH}" 2>/dev/null || echo "")

    if [[ "$local_head" != "$remote_head" ]]; then
        log "Unpushed commits detected, pushing..."
        if $DRY_RUN; then
            log "[DRY-RUN] Would: git push $REMOTE $BRANCH"
        else
            if timeout "$PUSH_TIMEOUT" git push "$REMOTE" "$BRANCH" >> "$LOG_FILE" 2>&1; then
                log "Push successful"
            else
                log "Push failed (will retry on next trigger)"
            fi
        fi
    else
        log "Already in sync with ${REMOTE}/${BRANCH}"
    fi

    log "--- Run finished ---"
}

main
