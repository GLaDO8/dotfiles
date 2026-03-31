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
SUDO_PID=$!

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
DIM='\033[2m'
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

# Temp dir for parallel job output
PARALLEL_DIR=$(mktemp -d)
trap 'rm -rf "$PARALLEL_DIR"; kill $SUDO_PID 2>/dev/null' EXIT

# ============================================================================
# Logging
# ============================================================================

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

log_phase() {
    echo ""
    echo -e "${CYAN}┌──────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}  Phase $1: $2"
    echo -e "${CYAN}└──────────────────────────────────────────────────────┘${NC}"
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

# Run a setup function with error handling (foreground)
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
# Parallel execution helpers
# ============================================================================

BG_PIDS=()
BG_LOGS=()
BG_NAMES=()

# Run a setup function in the background, capturing output to a temp file
run_setup_bg() {
    local func_name=$1
    local description=$2
    local log_file="$PARALLEL_DIR/${func_name}.log"

    (
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "${BLUE}[INFO]${NC} Starting: $description"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        if $func_name; then
            echo -e "${GREEN}[OK]${NC} Completed: $description"
        else
            echo -e "${RED}[ERROR]${NC} Failed: $description"
            echo "$description" >> "$PARALLEL_DIR/errors"
        fi
    ) > "$log_file" 2>&1 &

    BG_PIDS+=($!)
    BG_LOGS+=("$log_file")
    BG_NAMES+=("$description")
}

# Wait for all background jobs and replay their output in order
wait_phase() {
    local i
    for i in "${!BG_PIDS[@]}"; do
        wait "${BG_PIDS[$i]}" 2>/dev/null || true
        # Replay captured output
        [[ -f "${BG_LOGS[$i]}" ]] && cat "${BG_LOGS[$i]}"
    done

    # Collect errors from background jobs
    if [[ -f "$PARALLEL_DIR/errors" ]]; then
        while IFS= read -r err; do
            ERRORS+=("Failed: $err")
        done < "$PARALLEL_DIR/errors"
        rm -f "$PARALLEL_DIR/errors"
    fi

    BG_PIDS=()
    BG_LOGS=()
    BG_NAMES=()
}

# ============================================================================
# Setup Functions
# ============================================================================

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

secrets_setup() {
    log_info "Decrypting secrets from sops-encrypted store..."

    local encrypted="$DOTFILES_DIR/secrets/secrets.yaml"
    local target="$HOME/.secrets"

    if [[ ! -f "$encrypted" ]]; then
        log_warn "No encrypted secrets file found at $encrypted"
        return 0
    fi

    if ! command -v sops &> /dev/null; then
        log_warn "sops not installed, skipping secrets decryption"
        return 0
    fi

    # Check for age key
    if [[ ! -f "$HOME/.config/sops/age/keys.txt" ]]; then
        log_warn "Age private key not found at ~/.config/sops/age/keys.txt"
        log_warn "Transfer your age key to this machine, then run: sops -d $encrypted"
        return 0
    fi

    # Decrypt YAML and convert to shell exports
    log_info "Decrypting to $target..."
    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN]${NC} sops -d $encrypted → $target (as shell exports)"
        return 0
    fi

    local decrypted
    decrypted=$(sops decrypt "$encrypted" 2>/dev/null) || {
        log_error "sops decryption failed — check your age key"
        return 1
    }

    # Convert YAML key: value to export KEY="value" (skip comments and blank lines)
    echo "# Auto-generated from secrets/secrets.yaml — do not edit directly" > "$target"
    echo "# To modify: cd dotfiles && sops secrets/secrets.yaml" >> "$target"
    echo "$decrypted" | grep -v '^#' | grep -v '^$' | while IFS=': ' read -r key value; do
        # Strip surrounding quotes from value
        value="${value#\"}"
        value="${value%\"}"
        echo "export $key=\"$value\"" >> "$target"
    done

    chmod 600 "$target"
    log_success "Secrets decrypted to $target"

    return 0
}

zsh_setup() {
    # Make ZSH the default shell environment
    if [[ "$SHELL" != *"zsh"* ]]; then
        log_info "Setting zsh as default shell..."
        run chsh -s "$(which zsh)"
    else
        log_info "Zsh is already the default shell"
    fi

    # antidote (plugin manager) is installed via Brewfile
    # Plugins are declared in .zsh_plugins.txt and bundled on first shell load
    log_info "Zsh plugins managed by antidote — will be installed on first shell launch"

    return 0
}

