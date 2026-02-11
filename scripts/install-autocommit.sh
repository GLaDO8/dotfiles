#!/usr/bin/env bash
#
# install-autocommit.sh — Install or uninstall the dotfiles autocommit launchd agent
#
# Usage:
#   install-autocommit.sh              # Install and load the agent
#   install-autocommit.sh --uninstall  # Stop and remove the agent
#
set -euo pipefail

LABEL="com.glado8.dotfiles-autocommit"
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLIST_SRC="$DOTFILES_DIR/launchd/${LABEL}.plist"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_DST="$LAUNCH_AGENTS_DIR/${LABEL}.plist"
GUI_DOMAIN="gui/$(id -u)"

uninstall() {
    echo "Uninstalling $LABEL..."

    # Bootout (stop and unload) — ignore errors if not loaded
    launchctl bootout "$GUI_DOMAIN/$LABEL" 2>/dev/null && \
        echo "Agent stopped and unloaded" || \
        echo "Agent was not loaded (already stopped)"

    if [[ -f "$PLIST_DST" ]]; then
        rm -f "$PLIST_DST"
        echo "Removed $PLIST_DST"
    fi

    echo "Uninstall complete."
}

install() {
    if [[ ! -f "$PLIST_SRC" ]]; then
        echo "Error: plist not found at $PLIST_SRC" >&2
        exit 1
    fi

    # Unload existing if present
    launchctl bootout "$GUI_DOMAIN/$LABEL" 2>/dev/null || true

    # Ensure LaunchAgents directory exists
    mkdir -p "$LAUNCH_AGENTS_DIR"

    # Copy plist (not symlink — launchd is unreliable with symlinks)
    cp "$PLIST_SRC" "$PLIST_DST"
    echo "Copied plist to $PLIST_DST"

    # Make the autocommit script executable
    chmod +x "$DOTFILES_DIR/scripts/dotfiles-autocommit.sh"

    # Load the agent
    launchctl bootstrap "$GUI_DOMAIN" "$PLIST_DST"
    echo "Agent loaded successfully"

    echo ""
    echo "Verify with:"
    echo "  launchctl list | grep dotfiles"
    echo "  tail -f ~/Library/Logs/dotfiles-autocommit.log"
}

case "${1:-}" in
    --uninstall)
        uninstall
        ;;
    *)
        install
        ;;
esac
