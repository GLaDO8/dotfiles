#!/usr/bin/env bash
#
# Dotfiles installation script
#
# Usage:
#   ./install.sh              # Run full installation
#   ./install.sh --dry-run    # Preview what would be done
#   ./install.sh -n           # Same as --dry-run
#
# Environment:
#   DOTFILES_DIR              # Override dotfiles location (default: auto-detect)
#
set -o pipefail

# Ask for sudo password upfront and keep it alive for the duration of the script
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Auto-detect dotfiles directory (where this script lives)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$SCRIPT_DIR}"

# Track errors for summary
ERRORS=()
DRY_RUN=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
    esac
done

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ERRORS+=("$1")
}

# Execute command with dry-run support
run() {
    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN]${NC} $*"
        return 0
    else
        "$@"
    fi
}

# Run a setup function with error handling
run_setup() {
    local func_name=$1
    local description=$2

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Starting: $description"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if $func_name; then
        log_success "Completed: $description"
        return 0
    else
        log_error "Failed: $description"
        return 1
    fi
}

# ============================================================================
# Setup Functions
# ============================================================================

brew_setup() {
    # Check for Homebrew and install if we don't have it
    if ! command -v brew &> /dev/null; then
        log_info "Installing Homebrew..."
        run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Add brew to PATH for this session (needed on Apple Silicon)
        if [[ -x "/opt/homebrew/bin/brew" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    else
        log_info "Homebrew already installed"
    fi

    # Make sure we're using the latest Homebrew
    log_info "Updating Homebrew..."
    run brew update || log_warn "brew update failed, continuing..."

    # Upgrade any already-installed formulae
    log_info "Upgrading installed packages..."
    run brew upgrade || log_warn "brew upgrade failed, continuing..."

    # Install all our dependencies with bundle (See Brewfile)
    log_info "Installing brew packages and cask apps..."
    if [[ -f "$DOTFILES_DIR/Brewfile" ]]; then
        run brew bundle install --verbose --file="$DOTFILES_DIR/Brewfile" || log_warn "Some packages failed to install"
    else
        log_error "Brewfile not found at $DOTFILES_DIR/Brewfile"
        return 1
    fi

    # Create sha256sum symlink if coreutils is installed
    BREW_PREFIX=$(brew --prefix)
    if [[ -f "${BREW_PREFIX}/bin/gsha256sum" ]]; then
        run ln -sf "${BREW_PREFIX}/bin/gsha256sum" "${BREW_PREFIX}/bin/sha256sum" 2>/dev/null
    fi

    return 0
}

zsh_setup() {
    # Install oh-my-zsh
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        log_info "Installing oh-my-zsh..."
        run sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    else
        log_info "oh-my-zsh already installed"
    fi

    # Make ZSH the default shell environment
    if [[ "$SHELL" != *"zsh"* ]]; then
        log_info "Setting zsh as default shell..."
        run chsh -s "$(which zsh)"
    fi

    # Install powerline fonts
    if [[ ! -d "$HOME/.local/share/fonts" ]] || ! ls "$HOME/.local/share/fonts"/*Powerline* &>/dev/null; then
        log_info "Installing powerline fonts..."
        (
            run git clone https://github.com/powerline/fonts.git --depth=1 /tmp/powerline-fonts
            cd /tmp/powerline-fonts && run ./install.sh
            rm -rf /tmp/powerline-fonts
        )
    fi

    # Install spaceship prompt
    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    if [[ ! -d "$ZSH_CUSTOM/themes/spaceship-prompt" ]]; then
        log_info "Installing spaceship prompt..."
        run git clone https://github.com/spaceship-prompt/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt" --depth=1
        run ln -sf "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
    fi

    # Install zsh plugins
    if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
        log_info "Installing zsh-syntax-highlighting..."
        run git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    fi

    if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
        log_info "Installing zsh-autosuggestions..."
        run git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    fi

    if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-completions" ]]; then
        log_info "Installing zsh-completions..."
        run git clone https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"
    fi

    return 0
}

dotfile_setup() {
    log_info "Setting up shell dotfiles..."

    # Create symlinks for shell dotfiles in home directory
    run rm -rf "$HOME/.zshrc"
    run ln -sfv "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
    run ln -sfv "$DOTFILES_DIR/.bash_profile" "$HOME/.bash_profile"

    return 0
}

config_setup() {
    log_info "Setting up app configurations..."

    # Critical dotfiles (symlinks)
    run ln -sfv "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
    run ln -sfv "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"
    run ln -sfv "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc"
    run ln -sfv "$DOTFILES_DIR/.npmrc" "$HOME/.npmrc"

    # SSH config
    run mkdir -p "$HOME/.ssh"
    run chmod 700 "$HOME/.ssh"
    if [[ -f "$DOTFILES_DIR/ssh/config" ]]; then
        run ln -sfv "$DOTFILES_DIR/ssh/config" "$HOME/.ssh/config"
    else
        log_warn "SSH config not found, skipping..."
    fi

    # App configs (~/.config/)
    run mkdir -p "$HOME/.config/zed"
    run mkdir -p "$HOME/.config/ghostty"
    run mkdir -p "$HOME/.config/aichat"
    run mkdir -p "$HOME/.config/gh"

    # Zed
    if [[ -d "$DOTFILES_DIR/config/zed" ]]; then
        run ln -sfv "$DOTFILES_DIR/config/zed/settings.json" "$HOME/.config/zed/settings.json"
        run ln -sfv "$DOTFILES_DIR/config/zed/keymap.json" "$HOME/.config/zed/keymap.json"
        run ln -sfv "$DOTFILES_DIR/config/zed/tasks.json" "$HOME/.config/zed/tasks.json"
    else
        log_warn "Zed config not found, skipping..."
    fi

    # Ghostty
    if [[ -f "$DOTFILES_DIR/config/ghostty/config" ]]; then
        run ln -sfv "$DOTFILES_DIR/config/ghostty/config" "$HOME/.config/ghostty/config"
    else
        log_warn "Ghostty config not found, skipping..."
    fi

    # aichat
    if [[ -f "$DOTFILES_DIR/config/aichat/config.yaml" ]]; then
        run ln -sfv "$DOTFILES_DIR/config/aichat/config.yaml" "$HOME/.config/aichat/config.yaml"
    else
        log_warn "aichat config not found, skipping..."
    fi

    # GitHub CLI
    if [[ -f "$DOTFILES_DIR/config/gh/config.yml" ]]; then
        run ln -sfv "$DOTFILES_DIR/config/gh/config.yml" "$HOME/.config/gh/config.yml"
    else
        log_warn "GitHub CLI config not found, skipping..."
    fi

    return 0
}

mackup_setup() {
    log_info "Setting up Mackup for app settings backup..."

    if [[ -f "$DOTFILES_DIR/.mackup.cfg" ]]; then
        run rm -f "$HOME/.mackup.cfg"
        run ln -sfv "$DOTFILES_DIR/.mackup.cfg" "$HOME/.mackup.cfg"
    else
        log_warn ".mackup.cfg not found in dotfiles"
    fi

    log_info "Run 'mackup restore' manually after setup to restore app settings from iCloud"

    return 0
}

vscode_setup() {
    log_info "Setting up VS Code..."

    VSCODE_USER="$HOME/Library/Application Support/Code/User"
    run mkdir -p "$VSCODE_USER"

    # Settings
    if [[ -f "$DOTFILES_DIR/vscode/settings.json" ]]; then
        run ln -sfv "$DOTFILES_DIR/vscode/settings.json" "$VSCODE_USER/settings.json"
    else
        log_warn "VS Code settings not found, skipping..."
    fi

    # Extensions
    if command -v code &> /dev/null; then
        if [[ -f "$DOTFILES_DIR/vscode/extensions.txt" ]]; then
            log_info "Installing VS Code extensions..."
            if $DRY_RUN; then
                echo -e "${YELLOW}[DRY-RUN]${NC} Would install $(wc -l < "$DOTFILES_DIR/vscode/extensions.txt" | tr -d ' ') extensions"
            else
                while IFS= read -r extension; do
                    code --install-extension "$extension" --force 2>/dev/null || log_warn "Failed to install: $extension"
                done < "$DOTFILES_DIR/vscode/extensions.txt"
            fi
        fi
    else
        log_warn "VS Code CLI not found. Install extensions manually after installing VS Code."
    fi

    return 0
}

ai_tools_setup() {
    log_info "Installing AI coding tools..."

    # Claude Code (native installation)
    if ! command -v claude &> /dev/null; then
        log_info "Installing Claude Code..."
        if $DRY_RUN; then
            echo -e "${YELLOW}[DRY-RUN]${NC} curl -fsSL https://claude.ai/install.sh | bash"
        else
            curl -fsSL https://claude.ai/install.sh | bash || log_warn "Claude Code installation failed"
        fi
    else
        log_info "Claude Code already installed"
    fi

    # OpenAI Codex CLI
    if ! command -v codex &> /dev/null; then
        if command -v npm &> /dev/null; then
            log_info "Installing OpenAI Codex..."
            run npm i -g @openai/codex || log_warn "OpenAI Codex installation failed"
        else
            log_warn "npm not found, skipping OpenAI Codex installation"
        fi
    else
        log_info "OpenAI Codex already installed"
    fi

    return 0
}

claude_setup() {
    log_info "Setting up Claude Code configuration..."

    # Create directories
    run mkdir -p "$HOME/.claude/skills"
    run mkdir -p "$HOME/.claude/hooks"
    run mkdir -p "$HOME/.agents/skills"

    # Remove existing files/symlinks (clean slate)
    run rm -f "$HOME/.claude/CLAUDE.md"
    run rm -f "$HOME/.claude/settings.json"
    run rm -f "$HOME/.claude/statusline-command.sh"

    # Copy config files from backup
    if [[ -d "$DOTFILES_DIR/claude/backup" ]]; then
        log_info "Copying Claude config files..."
        run cp "$DOTFILES_DIR/claude/backup/CLAUDE.md" "$HOME/.claude/" 2>/dev/null || true
        run cp "$DOTFILES_DIR/claude/backup/settings.json" "$HOME/.claude/" 2>/dev/null || true
        run cp "$DOTFILES_DIR/claude/backup/statusline-command.sh" "$HOME/.claude/" 2>/dev/null || true
        run chmod +x "$HOME/.claude/statusline-command.sh" 2>/dev/null || true
    else
        log_warn "Claude backup directory not found, skipping config copy..."
    fi

    # Copy hooks
    if [[ -d "$DOTFILES_DIR/claude/backup/hooks" ]]; then
        log_info "Copying hooks to ~/.claude/hooks/..."
        for hook_file in "$DOTFILES_DIR/claude/backup/hooks"/*; do
            if [[ -f "$hook_file" ]]; then
                hook_name=$(basename "$hook_file")
                log_info "  - $hook_name"
                run cp "$hook_file" "$HOME/.claude/hooks/"
                run chmod +x "$HOME/.claude/hooks/$hook_name"
            fi
        done
    fi

    # Copy personal skills
    if [[ -d "$DOTFILES_DIR/claude/backup/skills" ]]; then
        log_info "Copying personal skills to ~/.claude/skills/..."
        for skill_dir in "$DOTFILES_DIR/claude/backup/skills"/*/; do
            if [[ -d "$skill_dir" ]]; then
                skill_name=$(basename "$skill_dir")
                log_info "  - $skill_name"
                run rm -rf "$HOME/.claude/skills/$skill_name"
                run cp -R "$skill_dir" "$HOME/.claude/skills/$skill_name"
            fi
        done
    fi

    # Copy community skills
    if [[ -d "$DOTFILES_DIR/claude/backup/agents-skills" ]]; then
        log_info "Copying community skills to ~/.agents/skills/..."
        for skill_dir in "$DOTFILES_DIR/claude/backup/agents-skills"/*/; do
            if [[ -d "$skill_dir" ]]; then
                skill_name=$(basename "$skill_dir")
                log_info "  - $skill_name"
                run rm -rf "$HOME/.agents/skills/$skill_name"
                run cp -R "$skill_dir" "$HOME/.agents/skills/$skill_name"
            fi
        done
    fi

    # Create symlinks for community skills
    log_info "Creating community skill symlinks in ~/.claude/skills/..."
    for skill_dir in "$HOME/.agents/skills"/*/; do
        if [[ -d "$skill_dir" ]]; then
            skill_name=$(basename "$skill_dir")
            if [[ ! -e "$HOME/.claude/skills/$skill_name" ]]; then
                run ln -sv "../../.agents/skills/$skill_name" "$HOME/.claude/skills/$skill_name"
            fi
        fi
    done

    # Copy plugins list
    if [[ -f "$DOTFILES_DIR/claude/backup/plugins/installed_plugins.json" ]]; then
        log_info "Copying installed_plugins.json..."
        run mkdir -p "$HOME/.claude/plugins"
        run cp "$DOTFILES_DIR/claude/backup/plugins/installed_plugins.json" "$HOME/.claude/plugins/"
    fi

    # Create settings.local.json template if it doesn't exist
    if [[ ! -f "$HOME/.claude/settings.local.json" ]]; then
        log_info "Creating settings.local.json template..."
        if ! $DRY_RUN; then
            cat > "$HOME/.claude/settings.local.json" << 'EOF'
{
  "env": {
    "VERCEL_TOKEN": "<YOUR_VERCEL_TOKEN>"
  }
}
EOF
        fi
    fi

    return 0
}

autocommit_setup() {
    log_info "Setting up dotfiles auto-backup agent..."

    if [[ -x "$DOTFILES_DIR/scripts/install-autocommit.sh" ]]; then
        run "$DOTFILES_DIR/scripts/install-autocommit.sh"
    else
        log_error "install-autocommit.sh not found or not executable"
        return 1
    fi

    return 0
}

dock_setup() {
    log_info "Setting up Dock..."

    if ! command -v dockutil &> /dev/null; then
        log_warn "dockutil not found, skipping dock setup"
        return 0
    fi

    DOCK_APPS="$DOTFILES_DIR/dock/dock-apps.txt"
    if [[ ! -f "$DOCK_APPS" ]]; then
        log_warn "dock-apps.txt not found, skipping dock setup"
        return 0
    fi

    # Dock preferences
    log_info "Setting dock preferences..."
    run defaults write com.apple.dock orientation -string "left"
    run defaults write com.apple.dock tilesize -int 48
    run defaults write com.apple.dock largesize -int 54
    run defaults write com.apple.dock magnification -bool true
    run defaults write com.apple.dock autohide -bool false
    run defaults write com.apple.dock minimize-to-application -bool true
    run defaults write com.apple.dock mineffect -string "genie"
    run defaults write com.apple.dock show-recents -bool false

    # Clear existing dock apps
    log_info "Clearing dock and adding apps..."
    run dockutil --remove all --no-restart

    # Add apps from dock-apps.txt
    while IFS= read -r app_path; do
        [[ -z "$app_path" || "$app_path" == \#* ]] && continue
        if [[ -d "$app_path" ]]; then
            log_info "  + $(basename "$app_path" .app)"
            run dockutil --add "$app_path" --no-restart
        else
            log_warn "  App not found: $app_path"
        fi
    done < "$DOCK_APPS"

    # Add Downloads folder
    log_info "  + Downloads folder"
    run dockutil --add "$HOME/Downloads" --sort dateadded --view fan --display folder --no-restart

    # Restart Dock
    log_info "Restarting Dock..."
    run killall Dock

    return 0
}

xcode_cl_tools() {
    log_info "Checking Xcode command line tools..."

    if xcode-select -p &>/dev/null; then
        log_info "Xcode command line tools already installed"
        return 0
    fi

    log_info "Installing Xcode command line tools..."
    run xcode-select --install || log_warn "Xcode CLI tools installation may require manual intervention"

    # Accept Xcode license
    log_info "Accepting Xcode license..."
    run sudo xcodebuild -license accept 2>/dev/null || log_warn "Xcode license acceptance failed (Xcode may not be installed yet)"

    return 0
}

macos_defaults_setup() {
    log_info "Setting macOS preferences..."

    if [[ -f "$DOTFILES_DIR/.macos" ]]; then
        # shellcheck source=/dev/null
        run source "$DOTFILES_DIR/.macos"
    else
        log_warn ".macos file not found, skipping..."
    fi

    return 0
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                    DOTFILES INSTALLATION                       ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    log_info "Dotfiles directory: $DOTFILES_DIR"

    if $DRY_RUN; then
        echo ""
        echo -e "${YELLOW}>>> DRY-RUN MODE: No changes will be made <<<${NC}"
    fi

    # Run each setup with error handling (continue on failure)
    run_setup brew_setup "Homebrew packages" || true
    # run_setup zsh_setup "Zsh and oh-my-zsh" || true  # Uncomment if needed
    run_setup dotfile_setup "Shell dotfiles" || true
    run_setup config_setup "App configurations" || true
    run_setup vscode_setup "VS Code" || true
    run_setup ai_tools_setup "AI coding tools" || true
    run_setup claude_setup "Claude Code configuration" || true
    run_setup xcode_cl_tools "Xcode command line tools" || true
    run_setup mackup_setup "Mackup app settings backup" || true
    run_setup autocommit_setup "Dotfiles auto-backup agent" || true
    run_setup dock_setup "Dock configuration" || true
    # run_setup macos_defaults_setup "macOS preferences" || true  # Uncomment if needed

    # Summary
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                    SUMMARY"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ ${#ERRORS[@]} -eq 0 ]]; then
        echo -e "${GREEN}All steps completed successfully!${NC}"
    else
        echo -e "${YELLOW}Completed with ${#ERRORS[@]} error(s):${NC}"
        for error in "${ERRORS[@]}"; do
            echo -e "  ${RED}•${NC} $error"
        done
    fi

    if $DRY_RUN; then
        echo ""
        echo -e "${YELLOW}This was a dry run. No changes were made.${NC}"
        echo "Run without --dry-run to apply changes."
    fi

    echo ""
}

main "$@"
