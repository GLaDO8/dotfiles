#!/usr/bin/env bash
#
# backup-config.sh — Config sync functions
#
# Provides the CONFIG_MAP of all tracked configuration files and functions
# to sync them from their source locations into the dotfiles repository.
#
# Sourced by the backup orchestrator. Not intended for direct execution.
#
# Requires:
#   - DOTFILES_DIR to be set by the caller
#   - common.sh to be sourced first
#
# Compatible with bash 3.2+ (macOS default) — uses parallel arrays
# instead of associative arrays.
#

# Sourced-file safety: enable strict mode so errors in library functions
# propagate correctly to the caller.
set -euo pipefail

# ============================================================================
# CONFIG_MAP — Source path → dotfiles destination (relative to DOTFILES_DIR)
# ============================================================================
# Parallel arrays: CONFIG_SOURCES[i] maps to CONFIG_DESTS[i].
# Add new entries to BOTH arrays to track more files.

CONFIG_SOURCES=(
    # Zsh
    "$HOME/.zshrc"
    "$HOME/.zsh_plugins.txt"
    # Zed
    "$HOME/.config/zed/settings.json"
    "$HOME/.config/zed/keymap.json"
    "$HOME/.config/zed/tasks.json"
    # Ghostty
    "$HOME/.config/ghostty/config"
    # aichat
    "$HOME/.config/aichat/config.yaml"
    # GitHub CLI
    "$HOME/.config/gh/config.yml"
    # Zellij
    "$HOME/.config/zellij/config.kdl"
    "$HOME/.config/zellij/layouts/claude.kdl"
    # Helix
    "$HOME/.config/helix/config.toml"
    # Neovim
    "$HOME/.config/nvim/init.lua"
    "$HOME/.config/nvim/lazy-lock.json"
    # Yazi
    "$HOME/.config/yazi/keymap.toml"
    "$HOME/.config/yazi/yazi.toml"
)

CONFIG_DESTS=(
    # Zsh
    "zsh/.zshrc"
    "zsh/.zsh_plugins.txt"
    # Zed
    "config/zed/settings.json"
    "config/zed/keymap.json"
    "config/zed/tasks.json"
    # Ghostty
    "config/ghostty/config"
    # aichat
    "config/aichat/config.yaml"
    # GitHub CLI
    "config/gh/config.yml"
    # Zellij
    "config/zellij/config.kdl"
    "config/zellij/layouts/claude.kdl"
    # Helix
    "config/helix/config.toml"
    # Neovim
    "config/nvim/init.lua"
    "config/nvim/lazy-lock.json"
    # Yazi
    "config/yazi/keymap.toml"
    "config/yazi/yazi.toml"
)

# ============================================================================
# sync_configs — Copy changed config files into dotfiles
# ============================================================================
# Usage: sync_configs "true"   # dry run — only report what would change
#        sync_configs "false"  # actually copy files

sync_configs() {
    local dry_run="${1:-false}"
    local changed=0
    local skipped=0
    local i

    for i in "${!CONFIG_SOURCES[@]}"; do
        local src="${CONFIG_SOURCES[$i]}"
        local rel_dest="${CONFIG_DESTS[$i]}"
        local dest="${DOTFILES_DIR:?DOTFILES_DIR must be set}/$rel_dest"

        # Skip if source doesn't exist
        if [[ ! -f "$src" ]]; then
            log_warn "Source not found, skipping: $src"
            ((skipped++)) || true
            continue
        fi

        # Check if files differ
        if [[ -f "$dest" ]] && diff -q "$src" "$dest" &>/dev/null; then
            continue
        fi

        # Files differ or destination doesn't exist yet
        if [[ "$dry_run" == "true" ]]; then
            if [[ -f "$dest" ]]; then
                log_info "[DRY-RUN] Would update: $rel_dest"
            else
                log_info "[DRY-RUN] Would create: $rel_dest"
            fi
        else
            mkdir -p "$(dirname "$dest")"
            cp "$src" "$dest"
            log_success "Updated: $rel_dest"
        fi
        ((changed++)) || true
    done

    if (( changed == 0 )); then
        log_info "All tracked configs are up to date"
    else
        log_info "$changed config(s) synced ($skipped skipped)"
    fi

    return 0
}