dotfile_setup() {
    log_info "Setting up shell dotfiles..."

    # Create symlinks for shell dotfiles in home directory
    run rm -rf "$HOME/.zshrc"
    run ln -sfv "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
    run ln -sfv "$DOTFILES_DIR/zsh/.zsh_plugins.txt" "$HOME/.zsh_plugins.txt"
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

    # Global ignore (ripgrep, fd, etc.)
    if [[ -f "$DOTFILES_DIR/.ignore" ]]; then
        run ln -sfv "$DOTFILES_DIR/.ignore" "$HOME/.ignore"
    fi

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
    run mkdir -p "$HOME/.config/ghostty/shaders"
    run mkdir -p "$HOME/.config/aichat"
    run mkdir -p "$HOME/.config/gh"
    run mkdir -p "$HOME/.config/btop"
    run mkdir -p "$HOME/.config/git"
    run mkdir -p "$HOME/.config/atuin"
    run mkdir -p "$HOME/.config/karabiner"

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
        for shader in "$DOTFILES_DIR/config/ghostty/shaders"/*.glsl; do
            [[ -f "$shader" ]] && run ln -sfv "$shader" "$HOME/.config/ghostty/shaders/$(basename "$shader")"
        done
    else
        log_warn "Ghostty config not found, skipping..."
    fi

    # btop
    if [[ -f "$DOTFILES_DIR/config/btop/btop.conf" ]]; then
        run ln -sfv "$DOTFILES_DIR/config/btop/btop.conf" "$HOME/.config/btop/btop.conf"
    else
        log_warn "btop config not found, skipping..."
    fi

    # Git global ignore
    if [[ -f "$DOTFILES_DIR/config/git/ignore" ]]; then
        run ln -sfv "$DOTFILES_DIR/config/git/ignore" "$HOME/.config/git/ignore"
    else
        log_warn "Git global ignore not found, skipping..."
    fi

    # Atuin
    if [[ -f "$DOTFILES_DIR/config/atuin/config.toml" ]]; then
        run ln -sfv "$DOTFILES_DIR/config/atuin/config.toml" "$HOME/.config/atuin/config.toml"
    else
        log_warn "Atuin config not found, skipping..."
    fi

    # Karabiner (copy, not symlink — Karabiner rewrites atomically and breaks symlinks)
    if [[ -f "$DOTFILES_DIR/config/karabiner/karabiner.json" ]]; then
        run cp "$DOTFILES_DIR/config/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"
    else
        log_warn "Karabiner config not found, skipping..."
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

    # Zellij
    run mkdir -p "$HOME/.config/zellij/layouts"
    if [[ -f "$DOTFILES_DIR/config/zellij/config.kdl" ]]; then
        run ln -sfv "$DOTFILES_DIR/config/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"
        for layout in "$DOTFILES_DIR/config/zellij/layouts"/*.kdl; do
            [[ -f "$layout" ]] && run ln -sfv "$layout" "$HOME/.config/zellij/layouts/$(basename "$layout")"
        done
    else
        log_warn "Zellij config not found, skipping..."
    fi

    # Helix
    run mkdir -p "$HOME/.config/helix"
    if [[ -f "$DOTFILES_DIR/config/helix/config.toml" ]]; then
        run ln -sfv "$DOTFILES_DIR/config/helix/config.toml" "$HOME/.config/helix/config.toml"
    else
        log_warn "Helix config not found, skipping..."
    fi

    # Neovim
    run mkdir -p "$HOME/.config/nvim"
    if [[ -d "$DOTFILES_DIR/config/nvim" ]]; then
        run ln -sfv "$DOTFILES_DIR/config/nvim/init.lua" "$HOME/.config/nvim/init.lua"
        [[ -f "$DOTFILES_DIR/config/nvim/lazy-lock.json" ]] && run ln -sfv "$DOTFILES_DIR/config/nvim/lazy-lock.json" "$HOME/.config/nvim/lazy-lock.json"
    else
        log_warn "Neovim config not found, skipping..."
    fi

    # Yazi
    run mkdir -p "$HOME/.config/yazi"
    if [[ -d "$DOTFILES_DIR/config/yazi" ]]; then
        run ln -sfv "$DOTFILES_DIR/config/yazi/yazi.toml" "$HOME/.config/yazi/yazi.toml"
        run ln -sfv "$DOTFILES_DIR/config/yazi/keymap.toml" "$HOME/.config/yazi/keymap.toml"
    else
        log_warn "Yazi config not found, skipping..."
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

    # Extensions (parallel install with xargs)
    if command -v code &> /dev/null; then
        if [[ -f "$DOTFILES_DIR/vscode/extensions.txt" ]]; then
            local ext_count
            ext_count=$(wc -l < "$DOTFILES_DIR/vscode/extensions.txt" | tr -d ' ')
            log_info "Installing $ext_count VS Code extensions (4 parallel)..."
            if $DRY_RUN; then
                echo -e "${YELLOW}[DRY-RUN]${NC} Would install $ext_count extensions"
            else
                xargs -P4 -I{} code --install-extension {} --force 2>/dev/null \
                    < "$DOTFILES_DIR/vscode/extensions.txt" \
                    || log_warn "Some VS Code extensions failed to install"
            fi
        fi
    else
        log_warn "VS Code CLI not found. Install extensions manually after installing VS Code."
    fi

    return 0
}

cursor_setup() {
    log_info "Setting up Cursor..."

    CURSOR_USER="$HOME/Library/Application Support/Cursor/User"
    run mkdir -p "$CURSOR_USER"

    # Settings
    if [[ -f "$DOTFILES_DIR/cursor/settings.json" ]]; then
        run ln -sfv "$DOTFILES_DIR/cursor/settings.json" "$CURSOR_USER/settings.json"
    else
        log_warn "Cursor settings not found, skipping..."
    fi

    # Keybindings
    if [[ -f "$DOTFILES_DIR/cursor/keybindings.json" ]]; then
        run ln -sfv "$DOTFILES_DIR/cursor/keybindings.json" "$CURSOR_USER/keybindings.json"
    else
        log_warn "Cursor keybindings not found, skipping..."
    fi

    # Extensions (parallel install with xargs)
    if command -v cursor &> /dev/null; then
        if [[ -f "$DOTFILES_DIR/cursor/extensions.txt" ]]; then
            local ext_count
            ext_count=$(wc -l < "$DOTFILES_DIR/cursor/extensions.txt" | tr -d ' ')
            log_info "Installing $ext_count Cursor extensions (4 parallel)..."
            if $DRY_RUN; then
                echo -e "${YELLOW}[DRY-RUN]${NC} Would install $ext_count extensions"
            else
                xargs -P4 -I{} cursor --install-extension {} --force 2>/dev/null \
                    < "$DOTFILES_DIR/cursor/extensions.txt" \
                    || log_warn "Some Cursor extensions failed to install"
            fi
        fi
    else
        log_warn "Cursor CLI not found. Install extensions manually after installing Cursor."
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
    run mkdir -p "$HOME/.claude/agent-docs"
    run mkdir -p "$HOME/.claude/rules"
    run mkdir -p "$HOME/.agents/skills"

    # Remove existing files/symlinks (clean slate)
    run rm -f "$HOME/.claude/CLAUDE.md"
    run rm -f "$HOME/.claude/RTK.md"
    run rm -f "$HOME/.claude/settings.json"
    run rm -f "$HOME/.claude/statusline-command.sh"
    run rm -f "$HOME/.claude/statusline.sh"
    run rm -f "$HOME/.claude/statusline.conf"
    run rm -f "$HOME/.claude/sl-toggle.sh"

    # Copy config files from backup (full parity with backup-config.sh)
    if [[ -d "$DOTFILES_DIR/claude" ]]; then
        log_info "Copying Claude config files..."
        local claude_files=(
            "CLAUDE.md"
            "RTK.md"
            "settings.json"
            "statusline-command.sh"
            "statusline.sh"
            "statusline.conf"
            "sl-toggle.sh"
        )
        for f in "${claude_files[@]}"; do
            [[ -f "$DOTFILES_DIR/claude/$f" ]] && run cp "$DOTFILES_DIR/claude/$f" "$HOME/.claude/"
        done
        # Make shell scripts executable
        for f in statusline-command.sh statusline.sh sl-toggle.sh; do
            [[ -f "$HOME/.claude/$f" ]] && run chmod +x "$HOME/.claude/$f"
        done
    else
        log_warn "Claude backup directory not found, skipping config copy..."
    fi

    # Copy hooks
    if [[ -d "$DOTFILES_DIR/claude/hooks" ]]; then
        log_info "Copying hooks to ~/.claude/hooks/..."
        for hook_file in "$DOTFILES_DIR/claude/hooks"/*; do
            if [[ -f "$hook_file" ]]; then
                hook_name=$(basename "$hook_file")
                log_info "  - $hook_name"
                run cp "$hook_file" "$HOME/.claude/hooks/"
                run chmod +x "$HOME/.claude/hooks/$hook_name"
            fi
        done
    fi

    # Copy agent-docs
    if [[ -d "$DOTFILES_DIR/claude/agent-docs" ]]; then
        log_info "Syncing agent-docs to ~/.claude/agent-docs/..."
        if ! $DRY_RUN; then
            rsync -a --delete "$DOTFILES_DIR/claude/agent-docs/" "$HOME/.claude/agent-docs/"
        else
            echo -e "${YELLOW}[DRY-RUN]${NC} rsync agent-docs/"
        fi
    fi

    # Copy rules
    if [[ -d "$DOTFILES_DIR/claude/rules" ]]; then
        log_info "Syncing rules to ~/.claude/rules/..."
        if ! $DRY_RUN; then
            rsync -a --delete "$DOTFILES_DIR/claude/rules/" "$HOME/.claude/rules/"
        else
            echo -e "${YELLOW}[DRY-RUN]${NC} rsync rules/"
        fi
    fi

    # Copy personal skills
    if [[ -d "$DOTFILES_DIR/claude/skills" ]]; then
        log_info "Copying personal skills to ~/.claude/skills/..."
        for skill_dir in "$DOTFILES_DIR/claude/skills"/*/; do
            if [[ -d "$skill_dir" ]]; then
                skill_name=$(basename "$skill_dir")
                log_info "  - $skill_name"
                run rm -rf "$HOME/.claude/skills/$skill_name"
                run cp -R "$skill_dir" "$HOME/.claude/skills/$skill_name"
            fi
        done
    fi

    # Copy community skills
    if [[ -d "$DOTFILES_DIR/claude/agents-skills" ]]; then
        log_info "Copying community skills to ~/.agents/skills/..."
        for skill_dir in "$DOTFILES_DIR/claude/agents-skills"/*/; do
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
    if [[ -f "$DOTFILES_DIR/claude/plugins/installed_plugins.json" ]]; then
        log_info "Copying installed_plugins.json..."
        run mkdir -p "$HOME/.claude/plugins"
        run cp "$DOTFILES_DIR/claude/plugins/installed_plugins.json" "$HOME/.claude/plugins/"
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
    local start_time=$SECONDS

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

    # ── Phase 1: Prerequisites (sequential) ──────────────────────
    log_phase "1/4" "Prerequisites"
    run_setup xcode_cl_tools "Xcode command line tools" || true
    run_setup brew_setup "Homebrew packages" || true

    # ── Phase 2: Configuration (instant, sequential) ─────────────
    log_phase "2/4" "Configuration"
    run_setup secrets_setup "Decrypt secrets" || true
    run_setup dotfile_setup "Shell dotfiles" || true
    run_setup config_setup "App configurations" || true

    # ── Phase 3: App setup (parallel) ────────────────────────────
    log_phase "3/4" "App setup (parallel)"
    run_setup_bg vscode_setup "VS Code"
    run_setup_bg cursor_setup "Cursor"
    run_setup_bg ai_tools_setup "AI coding tools"
    run_setup_bg autocommit_setup "Dotfiles auto-backup agent"
    wait_phase

    # ── Phase 4: Final setup (sequential) ────────────────────────
    log_phase "4/4" "Final setup"
    run_setup claude_setup "Claude Code configuration" || true
    run_setup mackup_setup "Mackup app settings backup" || true
    run_setup macos_defaults_setup "macOS preferences" || true
    run_setup dock_setup "Dock configuration" || true

    # ── Summary ──────────────────────────────────────────────────
    local elapsed=$(( SECONDS - start_time ))
    local minutes=$(( elapsed / 60 ))
    local seconds=$(( elapsed % 60 ))

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

    echo -e "${DIM}Elapsed: ${minutes}m ${seconds}s${NC}"

    if $DRY_RUN; then
        echo ""
        echo -e "${YELLOW}This was a dry run. No changes were made.${NC}"
        echo "Run without --dry-run to apply changes."
    fi

    echo ""
}

main "$@"
