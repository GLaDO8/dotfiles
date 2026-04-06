#!/usr/bin/env bash
#
# Minimal first-run bootstrap for a brand-new Mac before cloning dotfiles.
#
# Remote usage:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/GLaDO8/dotfiles/main/bootstrap.sh)"
#
set -euo pipefail

log() {
    printf '[bootstrap] %s\n' "$1"
}

install_brew_if_needed() {
    if command -v brew >/dev/null 2>&1; then
        log "Homebrew already installed"
        return 0
    fi

    log "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
}

install_cask_if_missing() {
    local cask=$1

    if brew list --cask "$cask" >/dev/null 2>&1; then
        log "Already installed: $cask"
        return 0
    fi

    log "Installing: $cask"
    brew install --cask "$cask"
}

main() {
    install_brew_if_needed

    brew update

    install_cask_if_missing "1password"
    install_cask_if_missing "1password-cli"
    install_cask_if_missing "google-chrome"
    install_cask_if_missing "thebrowsercompany-dia"

    log "Next steps:"
    log "1. Sign into 1Password and GitHub."
    log "2. Clone dotfiles: git clone git@github.com:GLaDO8/dotfiles.git ~/dotfiles"
    log "3. Run the full restore: cd ~/dotfiles && ./install.sh"
}

main "$@"
