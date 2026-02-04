#!/bin/bash
# Backup Claude config from ~/.claude and ~/.agents to dotfiles
#
# Usage: ./backup.sh
#
# This script copies configuration FROM the source locations TO dotfiles.
# Source of truth: ~/.claude/ and ~/.agents/skills/
# Backup location: dotfiles/claude/backup/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/backup"

echo "Backing up Claude Code configuration..."

# Create backup directories
mkdir -p "$BACKUP_DIR/skills"
mkdir -p "$BACKUP_DIR/agents-skills"
mkdir -p "$BACKUP_DIR/hooks"

# Backup config files
echo "  - CLAUDE.md"
cp ~/.claude/CLAUDE.md "$BACKUP_DIR/"

echo "  - settings.json"
cp ~/.claude/settings.json "$BACKUP_DIR/"

echo "  - statusline-command.sh"
cp ~/.claude/statusline-command.sh "$BACKUP_DIR/"

# Backup hooks
if [ -d ~/.claude/hooks ]; then
    echo "  - Hooks from ~/.claude/hooks/"
    for hook_file in ~/.claude/hooks/*; do
        if [ -f "$hook_file" ]; then
            hook_name=$(basename "$hook_file")
            # Skip hidden files
            if [[ "$hook_name" != .* ]]; then
                echo "    - $hook_name"
                cp "$hook_file" "$BACKUP_DIR/hooks/"
            fi
        fi
    done
fi

# Backup personal skills (excluding symlinks to community skills)
echo "  - Personal skills from ~/.claude/skills/"
for skill_dir in ~/.claude/skills/*/; do
    skill_name=$(basename "$skill_dir")
    # Skip if it's a symlink (community skills are symlinked to ~/.agents/skills/)
    if [ ! -L "${skill_dir%/}" ]; then
        echo "    - $skill_name"
        rsync -a --delete "$skill_dir" "$BACKUP_DIR/skills/$skill_name/"
    fi
done

# Backup community skills from ~/.agents/skills/
echo "  - Community skills from ~/.agents/skills/"
for skill_dir in ~/.agents/skills/*/; do
    skill_name=$(basename "$skill_dir")
    # Skip hidden files and .DS_Store
    if [[ "$skill_name" != .* ]]; then
        echo "    - $skill_name"
        rsync -a --delete "$skill_dir" "$BACKUP_DIR/agents-skills/$skill_name/"
    fi
done

echo ""
echo "Backup complete!"
echo ""
echo "Backed up to: $BACKUP_DIR"
echo ""
echo "Don't forget to commit and push:"
echo "  cd $SCRIPT_DIR && git add -A && git commit -m 'Backup Claude config' && git push"
