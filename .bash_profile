# .bash_profile - executed for login shells
# For zsh users: this file is rarely used since zsh uses .zshrc/.zprofile

# Source .bashrc if it exists (standard practice)
[[ -f ~/.bashrc ]] && source ~/.bashrc

# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"
