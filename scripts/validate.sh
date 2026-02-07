#!/usr/bin/env bash
#
# Dotfiles Validation Script
#
# Validates symlinks, Homebrew packages, shell configuration, and git/ssh/gpg setup.
#
# Usage:
#   ./validate.sh              # Run all validations
#   ./validate.sh --json       # Output results as JSON
#   ./validate.sh --fix        # Auto-fix issues where possible
#   ./validate.sh symlinks     # Run only symlink validation
#   ./validate.sh brew         # Run only Homebrew validation
#   ./validate.sh shell        # Run only shell config validation
#   ./validate.sh git          # Run only git/ssh/gpg validation
#
# Exit codes:
#   0 - All validations passed
#   1 - One or more validations failed
#   2 - Script error (missing dependencies, etc.)
#

set -o pipefail

# Auto-detect dotfiles directory (where this script lives)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR="${DOTFILES_DIR:-$(dirname "$SCRIPT_DIR")}"

# Source library files
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/symlinks.sh"
source "$SCRIPT_DIR/lib/brew.sh"
source "$SCRIPT_DIR/lib/shell.sh"
source "$SCRIPT_DIR/lib/git-ssh.sh"

# ============================================================================
# Parse Arguments
# ============================================================================

FIX_MODE=false
JSON_MODE=false
SPECIFIC_CHECK=""

for arg in "$@"; do
    case $arg in
        --json)
            JSON_MODE=true
            export OUTPUT_MODE="json"
            ;;
        --fix)
            FIX_MODE=true
            ;;
        symlinks|symlink)
            SPECIFIC_CHECK="symlinks"
            ;;
        brew|homebrew)
            SPECIFIC_CHECK="brew"
            ;;
        shell|zsh)
            SPECIFIC_CHECK="shell"
            ;;
        git|ssh|gpg)
            SPECIFIC_CHECK="git"
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS] [CHECK]"
            echo ""
            echo "Options:"
            echo "  --json    Output results as JSON"
            echo "  --fix     Auto-fix issues where possible"
            echo "  --help    Show this help message"
            echo ""
            echo "Checks:"
            echo "  symlinks  Validate dotfile symlinks"
            echo "  brew      Validate Homebrew packages"
            echo "  shell     Validate shell configuration"
            echo "  git       Validate git/ssh/gpg setup"
            echo ""
            echo "If no check is specified, all checks are run."
            exit 0
            ;;
    esac
done

# ============================================================================
# Main Execution
# ============================================================================

main() {
    local total_errors=0

    if [[ "$OUTPUT_MODE" != "json" ]]; then
        echo ""
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║                  DOTFILES VALIDATION                           ║"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo ""
        log_info "Dotfiles directory: $DOTFILES_DIR"

        if $FIX_MODE; then
            echo ""
            echo -e "${YELLOW}>>> FIX MODE: Will attempt to repair issues <<<${NC}"
        fi
    fi

    # Run validations based on specific check or all
    case "$SPECIFIC_CHECK" in
        symlinks)
            validate_symlinks || ((total_errors++))
            $FIX_MODE && fix_symlinks
            ;;
        brew)
            validate_brew || ((total_errors++))
            $FIX_MODE && fix_brew
            ;;
        shell)
            validate_shell || ((total_errors++))
            $FIX_MODE && fix_shell
            ;;
        git)
            validate_git_ssh || ((total_errors++))
            $FIX_MODE && fix_git_ssh
            ;;
        "")
            # Run all validations
            validate_symlinks || ((total_errors++))
            $FIX_MODE && fix_symlinks

            validate_brew || ((total_errors++))
            $FIX_MODE && fix_brew

            validate_shell || ((total_errors++))
            $FIX_MODE && fix_shell

            validate_git_ssh || ((total_errors++))
            $FIX_MODE && fix_git_ssh
            ;;
    esac

    # Output JSON if requested
    if [[ "$OUTPUT_MODE" == "json" ]]; then
        output_json
    else
        # Print summary
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "                    SUMMARY"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        # Count results
        local ok_count=0
        local warn_count=0
        local error_count=0

        for result in "${VALIDATION_RESULTS[@]}"; do
            if [[ "$result" == *'"status":"ok"'* ]]; then
                ((ok_count++))
            elif [[ "$result" == *'"status":"warn"'* ]]; then
                ((warn_count++))
            elif [[ "$result" == *'"status":"error"'* ]]; then
                ((error_count++))
            fi
        done

        echo -e "${GREEN}Passed:${NC} $ok_count"
        echo -e "${YELLOW}Warnings:${NC} $warn_count"
        echo -e "${RED}Errors:${NC} $error_count"

        if [[ $error_count -eq 0 ]]; then
            echo ""
            echo -e "${GREEN}All validations passed!${NC}"
        else
            echo ""
            echo -e "${RED}Validation failed with $error_count error(s)${NC}"

            if ! $FIX_MODE; then
                echo ""
                echo "Run with --fix to attempt auto-repair of fixable issues."
            fi
        fi
    fi

    # Return appropriate exit code
    if [[ $total_errors -gt 0 ]]; then
        return 1
    fi

    return 0
}

main "$@"
