#!/usr/bin/env bash
#
# Git, SSH, and GPG configuration validation
#

# Expected values (from .gitconfig)
EXPECTED_USER_NAME="GLaDO8"
EXPECTED_USER_EMAIL="gshreyas@icloud.com"
EXPECTED_SSH_SIGN_PROGRAM="/Applications/1Password.app/Contents/MacOS/op-ssh-sign"

# ============================================================================
# Validation Functions
# ============================================================================

validate_git_ssh() {
    print_section "Git/SSH/GPG Validation"

    local errors=0
    local warnings=0

    # Check git is installed
    if ! command_exists git; then
        log_error "Git is not installed"
        add_result "error" "git" "Git is not installed" false
        return 1
    fi

    log_success "Git is installed: $(git --version | head -1)"
    add_result "ok" "git" "Git is installed" false

    # Check git user.name
    local current_name=$(git config --global user.name 2>/dev/null)
    if [[ "$current_name" == "$EXPECTED_USER_NAME" ]]; then
        log_success "Git user.name: $current_name"
        add_result "ok" "git:user.name" "Correctly set to $current_name" false
    elif [[ -n "$current_name" ]]; then
        log_warn "Git user.name: $current_name (expected: $EXPECTED_USER_NAME)"
        add_result "warn" "git:user.name" "Set to $current_name, expected $EXPECTED_USER_NAME" false
        ((warnings++))
    else
        log_error "Git user.name is not set"
        add_result "error" "git:user.name" "Not configured" false
        ((errors++))
    fi

    # Check git user.email
    local current_email=$(git config --global user.email 2>/dev/null)
    if [[ "$current_email" == "$EXPECTED_USER_EMAIL" ]]; then
        log_success "Git user.email: $current_email"
        add_result "ok" "git:user.email" "Correctly set to $current_email" false
    elif [[ -n "$current_email" ]]; then
        log_warn "Git user.email: $current_email (expected: $EXPECTED_USER_EMAIL)"
        add_result "warn" "git:user.email" "Set to $current_email, expected $EXPECTED_USER_EMAIL" false
        ((warnings++))
    else
        log_error "Git user.email is not set"
        add_result "error" "git:user.email" "Not configured" false
        ((errors++))
    fi

    # Check GPG signing is enabled
    local gpg_sign=$(git config --global commit.gpgsign 2>/dev/null)
    if [[ "$gpg_sign" == "true" ]]; then
        log_success "GPG signing is enabled"
        add_result "ok" "git:gpgsign" "Commit signing is enabled" false
    else
        log_warn "GPG signing is not enabled"
        add_result "warn" "git:gpgsign" "Commit signing is not enabled" false
        ((warnings++))
    fi

    # Check GPG format is SSH
    local gpg_format=$(git config --global gpg.format 2>/dev/null)
    if [[ "$gpg_format" == "ssh" ]]; then
        log_success "GPG format: ssh (using SSH keys for signing)"
        add_result "ok" "git:gpg.format" "Using SSH format for signing" false
    else
        log_info "GPG format: ${gpg_format:-not set}"
        add_result "warn" "git:gpg.format" "GPG format is ${gpg_format:-not set}, expected ssh" false
    fi

    # Check 1Password SSH signing program
    if [[ -x "$EXPECTED_SSH_SIGN_PROGRAM" ]]; then
        log_success "1Password SSH signing program exists and is executable"
        add_result "ok" "1password:ssh-sign" "op-ssh-sign is available" false
    elif [[ -f "$EXPECTED_SSH_SIGN_PROGRAM" ]]; then
        log_warn "1Password SSH signing program exists but may not be executable"
        add_result "warn" "1password:ssh-sign" "op-ssh-sign exists but not executable" false
        ((warnings++))
    else
        log_warn "1Password SSH signing program not found (1Password may not be installed)"
        add_result "warn" "1password:ssh-sign" "op-ssh-sign not found at expected path" false
        ((warnings++))
    fi

    # Check SSH config exists
    if [[ -f "$HOME/.ssh/config" ]]; then
        log_success "SSH config exists"
        add_result "ok" "ssh:config" "SSH config file exists" false
    elif [[ -L "$HOME/.ssh/config" ]]; then
        if [[ -e "$HOME/.ssh/config" ]]; then
            log_success "SSH config exists (symlink)"
            add_result "ok" "ssh:config" "SSH config symlink is valid" false
        else
            log_error "SSH config symlink is broken"
            add_result "error" "ssh:config" "SSH config symlink points to missing file" true
            ((errors++))
        fi
    else
        log_warn "SSH config not found"
        add_result "warn" "ssh:config" "SSH config file not found" true
        ((warnings++))
    fi

    # Test GitHub SSH connection (non-blocking, quick timeout)
    log_info "Testing GitHub SSH connection..."
    local ssh_test_output
    ssh_test_output=$(ssh -T git@github.com -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new 2>&1) || true

    if [[ "$ssh_test_output" == *"successfully authenticated"* ]] || [[ "$ssh_test_output" == *"You've successfully authenticated"* ]]; then
        log_success "GitHub SSH authentication works"
        add_result "ok" "github:ssh" "SSH authentication to GitHub successful" false
    elif [[ "$ssh_test_output" == *"Hi "* ]]; then
        log_success "GitHub SSH authentication works"
        add_result "ok" "github:ssh" "SSH authentication to GitHub successful" false
    elif [[ "$ssh_test_output" == *"Permission denied"* ]]; then
        log_error "GitHub SSH authentication failed (permission denied)"
        add_result "error" "github:ssh" "SSH authentication to GitHub failed" false
        ((errors++))
    else
        log_warn "Could not verify GitHub SSH (may require 1Password auth or network)"
        add_result "warn" "github:ssh" "Could not verify GitHub SSH connection" false
        ((warnings++))
    fi

    return $errors
}

# ============================================================================
# Fix Functions (Alert only - security sensitive)
# ============================================================================

fix_git_ssh() {
    print_section "Git/SSH/GPG Issues"

    log_info "Git/SSH/GPG configuration issues require manual attention:"
    log_info ""
    log_info "To configure git user:"
    log_info "  git config --global user.name \"$EXPECTED_USER_NAME\""
    log_info "  git config --global user.email \"$EXPECTED_USER_EMAIL\""
    log_info ""
    log_info "To enable GPG signing:"
    log_info "  git config --global commit.gpgsign true"
    log_info "  git config --global gpg.format ssh"
    log_info ""
    log_info "For SSH issues, ensure:"
    log_info "  1. 1Password is installed with SSH agent enabled"
    log_info "  2. SSH config is properly linked: ln -sfv $DOTFILES_DIR/ssh/config ~/.ssh/config"
    log_info "  3. SSH key is added to your GitHub account"

    return 0
}
