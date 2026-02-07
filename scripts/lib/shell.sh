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
        local plugin_count=$(grep -v "^#" "$HOME/.zsh_plugins.txt" | grep -v "^$" | wc -l | tr -d ' ')
        log_info "Found $plugin_count plugins defined"
    else
        log_error ".zsh_plugins.txt missing"
        add_result "error" ".zsh_plugins.txt" "Antidote plugins list not found" true
        ((errors++))
    fi

    # Check if .zsh_plugins.zsh (compiled) exists
    if [[ -f "$HOME/.zsh_plugins.zsh" ]]; then
        log_success ".zsh_plugins.zsh (compiled) exists"
        add_result "ok" ".zsh_plugins.zsh" "Compiled plugins file exists" false
    else
        log_warn ".zsh_plugins.zsh not found (run: antidote bundle < ~/.zsh_plugins.txt > ~/.zsh_plugins.zsh)"
        add_result "warn" ".zsh_plugins.zsh" "Compiled plugins file not found" true
        ((warnings++))
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

    # Syntax check .aliases
    if [[ -f "$DOTFILES_DIR/.aliases" ]]; then
        if bash -n "$DOTFILES_DIR/.aliases" 2>/dev/null; then
            log_success ".aliases syntax is valid"
            add_result "ok" ".aliases" "Syntax is valid" false
        else
            log_error ".aliases has syntax errors"
            add_result "error" ".aliases" "Syntax errors detected" false
            ((errors++))
        fi
    fi

    # Syntax check .functions
    if [[ -f "$DOTFILES_DIR/.functions" ]]; then
        if bash -n "$DOTFILES_DIR/.functions" 2>/dev/null; then
            log_success ".functions syntax is valid"
            add_result "ok" ".functions" "Syntax is valid" false
        else
            log_error ".functions has syntax errors"
            add_result "error" ".functions" "Syntax errors detected" false
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
