#!/usr/bin/env bash
#
# Symlink validation and repair
#

# Define expected symlinks
# Format: "target_path:source_path" (relative to DOTFILES_DIR)
EXPECTED_SYMLINKS=(
    # Shell dotfiles
    "$HOME/.zshrc:zsh/.zshrc"
    "$HOME/.zsh_plugins.txt:zsh/.zsh_plugins.txt"
    "$HOME/.bash_profile:.bash_profile"
    "$HOME/.bashrc:.bashrc"

    # Git and tools
    "$HOME/.gitconfig:.gitconfig"
    "$HOME/.tmux.conf:.tmux.conf"
    "$HOME/.npmrc:.npmrc"

    # SSH
    "$HOME/.ssh/config:ssh/config"

    # Zed editor
    "$HOME/.config/zed/settings.json:config/zed/settings.json"
    "$HOME/.config/zed/keymap.json:config/zed/keymap.json"
    "$HOME/.config/zed/tasks.json:config/zed/tasks.json"

    # Ghostty terminal
    "$HOME/.config/ghostty/config:config/ghostty/config"

    # aichat
    "$HOME/.config/aichat/config.yaml:config/aichat/config.yaml"

    # GitHub CLI
    "$HOME/.config/gh/config.yml:config/gh/config.yml"

    # VS Code
    "$HOME/Library/Application Support/Code/User/settings.json:vscode/settings.json"
)

# ============================================================================
# Validation Functions
# ============================================================================

validate_symlinks() {
    print_section "Symlink Validation"

    local errors=0
    local warnings=0

    for entry in "${EXPECTED_SYMLINKS[@]}"; do
        local target="${entry%%:*}"
        local source_rel="${entry##*:}"
        local source_abs="$DOTFILES_DIR/$source_rel"

        # Check if source file exists in dotfiles
        if [[ ! -e "$source_abs" ]]; then
            log_warn "Source not in dotfiles: $source_rel"
            add_result "warn" "$target" "Source file missing in dotfiles: $source_rel" false
            ((warnings++))
            continue
        fi

        # Check if target exists
        if [[ ! -e "$target" ]] && [[ ! -L "$target" ]]; then
            log_error "Missing: $target"
            add_result "error" "$target" "Symlink missing, should point to $source_rel" true
            ((errors++))
            continue
        fi

        # Check if target is a symlink
        if [[ ! -L "$target" ]]; then
            log_error "Not a symlink: $target (is a regular file)"
            add_result "error" "$target" "Regular file exists instead of symlink" true
            ((errors++))
            continue
        fi

        # Check if symlink points to correct location
        local current_target=$(readlink "$target")

        # Handle both absolute and relative paths
        if [[ "$current_target" != "$source_abs" ]]; then
            # Also check if it's a relative path that resolves correctly
            local resolved_target=$(cd "$(dirname "$target")" && cd "$(dirname "$current_target")" 2>/dev/null && pwd)/$(basename "$current_target")

            if [[ "$resolved_target" != "$source_abs" ]] && [[ "$current_target" != "$source_abs" ]]; then
                log_error "Wrong target: $target -> $current_target (should be $source_abs)"
                add_result "error" "$target" "Points to wrong location: $current_target" true
                ((errors++))
                continue
            fi
        fi

        log_success "OK: $target"
        add_result "ok" "$target" "Correctly linked to $source_rel" false
    done

    return $errors
}

# ============================================================================
# Fix Functions
# ============================================================================

fix_symlinks() {
    print_section "Fixing Symlinks"

    local fixed=0
    local failed=0

    for entry in "${EXPECTED_SYMLINKS[@]}"; do
        local target="${entry%%:*}"
        local source_rel="${entry##*:}"
        local source_abs="$DOTFILES_DIR/$source_rel"

        # Skip if source doesn't exist
        if [[ ! -e "$source_abs" ]]; then
            continue
        fi

        # Check if fix is needed
        local needs_fix=false

        if [[ ! -e "$target" ]] && [[ ! -L "$target" ]]; then
            needs_fix=true
        elif [[ ! -L "$target" ]]; then
            needs_fix=true
        elif [[ "$(readlink "$target")" != "$source_abs" ]]; then
            # Check for path mismatch
            local current=$(readlink "$target")
            if [[ "$current" != "$source_abs" ]]; then
                needs_fix=true
            fi
        fi

        if $needs_fix; then
            # Backup existing file if it's not a symlink
            if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
                backup_file "$target"
            fi

            # Ensure parent directory exists
            ensure_parent_dir "$target"

            # Remove existing symlink/file and create new one
            rm -f "$target"
            if ln -sfv "$source_abs" "$target"; then
                log_fix "Fixed: $target -> $source_abs"
                ((fixed++))
            else
                log_error "Failed to create symlink: $target"
                ((failed++))
            fi
        fi
    done

    if [[ $fixed -gt 0 ]]; then
        log_success "Fixed $fixed symlink(s)"
    fi

    if [[ $failed -gt 0 ]]; then
        log_error "Failed to fix $failed symlink(s)"
        return 1
    fi

    return 0
}
