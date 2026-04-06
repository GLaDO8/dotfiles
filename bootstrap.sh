#!/usr/bin/env bash
#
# Minimal first-run bootstrap for a brand-new Mac before cloning dotfiles.
#
# Remote usage:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/GLaDO8/dotfiles/main/bootstrap.sh)"
#
set -euo pipefail

DOTFILES_REPO_URL="${DOTFILES_REPO_URL:-https://github.com/GLaDO8/dotfiles.git}"
DOTFILES_DEST="${DOTFILES_DEST:-$HOME/dotfiles}"
RUN_DOTFILES_INSTALL="${RUN_DOTFILES_INSTALL:-false}"

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

persist_brew_shellenv() {
    local brew_bin=""
    local shellenv_line=""

    if [[ -x /opt/homebrew/bin/brew ]]; then
        brew_bin="/opt/homebrew/bin/brew"
    elif [[ -x /usr/local/bin/brew ]]; then
        brew_bin="/usr/local/bin/brew"
    else
        return 0
    fi

    shellenv_line="eval \"\$(${brew_bin} shellenv)\""
    touch "$HOME/.zprofile"
    if ! grep -Fqx "$shellenv_line" "$HOME/.zprofile"; then
        printf '\n%s\n' "$shellenv_line" >> "$HOME/.zprofile"
        log "Persisted Homebrew shellenv in ~/.zprofile"
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

install_formula_if_missing() {
    local formula=$1

    if brew list --formula "$formula" >/dev/null 2>&1; then
        log "Already installed: $formula"
        return 0
    fi

    log "Installing: $formula"
    brew install "$formula"
}

clone_dotfiles_if_needed() {
    if [[ -d "$DOTFILES_DEST/.git" ]]; then
        log "Dotfiles repo already present at $DOTFILES_DEST"
        return 0
    fi

    log "Cloning dotfiles to $DOTFILES_DEST"
    git clone "$DOTFILES_REPO_URL" "$DOTFILES_DEST"
}

main() {
    install_brew_if_needed
    persist_brew_shellenv

    brew update

    install_formula_if_missing "git"
    install_formula_if_missing "gh"
    install_cask_if_missing "1password"
    install_cask_if_missing "1password-cli"
    install_cask_if_missing "google-chrome"
    install_cask_if_missing "thebrowsercompany-dia"

    clone_dotfiles_if_needed

    if [[ "$RUN_DOTFILES_INSTALL" == "true" ]]; then
        log "Running full restore"
        cd "$DOTFILES_DEST"
        ./install.sh
        return 0
    fi

    log "Next steps:"
    log "1. Sign into 1Password and GitHub."
    log "2. Dotfiles repo: $DOTFILES_DEST"
    log "3. Run the full restore: cd $DOTFILES_DEST && ./install.sh"
    log "Tip: set RUN_DOTFILES_INSTALL=true to have bootstrap run the full installer automatically."
}

main "$@"