# ============================================================================
# sync_claude_configs — Sync Claude Code configuration into dotfiles
# ============================================================================
# Mirrors the logic from claude/backup.sh: copies files from ~/.claude/
# and ~/.agents/skills/ into the dotfiles claude/ directory.

sync_claude_configs() {
    local dry_run="${1:-false}"
    local claude_dest="${DOTFILES_DIR:?DOTFILES_DIR must be set}/claude"
    local changed=0

    # --- Individual config files ---

    local claude_srcs=(
        "$HOME/.claude/CLAUDE.md"
        "$HOME/.claude/RTK.md"
        "$HOME/.claude/settings.json"
        "$HOME/.claude/statusline.sh"
        "$HOME/.claude/statusline.conf"
        "$HOME/.claude/statusline-command.sh"
        "$HOME/.claude/sl-toggle.sh"
    )
    local claude_dests=(
        "$claude_dest/CLAUDE.md"
        "$claude_dest/RTK.md"
        "$claude_dest/settings.json"
        "$claude_dest/statusline.sh"
        "$claude_dest/statusline.conf"
        "$claude_dest/statusline-command.sh"
        "$claude_dest/sl-toggle.sh"
    )

    local i
    for i in "${!claude_srcs[@]}"; do
        local src="${claude_srcs[$i]}"
        local dest="${claude_dests[$i]}"

        [[ -f "$src" ]] || continue

        if [[ -f "$dest" ]] && diff -q "$src" "$dest" &>/dev/null; then
            continue
        fi

        if [[ "$dry_run" == "true" ]]; then
            log_info "[DRY-RUN] Would sync: $(basename "$src")"
        else
            mkdir -p "$(dirname "$dest")"
            cp "$src" "$dest"
            log_success "Synced: $(basename "$src")"
        fi
        ((changed++)) || true
    done

    # --- Hooks directory (rsync to capture subdirs like sounds/) ---

    if [[ -d "$HOME/.claude/hooks" ]]; then
        local hooks_dest="$claude_dest/hooks"
        if [[ "$dry_run" == "true" ]]; then
            log_info "[DRY-RUN] Would rsync hooks/"
        else
            mkdir -p "$hooks_dest"
            rsync -a --delete \
                --exclude='.*' \
                "$HOME/.claude/hooks/" "$hooks_dest/"
            log_success "Synced hooks/"
        fi
        ((changed++)) || true
    fi

    # --- Agent-docs directory ---

    if [[ -d "$HOME/.claude/agent-docs" ]]; then
        local agentdocs_dest="$claude_dest/agent-docs"
        if [[ "$dry_run" == "true" ]]; then
            log_info "[DRY-RUN] Would rsync agent-docs/"
        else
            mkdir -p "$agentdocs_dest"
            rsync -a --delete "$HOME/.claude/agent-docs/" "$agentdocs_dest/"
            log_success "Synced agent-docs/"
        fi
        ((changed++)) || true
    fi

    # --- Rules directory ---

    if [[ -d "$HOME/.claude/rules" ]]; then
        local rules_dest="$claude_dest/rules"
        if [[ "$dry_run" == "true" ]]; then
            log_info "[DRY-RUN] Would rsync rules/"
        else
            mkdir -p "$rules_dest"
            rsync -a --delete "$HOME/.claude/rules/" "$rules_dest/"
            log_success "Synced rules/"
        fi
        ((changed++)) || true
    fi

    # --- Plugins (all json config files) ---

    if [[ -d "$HOME/.claude/plugins" ]]; then
        local plugins_dest="$claude_dest/plugins"
        local plugin_file plugin_name

        for plugin_file in "$HOME/.claude/plugins"/*.json; do
            [[ -f "$plugin_file" ]] || continue
            plugin_name=$(basename "$plugin_file")
            # Skip ephemeral caches
            [[ "$plugin_name" == "install-counts-cache.json" ]] && continue

            if [[ -f "$plugins_dest/$plugin_name" ]] && diff -q "$plugin_file" "$plugins_dest/$plugin_name" &>/dev/null; then
                continue
            fi

            if [[ "$dry_run" == "true" ]]; then
                log_info "[DRY-RUN] Would sync plugin config: $plugin_name"
            else
                mkdir -p "$plugins_dest"
                cp "$plugin_file" "$plugins_dest/$plugin_name"
                log_success "Synced plugin config: $plugin_name"
            fi
            ((changed++)) || true
        done
    fi

    # --- Personal skills (non-symlink dirs in ~/.claude/skills/) ---

    if [[ -d "$HOME/.claude/skills" ]]; then
        local skills_dest="$claude_dest/skills"
        local skill_dir skill_name

        for skill_dir in "$HOME/.claude/skills"/*/; do
            [[ -d "$skill_dir" ]] || continue
            skill_name=$(basename "$skill_dir")
            [[ -L "${skill_dir%/}" ]] && continue

            if [[ "$dry_run" == "true" ]]; then
                log_info "[DRY-RUN] Would rsync skill: $skill_name"
            else
                mkdir -p "$skills_dest/$skill_name"
                rsync -a --delete "$skill_dir" "$skills_dest/$skill_name/"
                log_success "Synced skill: $skill_name"
            fi
            ((changed++)) || true
        done
    fi

    # --- Community skills from ~/.agents/skills/ ---

    if [[ -d "$HOME/.agents/skills" ]]; then
        local agents_dest="$claude_dest/agents-skills"
        local skill_dir skill_name

        for skill_dir in "$HOME/.agents/skills"/*/; do
            [[ -d "$skill_dir" ]] || continue
            skill_name=$(basename "$skill_dir")
            [[ "$skill_name" == .* ]] && continue

            if [[ "$dry_run" == "true" ]]; then
                log_info "[DRY-RUN] Would rsync agents skill: $skill_name"
            else
                mkdir -p "$agents_dest/$skill_name"
                rsync -a --delete "$skill_dir" "$agents_dest/$skill_name/"
                log_success "Synced agents skill: $skill_name"
            fi
            ((changed++)) || true
        done
    fi

    # --- Summary ---

    if (( changed == 0 )); then
        log_info "All Claude configs are up to date"
    else
        local action="synced"
        [[ "$dry_run" == "true" ]] && action="would be synced"
        log_info "$changed Claude config item(s) $action"
    fi

    return 0
}

# ============================================================================
# report_config_changes — Show which configs differ from dotfiles
# ============================================================================

report_config_changes() {
    local changed=0
    local total=0
    local i

    printf "%-50s  %s\n" "CONFIG FILE" "STATUS"
    printf "%-50s  %s\n" "$(printf '─%.0s' $(seq 1 50))" "$(printf '─%.0s' $(seq 1 10))"

    for i in "${!CONFIG_SOURCES[@]}"; do
        local src="${CONFIG_SOURCES[$i]}"
        local rel_dest="${CONFIG_DESTS[$i]}"
        local dest="${DOTFILES_DIR:?DOTFILES_DIR must be set}/$rel_dest"
        local status
        ((total++)) || true

        if [[ ! -f "$src" ]]; then
            status="${YELLOW}missing${NC}"
        elif [[ ! -f "$dest" ]]; then
            status="${CYAN}new${NC}"
            ((changed++)) || true
        elif ! diff -q "$src" "$dest" &>/dev/null; then
            status="${RED}changed${NC}"
            ((changed++)) || true
        else
            status="${GREEN}ok${NC}"
        fi

        printf "%-50s  %b\n" "$rel_dest" "$status"
    done

    echo ""
    log_info "$changed of $total config(s) have pending changes"
}
