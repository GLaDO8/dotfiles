#!/bin/bash
# Backup Claude config from ~/.claude and ~/.agents to dotfiles
#
# Usage: ./backup.sh
#
# Thin wrapper around the shared backup-config library.
# Called directly and also by the SessionEnd hook in settings.json.
#
# Source of truth: ~/.claude/ and ~/.agents/skills/
# Backup location: dotfiles/claude/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source shared libraries
source "$DOTFILES_DIR/scripts/lib/common.sh"
source "$DOTFILES_DIR/scripts/lib/backup-config.sh"

echo "Backing up Claude Code configuration..."
echo ""

sync_claude_configs "false"

echo ""
echo "Backup complete!"
echo ""
echo "Backed up to: $SCRIPT_DIR"
echo ""
echo "Don't forget to commit and push:"
echo "  cd $DOTFILES_DIR && git add -A && git commit -m 'Backup Claude config' && git push"
