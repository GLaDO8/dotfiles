#!/bin/bash
# Backup Claude config plus shared agent docs and skills from ~/.claude, ~/.codex, and ~/.agents to dotfiles
#
# Usage: ./backup.sh
#
# Thin wrapper around the shared backup-config library.
# Called directly and also by the SessionEnd hook in settings.json.
#
# Source of truth: ~/.claude/ for Claude-specific config, ~/.codex/ for
# Codex-specific prompt files, and ~/.agents/{agent-docs,skills}/ for shared
# cross-agent assets
# mirrored into Claude and Codex
# Backup location: dotfiles/claude/, dotfiles/codex/, and dotfiles/agents/{agent-docs,skills}/

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
