#!/usr/bin/env bash
#
# Shell configuration validation (antidote-based)
#

# ============================================================================
# Validation Functions
# ============================================================================

validate_shell() {
    print_section "Shell Configuration Validation"

    local errors=0
    local warnings=0
    local atuin_data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/atuin"
    local atuin_session="$atuin_data_dir/session"
    local atuin_key="$atuin_data_dir/key"
    local atuin_cache="$HOME/.cache/zsh-inits/atuin.zsh"

    # Check if antidote is installed (via Homebrew)
    # Note: antidote is a zsh function, not a binary, so we check brew list
    if brew list antidote &>/dev/null; then
        log_success "antidote is installed (via Homebrew)"
        add_result "ok" "antidote" "antidote plugin manager is installed" false
    elif [[ -f "/opt/homebrew/share/antidote/antidote.zsh" ]] || [[ -f "/usr/local/share/antidote/antidote.zsh" ]]; then
        log_success "antidote is installed"
        add_result "ok" "antidote" "antidote plugin manager is installed" false
    else
        log_error "antidote is not installed"
        add_result "error" "antidote" "antidote plugin manager is not installed (brew install antidote)" false
        ((errors++))
    fi

    # Check if .zsh_plugins.txt exists
    if [[ -f "$HOME/.zsh_plugins.txt" ]] || [[ -L "$HOME/.zsh_plugins.txt" ]]; then
        log_success ".zsh_plugins.txt exists"
        add_result "ok" ".zsh_plugins.txt" "Antidote plugins list exists" false

        # Count plugins
        local plugin_count
        plugin_count=$(grep -cve '^#' -e '^$' "$HOME/.zsh_plugins.txt" | tr -d ' ')
        log_info "Found $plugin_count plugins defined"
    else
        log_error ".zsh_plugins.txt missing"
        add_result "error" ".zsh_plugins.txt" "Antidote plugins list not found" true
        ((errors++))
    fi

    # Compiled antidote bundle is optional. This setup loads directly from
    # antidote at shell startup and treats the compiled file as an optimization.
    if [[ -f "$HOME/.zsh_plugins.zsh" ]]; then
        log_success ".zsh_plugins.zsh (compiled) exists"
        add_result "ok" ".zsh_plugins.zsh" "Compiled plugins file exists" false
    else
        log_info ".zsh_plugins.zsh not found; direct antidote loading is enabled"
        add_result "ok" ".zsh_plugins.zsh" "Compiled plugins file is optional for this setup" false
    fi

    # Check key plugins are in the list
    local expected_plugins=("zsh-autosuggestions" "fast-syntax-highlighting" "zsh-completions")

    if [[ -f "$HOME/.zsh_plugins.txt" ]]; then
        for plugin in "${expected_plugins[@]}"; do
            if grep -q "$plugin" "$HOME/.zsh_plugins.txt" 2>/dev/null; then
                log_success "Plugin configured: $plugin"
                add_result "ok" "plugin:$plugin" "Plugin is in .zsh_plugins.txt" false
            else
                log_warn "Plugin missing from config: $plugin"
                add_result "warn" "plugin:$plugin" "Recommended plugin not in .zsh_plugins.txt" false
                ((warnings++))
            fi
        done
    fi

    # Syntax check .zshrc
    if [[ -f "$DOTFILES_DIR/zsh/.zshrc" ]]; then
        if zsh -n "$DOTFILES_DIR/zsh/.zshrc" 2>/dev/null; then
            log_success "zsh/.zshrc syntax is valid"
            add_result "ok" "zsh/.zshrc" "Syntax is valid" false
        else
            log_error "zsh/.zshrc has syntax errors"
            add_result "error" "zsh/.zshrc" "Syntax errors detected" false
            ((errors++))
        fi
    fi

    # Check zsh is the default shell
    if [[ "$SHELL" == *"zsh"* ]]; then
        log_success "Default shell is zsh"
        add_result "ok" "default-shell" "zsh is the default shell" false
    else
        log_warn "Default shell is not zsh: $SHELL"
        add_result "warn" "default-shell" "Default shell is $SHELL, not zsh" false
        ((warnings++))
    fi

    if [[ -f "$HOME/.config/atuin/config.toml" ]] || [[ -L "$HOME/.config/atuin/config.toml" ]]; then
        if command_exists atuin; then
            log_success "Atuin CLI is installed"
            add_result "ok" "atuin" "Atuin CLI is installed" false
        else
            log_error "Atuin config exists but atuin is not installed"
            add_result "error" "atuin" "Atuin config exists but the CLI is missing" false
            ((errors++))
        fi

        if [[ -s "$atuin_cache" ]]; then
            log_success "Cached Atuin shell init exists"
            add_result "ok" "atuin-cache" "Cached Atuin shell init exists" false
        else
            log_warn "Cached Atuin shell init is missing or empty"
            add_result "warn" "atuin-cache" "Run zsh-refresh-cache to regenerate Atuin shell init" false
            ((warnings++))
        fi

        if [[ -s "$atuin_session" ]] && [[ -s "$atuin_key" ]]; then
            log_success "Atuin account sync state is present"
            add_result "ok" "atuin-sync" "Atuin session and encryption key exist" false
        else
            log_warn "Atuin is not signed in for sync on this machine"
            add_result "warn" "atuin-sync" "Run atuin register or atuin login, then atuin sync" false
            ((warnings++))
        fi
    fi

    return $errors
}

# ============================================================================
# Fix Functions
# ============================================================================

fix_shell() {
    print_section "Fixing Shell Configuration"

    local fixed=0
    local failed=0

    # Install antidote if missing
    if ! brew list antidote &>/dev/null; then
        if command_exists brew; then
            log_fix "Installing antidote via Homebrew..."
            if brew install antidote; then
                log_success "Installed antidote"
                ((fixed++))
            else
                log_error "Failed to install antidote"
                ((failed++))
            fi
        else
            log_error "Homebrew not available to install antidote"
            ((failed++))
        fi
    fi

    # Regenerate .zsh_plugins.zsh if missing and .zsh_plugins.txt exists
    if [[ ! -f "$HOME/.zsh_plugins.zsh" ]] && [[ -f "$HOME/.zsh_plugins.txt" ]]; then
        if command_exists antidote; then
            log_fix "Regenerating .zsh_plugins.zsh..."
            if antidote bundle < "$HOME/.zsh_plugins.txt" > "$HOME/.zsh_plugins.zsh"; then
                log_success "Regenerated .zsh_plugins.zsh"
                ((fixed++))
            else
                log_error "Failed to regenerate .zsh_plugins.zsh"
                ((failed++))
            fi
        fi
    fi

    if [[ $fixed -gt 0 ]]; then
        log_success "Fixed $fixed shell configuration issue(s)"
    fi

    if [[ $failed -gt 0 ]]; then
        log_error "Failed to fix $failed issue(s)"
        return 1
    fi

    return 0
}
