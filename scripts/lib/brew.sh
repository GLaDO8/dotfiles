#!/usr/bin/env bash
#
# Homebrew/Brewfile validation
#

# ============================================================================
# Validation Functions
# ============================================================================

validate_brew() {
    print_section "Homebrew Validation"

    local errors=0
    local warnings=0

    # Check if Homebrew is installed
    if ! command_exists brew; then
        log_error "Homebrew is not installed"
        add_result "error" "homebrew" "Homebrew is not installed" false
        return 1
    fi

    log_success "Homebrew is installed"
    add_result "ok" "homebrew" "Homebrew is installed" false

    # Check if Brewfile exists
    if [[ ! -f "$DOTFILES_DIR/Brewfile" ]]; then
        log_error "Brewfile not found at $DOTFILES_DIR/Brewfile"
        add_result "error" "Brewfile" "Brewfile not found" false
        return 1
    fi

    log_info "Checking installed packages against Brewfile..."

    # Parse Brewfile for expected packages
    local -a expected_formulas=()
    local -a expected_casks=()

    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Extract formula names
        if [[ "$line" =~ ^brew[[:space:]]+\"([^\"]+)\" ]]; then
            expected_formulas+=("${BASH_REMATCH[1]}")
        # Extract cask names
        elif [[ "$line" =~ ^cask[[:space:]]+\"([^\"]+)\" ]]; then
            expected_casks+=("${BASH_REMATCH[1]}")
        fi
    done < "$DOTFILES_DIR/Brewfile"

    # Get installed formulas
    local -a installed_formulas=()
    while IFS= read -r formula; do
        installed_formulas+=("$formula")
    done < <(brew list --formula 2>/dev/null)

    # Get installed casks
    local -a installed_casks=()
    while IFS= read -r cask; do
        installed_casks+=("$cask")
    done < <(brew list --cask 2>/dev/null)

    # Check critical formulas
    local critical_formulas=("git" "gh" "node" "fzf" "zoxide" "eza" "tmux" "aichat" "vim" "zsh")

    for formula in "${critical_formulas[@]}"; do
        if printf '%s\n' "${installed_formulas[@]}" | grep -qx "$formula"; then
            log_success "Formula installed: $formula"
            add_result "ok" "brew:$formula" "Critical formula is installed" false
        else
            log_error "Formula missing: $formula"
            add_result "error" "brew:$formula" "Critical formula is not installed" false
            ((errors++))
        fi
    done

    # Count missing from Brewfile
    local missing_count=0
    for formula in "${expected_formulas[@]}"; do
        if ! printf '%s\n' "${installed_formulas[@]}" | grep -qx "$formula"; then
            ((missing_count++))
        fi
    done

    if [[ $missing_count -gt 0 ]]; then
        log_warn "$missing_count formula(s) in Brewfile not installed"
        add_result "warn" "brew:formulas" "$missing_count formulas from Brewfile not installed" false
        ((warnings++))
    fi

    # Check for drift (installed but not in Brewfile)
    local drift_count=0
    for formula in "${installed_formulas[@]}"; do
        if ! printf '%s\n' "${expected_formulas[@]}" | grep -qx "$formula"; then
            ((drift_count++))
        fi
    done

    if [[ $drift_count -gt 0 ]]; then
        log_info "$drift_count formula(s) installed but not in Brewfile (consider adding or removing)"
        add_result "warn" "brew:drift" "$drift_count formulas installed but not in Brewfile" false
    fi

    return $errors
}

# ============================================================================
# Fix Functions (Report only - user decision required)
# ============================================================================

fix_brew() {
    print_section "Homebrew Sync"

    log_info "To install missing packages, run:"
    log_info "  brew bundle install --file=$DOTFILES_DIR/Brewfile"
    log_info ""
    log_info "To add installed packages to Brewfile, run:"
    log_info "  brew bundle dump --file=$DOTFILES_DIR/Brewfile --force"

    return 0
}
