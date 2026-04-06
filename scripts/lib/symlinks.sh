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
    "$HOME/.ignore:.ignore"
    "$HOME/.mackup.cfg:.mackup.cfg"

    # SSH
    "$HOME/.ssh/config:ssh/config"

    # Zed editor
    "$HOME/.config/zed/settings.json:config/zed/settings.json"
    "$HOME/.config/zed/keymap.json:config/zed/keymap.json"
    "$HOME/.config/zed/tasks.json:config/zed/tasks.json"

    # Ghostty terminal
    "$HOME/.config/ghostty/config:config/ghostty/config"

    # btop
    "$HOME/.config/btop/btop.conf:config/btop/btop.conf"

    # Git global ignore
    "$HOME/.config/git/ignore:config/git/ignore"

    # Atuin
    "$HOME/.config/atuin/config.toml:config/atuin/config.toml"

    # aichat
    "$HOME/.config/aichat/config.yaml:config/aichat/config.yaml"

    # GitHub CLI
    "$HOME/.config/gh/config.yml:config/gh/config.yml"

    # Zellij
    "$HOME/.config/zellij/config.kdl:config/zellij/config.kdl"
    "$HOME/.config/zellij/layouts/claude.kdl:config/zellij/layouts/claude.kdl"

    # Helix
    "$HOME/.config/helix/config.toml:config/helix/config.toml"

    # Neovim
    "$HOME/.config/nvim/init.lua:config/nvim/init.lua"
    "$HOME/.config/nvim/lazy-lock.json:config/nvim/lazy-lock.json"

    # Nicotine+
    "$HOME/.config/nicotine/config:config/nicotine/config"

    # uv
    "$HOME/.config/uv/uv-receipt.json:config/uv/uv-receipt.json"

    # Yazi
    "$HOME/.config/yazi/yazi.toml:config/yazi/yazi.toml"
    "$HOME/.config/yazi/keymap.toml:config/yazi/keymap.toml"

    # VS Code
    "$HOME/Library/Application Support/Code/User/settings.json:vscode/settings.json"

    # Cursor
    "$HOME/Library/Application Support/Cursor/User/settings.json:cursor/settings.json"
    "$HOME/Library/Application Support/Cursor/User/keybindings.json:cursor/keybindings.json"
)

EXPECTED_SYMLINK_DIRS=(
    "$HOME/.config/ghostty/shaders:config/ghostty/shaders"
    "$HOME/.config/ghostty/themes:config/ghostty/themes"
    "$HOME/.config/helix/themes:config/helix/themes"
    "$HOME/.config/zellij/layouts:config/zellij/layouts"
)

build_expected_symlink_entries() {
    local entries=("${EXPECTED_SYMLINKS[@]}")
    local entry target_dir source_dir source_file relative_path

    for entry in "${EXPECTED_SYMLINK_DIRS[@]}"; do
        target_dir="${entry%%:*}"
        source_dir="${entry##*:}"
        source_dir="$DOTFILES_DIR/$source_dir"

        [[ -d "$source_dir" ]] || continue

        while IFS= read -r source_file; do
            relative_path="${source_file#"$source_dir"/}"
            entries+=("$target_dir/$relative_path:${source_file#"$DOTFILES_DIR"/}")
        done < <(find "$source_dir" -type f | sort)
    done

    printf '%s\n' "${entries[@]}"
}

# ============================================================================
# Validation Functions
# ============================================================================

validate_symlinks() {
    print_section "Symlink Validation"

    local errors=0
    local warnings=0

    while IFS= read -r entry; do
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
        local current_target
        current_target=$(readlink "$target")

        # Handle both absolute and relative paths
        if [[ "$current_target" != "$source_abs" ]]; then
            # Also check if it's a relative path that resolves correctly
            local resolved_base
            local resolved_target
            resolved_base=$(cd "$(dirname "$target")" && cd "$(dirname "$current_target")" 2>/dev/null && pwd)
            resolved_target="${resolved_base}/$(basename "$current_target")"

            if [[ "$resolved_target" != "$source_abs" ]] && [[ "$current_target" != "$source_abs" ]]; then
                log_error "Wrong target: $target -> $current_target (should be $source_abs)"
                add_result "error" "$target" "Points to wrong location: $current_target" true
                ((errors++))
                continue
            fi
        fi

        log_success "OK: $target"
        add_result "ok" "$target" "Correctly linked to $source_rel" false
    done < <(build_expected_symlink_entries)

    return $errors
}

# ============================================================================
# Fix Functions
# ============================================================================

fix_symlinks() {
    print_section "Fixing Symlinks"

    local fixed=0
    local failed=0

    while IFS= read -r entry; do
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
            local current
            current=$(readlink "$target")
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
    done < <(build_expected_symlink_entries)

    if [[ $fixed -gt 0 ]]; then
        log_success "Fixed $fixed symlink(s)"
    fi

    if [[ $failed -gt 0 ]]; then
        log_error "Failed to fix $failed symlink(s)"
        return 1
    fi

    return 0
}
