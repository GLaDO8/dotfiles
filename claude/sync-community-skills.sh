#!/bin/bash
# Sync community skills between ~/.agents/skills/ and dotfiles
#
# This script:
# 1. Finds new skills in ~/.agents/skills/ (added via npx skills add)
# 2. Moves them to dotfiles/claude/community-skills/
# 3. Creates symlinks back to ~/.agents/skills/
#
# Run this after adding new community skills via npx

set -e

DOTFILES_COMMUNITY="$HOME/dotfiles/claude/community-skills"
AGENTS_SKILLS="$HOME/.agents/skills"

# Ensure directories exist
mkdir -p "$DOTFILES_COMMUNITY"
mkdir -p "$AGENTS_SKILLS"

echo "Syncing community skills..."

# Find new skills (directories that aren't symlinks)
new_skills=0
for skill_dir in "$AGENTS_SKILLS"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")

    # Skip if it's already a symlink
    if [ -L "${AGENTS_SKILLS}/${skill_name}" ]; then
        continue
    fi

    # Skip .DS_Store and other hidden files
    [[ "$skill_name" == .* ]] && continue

    echo "Found new skill: $skill_name"

    # Check if already exists in dotfiles
    if [ -d "$DOTFILES_COMMUNITY/$skill_name" ]; then
        echo "  Already in dotfiles, replacing with symlink..."
        rm -rf "$AGENTS_SKILLS/$skill_name"
    else
        echo "  Moving to dotfiles..."
        mv "$AGENTS_SKILLS/$skill_name" "$DOTFILES_COMMUNITY/$skill_name"
    fi

    # Create symlink
    ln -sv "$DOTFILES_COMMUNITY/$skill_name" "$AGENTS_SKILLS/$skill_name"
    ((new_skills++))
done

# Ensure all dotfiles skills are symlinked
for skill_dir in "$DOTFILES_COMMUNITY"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")

    # Skip hidden directories
    [[ "$skill_name" == .* ]] && continue

    if [ ! -e "$AGENTS_SKILLS/$skill_name" ]; then
        echo "Creating symlink for: $skill_name"
        ln -sv "$DOTFILES_COMMUNITY/$skill_name" "$AGENTS_SKILLS/$skill_name"
        ((new_skills++))
    fi
done

if [ $new_skills -eq 0 ]; then
    echo "All skills already synced."
else
    echo "Synced $new_skills skill(s)."
fi

echo ""
echo "Current community skills:"
ls -la "$AGENTS_SKILLS" | grep -E "^[dl]" | grep -v "^\."
