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
set -uo pipefail

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
INSTALL_MAS="${INSTALL_MAS:-false}"
INSTALL_VALIDATE="${INSTALL_VALIDATE:-true}"
BREW_UPGRADE="${BREW_UPGRADE:-false}"
SUDO_PID=""
BACKUP_ROOT="${BACKUP_ROOT:-$HOME/.dotfiles-backup}"
BACKUP_DIR=""

BREW_STATE_LOADED=false
MAS_STATE_LOADED=false
HAS_MAS_ACCOUNT=false
INSTALLED_TAPS=()
INSTALLED_FORMULAS=()
INSTALLED_CASKS=()
INSTALLED_MAS_IDS=()

# Parse arguments
for arg in "$@"; do
    case $arg in
        -n|--dry-run)
            DRY_RUN=true
            ;;
        -h|--help)
            cat <<EOF
Usage: ./install.sh [OPTIONS]

Options:
  -n, --dry-run   Preview changes without applying them
  -h, --help      Show this help

Environment:
  DOTFILES_DIR        Override dotfiles directory
  INSTALL_MAS=true    Include Mac App Store installs from Brewfile
  BREW_UPGRADE=true   Run brew upgrade before restoring packages
  INSTALL_VALIDATE=false  Skip post-install validation
  BACKUP_ROOT=...     Override backup root for replaced files
EOF
            exit 0
            ;;
    esac
done

# Temp dir for parallel job output
PARALLEL_DIR=$(mktemp -d)
trap 'rm -rf "$PARALLEL_DIR"; [[ -n "$SUDO_PID" ]] && kill "$SUDO_PID" 2>/dev/null' EXIT

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

ensure_backup_dir() {
    if [[ -n "$BACKUP_DIR" ]]; then
        return 0
    fi

    BACKUP_DIR="$BACKUP_ROOT/install-$(date +%Y%m%d_%H%M%S)"
    if $DRY_RUN; then
        return 0
    fi

    mkdir -p "$BACKUP_DIR"
}

backup_path() {
    local target=$1
    local backup_path

    if [[ ! -e "$target" ]] && [[ ! -L "$target" ]]; then
        return 0
    fi

    ensure_backup_dir || return 1

    backup_path="$BACKUP_DIR/${target#/}"
    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN]${NC} backup $target -> $backup_path"
        return 0
    fi

    mkdir -p "$(dirname "$backup_path")"
    mv "$target" "$backup_path"
    log_info "Backed up $target to $backup_path"
}

ensure_parent_dir() {
    local target=$1
    run mkdir -p "$(dirname "$target")"
}

ensure_symlink() {
    local source=$1
    local target=$2
    local current_target=""
    local resolved_target=""

    if [[ ! -e "$source" ]]; then
        log_warn "Missing source, skipping symlink: $source"
        return 0
    fi

    ensure_parent_dir "$target" || return 1

    if [[ -L "$target" ]]; then
        current_target=$(readlink "$target")
        if [[ "$current_target" == "$source" ]]; then
            return 0
        fi

        resolved_target=$(cd "$(dirname "$target")" && cd "$(dirname "$current_target")" 2>/dev/null && pwd)/$(basename "$current_target")
        if [[ "$resolved_target" == "$source" ]]; then
            return 0
        fi
    elif [[ -e "$target" ]]; then
        backup_path "$target" || return 1
    fi

    run ln -sfn "$source" "$target"
}

ensure_copy() {
    local source=$1
    local target=$2

    if [[ ! -e "$source" ]]; then
        log_warn "Missing source, skipping copy: $source"
        return 0
    fi

    ensure_parent_dir "$target" || return 1

    if [[ -L "$target" ]]; then
        backup_path "$target" || return 1
    elif [[ -f "$target" ]] && cmp -s "$source" "$target"; then
        return 0
    elif [[ -e "$target" ]]; then
        backup_path "$target" || return 1
    fi

    run cp "$source" "$target"
}

ensure_symlink_tree() {
    local source_dir=$1
    local target_dir=$2
    local source_path
    local relative_path

    if [[ ! -d "$source_dir" ]]; then
        log_warn "Missing directory, skipping: $source_dir"
        return 0
    fi

    while IFS= read -r source_path; do
        relative_path="${source_path#"$source_dir"/}"
        ensure_symlink "$source_path" "$target_dir/$relative_path" || return 1
    done < <(find "$source_dir" -type f | sort)
}

array_contains() {
    local value=$1
    shift
    printf '%s\n' "$@" | grep -Fxq -- "$value"
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

setup_sudo_session() {
    if $DRY_RUN; then
        return 0
    fi

    sudo -v || return 1
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    SUDO_PID=$!
}

preflight_checks() {
    log_info "Running preflight checks..."

    if [[ "$(uname -s)" != "Darwin" ]]; then
        log_error "This installer only supports macOS"
        return 1
    fi

    if [[ ! -d "$DOTFILES_DIR" ]]; then
        log_error "Dotfiles directory not found: $DOTFILES_DIR"
        return 1
    fi

    if [[ ! -f "$DOTFILES_DIR/Brewfile" ]]; then
        log_error "Brewfile not found at $DOTFILES_DIR/Brewfile"
        return 1
    fi

    if ! $DRY_RUN && [[ ! -w "$HOME" ]]; then
        log_error "Home directory is not writable: $HOME"
        return 1
    fi

    return 0
}

# ============================================================================
# Brewfile helpers
# ============================================================================

quoted_field() {
    local line=$1
    local position=$2

    awk -F'"' -v position="$position" '{print $(position * 2)}' <<< "$line"
}

should_process_brewfile_line() {
    local line=$1

    [[ "$line" =~ ^[[:space:]]*# ]] && return 1
    [[ -z "${line// }" ]] && return 1

    if [[ "$line" =~ ^mas[[:space:]]+ ]] && [[ "$INSTALL_MAS" != "true" ]]; then
        return 1
    fi

    [[ "$line" =~ ^(tap|brew|cask|mas|go)[[:space:]]+ ]]
}

brewfile_entry_total() {
    local line
    local total=0

    while IFS= read -r line; do
        if should_process_brewfile_line "$line"; then
            ((total++))
        fi
    done < "$DOTFILES_DIR/Brewfile"

    echo "$total"
}

load_brew_state() {
    local item

    if $BREW_STATE_LOADED; then
        return 0
    fi

    INSTALLED_TAPS=()
    INSTALLED_FORMULAS=()
    INSTALLED_CASKS=()

    while IFS= read -r item; do
        [[ -n "$item" ]] && INSTALLED_TAPS+=("$item")
    done < <(brew tap)

    while IFS= read -r item; do
        [[ -n "$item" ]] && INSTALLED_FORMULAS+=("$item")
    done < <(brew list --formula 2>/dev/null)

    while IFS= read -r item; do
        [[ -n "$item" ]] && INSTALLED_CASKS+=("$item")
    done < <(brew list --cask 2>/dev/null)

    BREW_STATE_LOADED=true
}

load_mas_state() {
    local item
    local app_id

    if $MAS_STATE_LOADED; then
        return 0
    fi

    INSTALLED_MAS_IDS=()
    HAS_MAS_ACCOUNT=false

    if ! command -v mas &>/dev/null; then
        MAS_STATE_LOADED=true
        return 0
    fi

    if mas account &>/dev/null; then
        HAS_MAS_ACCOUNT=true
        while IFS= read -r item; do
            [[ -z "$item" ]] && continue
            app_id=${item%% *}
            [[ -n "$app_id" ]] && INSTALLED_MAS_IDS+=("$app_id")
        done < <(mas list 2>/dev/null)
    fi

    MAS_STATE_LOADED=true
}

brewfile_install_entry() {
    local index=$1
    local total=$2
    local line=$3
    local type
    local link_false=false
    local primary_field
    local secondary_field

    type=${line%% *}
    primary_field=$(quoted_field "$line" 1)
    secondary_field=$(quoted_field "$line" 2)

    case "$type" in
        tap)
            local tap_name="$primary_field"
            local tap_url="$secondary_field"
            log_info "[$index/$total] tap $tap_name"

            load_brew_state
            if array_contains "$tap_name" "${INSTALLED_TAPS[@]}"; then
                log_success "Already tapped: $tap_name"
                return 0
            fi

            if [[ -n "$tap_url" ]]; then
                run brew tap "$tap_name" "$tap_url" || return 1
            else
                run brew tap "$tap_name" || return 1
            fi
            INSTALLED_TAPS+=("$tap_name")
            ;;

        brew)
            local formula="$primary_field"
            [[ "$line" == *"link: false"* ]] && link_false=true
            log_info "[$index/$total] brew $formula"

            load_brew_state
            if array_contains "$formula" "${INSTALLED_FORMULAS[@]}"; then
                log_success "Already installed: $formula"
                return 0
            fi

            run brew install "$formula" || return 1
            if $link_false; then
                run brew unlink "$formula" || log_warn "Could not unlink $formula after install"
            fi
            INSTALLED_FORMULAS+=("$formula")
            ;;

        cask)
            local cask="$primary_field"
            log_info "[$index/$total] cask $cask"

            load_brew_state
            if array_contains "$cask" "${INSTALLED_CASKS[@]}"; then
                log_success "Already installed: $cask"
                return 0
            fi

            run brew install --cask "$cask" || return 1
            INSTALLED_CASKS+=("$cask")
            ;;

        mas)
            local app_name="$primary_field"
            local app_id

            load_mas_state

            if ! command -v mas &>/dev/null; then
                log_warn "mas CLI not installed yet, skipping App Store app: $app_name"
                return 1
            fi

            if ! $HAS_MAS_ACCOUNT; then
                log_warn "App Store account not signed in, skipping: $app_name"
                return 1
            fi

            if [[ "$line" =~ id:[[:space:]]*([0-9]+) ]]; then
                app_id="${BASH_REMATCH[1]}"
            else
                log_warn "Could not parse App Store ID for: $app_name"
                return 1
            fi

            log_info "[$index/$total] mas $app_name"

            if array_contains "$app_id" "${INSTALLED_MAS_IDS[@]}"; then
                log_success "Already installed: $app_name"
                return 0
            fi

            run mas install "$app_id" || return 1
            INSTALLED_MAS_IDS+=("$app_id")
            ;;

        go)
            local package="$primary_field"
            local binary="${package##*/}"
            log_info "[$index/$total] go $package"

            if ! command -v go &>/dev/null; then
                log_warn "go is not installed yet, skipping: $package"
                return 1
            fi

            if command -v "$binary" &>/dev/null; then
                log_success "Already installed: $binary"
                return 0
            fi

            run go install "$package@latest" || return 1
            ;;
    esac

    log_success "Installed: $primary_field"
    return 0
}

install_from_brewfile() {
    local line
    local current=0
    local total

    total=$(brewfile_entry_total)
    log_info "Installing Brewfile entries with progress ($total items)..."

    while IFS= read -r line; do
        if ! should_process_brewfile_line "$line"; then
            continue
        fi

        ((current++))
        if ! brewfile_install_entry "$current" "$total" "$line"; then
            log_warn "Continuing after failed Brewfile entry: $line"
            ERRORS+=("Brewfile entry failed: $line")
        fi
    done < "$DOTFILES_DIR/Brewfile"
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
    if ! run xcode-select --install; then
        log_warn "Xcode CLI tools installation may require manual intervention in a GUI prompt"
    fi

    if ! xcode-select -p &>/dev/null; then
        log_warn "Xcode CLI tools are still unavailable; rerun the installer after installation completes"
        return 0
    fi

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

    load_brew_state

    # Make sure we're using the latest Homebrew
    log_info "Updating Homebrew..."
    run brew update || log_warn "brew update failed, continuing..."

    if [[ "$BREW_UPGRADE" == "true" ]]; then
        log_info "Upgrading installed packages..."
        run brew upgrade || log_warn "brew upgrade failed, continuing..."
    else
        log_info "Skipping brew upgrade (set BREW_UPGRADE=true to enable)"
    fi

    # Install all dependencies from Brewfile with progress and soft-fail behavior.
    log_info "Installing brew packages and cask apps..."
    if [[ -f "$DOTFILES_DIR/Brewfile" ]]; then
        install_from_brewfile
    else
        log_error "Brewfile not found at $DOTFILES_DIR/Brewfile"
        return 1
    fi

    if [[ "$INSTALL_MAS" != "true" ]]; then
        log_warn "Skipping Mac App Store installs by default. Run INSTALL_MAS=true ./install.sh after signing into the App Store and disabling the purchase-password prompt."
    fi

    # Create sha256sum symlink if coreutils is installed
    local BREW_PREFIX
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
    ensure_symlink "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
    ensure_symlink "$DOTFILES_DIR/zsh/.zsh_plugins.txt" "$HOME/.zsh_plugins.txt"
    ensure_symlink "$DOTFILES_DIR/.bash_profile" "$HOME/.bash_profile"

    return 0
}

config_setup() {
    log_info "Setting up app configurations..."

    # Critical dotfiles (symlinks)
    ensure_symlink "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
    ensure_symlink "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"
    ensure_symlink "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc"
    ensure_symlink "$DOTFILES_DIR/.npmrc" "$HOME/.npmrc"

    # Global ignore (ripgrep, fd, etc.)
    if [[ -f "$DOTFILES_DIR/.ignore" ]]; then
        ensure_symlink "$DOTFILES_DIR/.ignore" "$HOME/.ignore"
    fi

    # SSH config
    run mkdir -p "$HOME/.ssh"
    run chmod 700 "$HOME/.ssh"
    if [[ -f "$DOTFILES_DIR/ssh/config" ]]; then
        ensure_symlink "$DOTFILES_DIR/ssh/config" "$HOME/.ssh/config"
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
    run mkdir -p "$HOME/Library/Application Support/Choosy"

    # Zed
    if [[ -d "$DOTFILES_DIR/config/zed" ]]; then
        ensure_symlink "$DOTFILES_DIR/config/zed/settings.json" "$HOME/.config/zed/settings.json"
        ensure_symlink "$DOTFILES_DIR/config/zed/keymap.json" "$HOME/.config/zed/keymap.json"
        ensure_symlink "$DOTFILES_DIR/config/zed/tasks.json" "$HOME/.config/zed/tasks.json"
    else
        log_warn "Zed config not found, skipping..."
    fi

    # Ghostty
    if [[ -f "$DOTFILES_DIR/config/ghostty/config" ]]; then
        ensure_symlink "$DOTFILES_DIR/config/ghostty/config" "$HOME/.config/ghostty/config"
        ensure_symlink_tree "$DOTFILES_DIR/config/ghostty/shaders" "$HOME/.config/ghostty/shaders"
        ensure_symlink_tree "$DOTFILES_DIR/config/ghostty/themes" "$HOME/.config/ghostty/themes"
    else
        log_warn "Ghostty config not found, skipping..."
    fi

    # Choosy (copy, not symlink — app-managed files)
    if [[ -f "$DOTFILES_DIR/config/choosy/behaviours.plist" ]]; then
        ensure_copy "$DOTFILES_DIR/config/choosy/behaviours.plist" "$HOME/Library/Application Support/Choosy/behaviours.plist"
    fi
    if [[ -f "$DOTFILES_DIR/config/choosy/com.choosyosx.Choosy.plist" ]]; then
        ensure_copy "$DOTFILES_DIR/config/choosy/com.choosyosx.Choosy.plist" "$HOME/Library/Preferences/com.choosyosx.Choosy.plist"
    fi

    # btop
    if [[ -f "$DOTFILES_DIR/config/btop/btop.conf" ]]; then
        ensure_symlink "$DOTFILES_DIR/config/btop/btop.conf" "$HOME/.config/btop/btop.conf"
    else
        log_warn "btop config not found, skipping..."
    fi

    # Git global ignore
    if [[ -f "$DOTFILES_DIR/config/git/ignore" ]]; then
        ensure_symlink "$DOTFILES_DIR/config/git/ignore" "$HOME/.config/git/ignore"
    else
        log_warn "Git global ignore not found, skipping..."
    fi

    # Atuin
    if [[ -f "$DOTFILES_DIR/config/atuin/config.toml" ]]; then
        ensure_symlink "$DOTFILES_DIR/config/atuin/config.toml" "$HOME/.config/atuin/config.toml"
    else
        log_warn "Atuin config not found, skipping..."
    fi

    # Karabiner (copy, not symlink — Karabiner rewrites atomically and breaks symlinks)
    if [[ -f "$DOTFILES_DIR/config/karabiner/karabiner.json" ]]; then
        ensure_copy "$DOTFILES_DIR/config/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"
    else
        log_warn "Karabiner config not found, skipping..."
    fi

    # aichat
    if [[ -f "$DOTFILES_DIR/config/aichat/config.yaml" ]]; then
        ensure_symlink "$DOTFILES_DIR/config/aichat/config.yaml" "$HOME/.config/aichat/config.yaml"
    else
        log_warn "aichat config not found, skipping..."
    fi

    # GitHub CLI
    if [[ -f "$DOTFILES_DIR/config/gh/config.yml" ]]; then
        ensure_symlink "$DOTFILES_DIR/config/gh/config.yml" "$HOME/.config/gh/config.yml"
    else
        log_warn "GitHub CLI config not found, skipping..."
    fi

    # Zellij
    run mkdir -p "$HOME/.config/zellij/layouts"
    if [[ -f "$DOTFILES_DIR/config/zellij/config.kdl" ]]; then
        ensure_symlink "$DOTFILES_DIR/config/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"
        ensure_symlink_tree "$DOTFILES_DIR/config/zellij/layouts" "$HOME/.config/zellij/layouts"
    else
        log_warn "Zellij config not found, skipping..."
    fi

    # Helix
    run mkdir -p "$HOME/.config/helix"
    if [[ -f "$DOTFILES_DIR/config/helix/config.toml" ]]; then
        ensure_symlink "$DOTFILES_DIR/config/helix/config.toml" "$HOME/.config/helix/config.toml"
        ensure_symlink_tree "$DOTFILES_DIR/config/helix/themes" "$HOME/.config/helix/themes"
    else
        log_warn "Helix config not found, skipping..."
    fi

    # Neovim
    run mkdir -p "$HOME/.config/nvim"
    if [[ -d "$DOTFILES_DIR/config/nvim" ]]; then
        ensure_symlink_tree "$DOTFILES_DIR/config/nvim" "$HOME/.config/nvim"
    else
        log_warn "Neovim config not found, skipping..."
    fi

    # Yazi
    run mkdir -p "$HOME/.config/yazi"
    if [[ -d "$DOTFILES_DIR/config/yazi" ]]; then
        ensure_symlink_tree "$DOTFILES_DIR/config/yazi" "$HOME/.config/yazi"
    else
        log_warn "Yazi config not found, skipping..."
    fi

    # Nicotine+
    run mkdir -p "$HOME/.config/nicotine"
    if [[ -f "$DOTFILES_DIR/config/nicotine/config" ]]; then
        ensure_symlink "$DOTFILES_DIR/config/nicotine/config" "$HOME/.config/nicotine/config"
    fi

    # uv receipt
    run mkdir -p "$HOME/.config/uv"
    if [[ -f "$DOTFILES_DIR/config/uv/uv-receipt.json" ]]; then
        ensure_symlink "$DOTFILES_DIR/config/uv/uv-receipt.json" "$HOME/.config/uv/uv-receipt.json"
    fi

    return 0
}

iina_default_player_setup() {
    local iina_app="/Applications/IINA.app"
    local iina_bundle_id="com.colliderli.iina"
    local type_or_ext

    log_info "Setting IINA as default media player..."

    if [[ ! -d "$iina_app" ]]; then
        log_warn "IINA is not installed, skipping default media association"
        return 0
    fi

    if ! command -v duti &>/dev/null; then
        log_warn "duti not found, skipping IINA default media association"
        return 0
    fi

    local -a content_types=(
        "public.movie"
        "public.video"
        "public.audio"
        "public.audiovisual-content"
        "public.mpeg-4"
        "public.mp3"
    )

    local -a extensions=(
        "avi"
        "flac"
        "m4a"
        "m4v"
        "mkv"
        "mov"
        "mp3"
        "mp4"
        "mpeg"
        "mpg"
        "wav"
        "webm"
    )

    for type_or_ext in "${content_types[@]}"; do
        run duti -s "$iina_bundle_id" "$type_or_ext" all || log_warn "Failed to assign IINA for content type: $type_or_ext"
    done

    for type_or_ext in "${extensions[@]}"; do
        run duti -s "$iina_bundle_id" ".$type_or_ext" all || log_warn "Failed to assign IINA for extension: .$type_or_ext"
    done

    return 0
}

choosy_default_browser_setup() {
    local choosy_app="/Applications/Choosy.app"
    local choosy_bundle_id="com.choosyosx.Choosy"
    local type_or_scheme

    log_info "Setting Choosy as default browser..."

    if [[ ! -d "$choosy_app" ]]; then
        log_warn "Choosy is not installed, skipping default browser association"
        return 0
    fi

    if ! command -v duti &>/dev/null; then
        log_warn "duti not found, skipping Choosy default browser association"
        return 0
    fi

    local -a url_schemes=(
        "http"
        "https"
    )

    local -a content_types=(
        "public.html"
        "public.xhtml"
        "public.url"
        "public.url-name"
    )

    local -a extensions=(
        "htm"
        "html"
        "shtml"
        "xhtml"
    )

    for type_or_scheme in "${url_schemes[@]}"; do
        run duti -s "$choosy_bundle_id" "$type_or_scheme" all || log_warn "Failed to assign Choosy for URL scheme: $type_or_scheme"
    done

    for type_or_scheme in "${content_types[@]}"; do
        run duti -s "$choosy_bundle_id" "$type_or_scheme" all || log_warn "Failed to assign Choosy for content type: $type_or_scheme"
    done

    for type_or_scheme in "${extensions[@]}"; do
        run duti -s "$choosy_bundle_id" ".$type_or_scheme" all || log_warn "Failed to assign Choosy for extension: .$type_or_scheme"
    done

    return 0
}

mackup_setup() {
    log_info "Setting up Mackup for app settings backup..."

    if [[ -f "$DOTFILES_DIR/.mackup.cfg" ]]; then
        ensure_symlink "$DOTFILES_DIR/.mackup.cfg" "$HOME/.mackup.cfg"
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
    local code_bin="code"
    if ! command -v "$code_bin" &> /dev/null && [[ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]; then
        code_bin="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    fi

    if command -v "$code_bin" &> /dev/null || [[ -x "$code_bin" ]]; then
        if [[ -f "$DOTFILES_DIR/vscode/extensions.txt" ]]; then
            local ext_count
            ext_count=$(wc -l < "$DOTFILES_DIR/vscode/extensions.txt" | tr -d ' ')
            log_info "Installing $ext_count VS Code extensions (4 parallel)..."
            if $DRY_RUN; then
                echo -e "${YELLOW}[DRY-RUN]${NC} Would install $ext_count extensions"
            else
                xargs -P4 -I{} "$code_bin" --install-extension {} --force 2>/dev/null \
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
    local cursor_bin="cursor"
    if ! command -v "$cursor_bin" &> /dev/null && [[ -x "/Applications/Cursor.app/Contents/Resources/app/bin/cursor" ]]; then
        cursor_bin="/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
    fi

    if command -v "$cursor_bin" &> /dev/null || [[ -x "$cursor_bin" ]]; then
        if [[ -f "$DOTFILES_DIR/cursor/extensions.txt" ]]; then
            local ext_count
            ext_count=$(wc -l < "$DOTFILES_DIR/cursor/extensions.txt" | tr -d ' ')
            log_info "Installing $ext_count Cursor extensions (4 parallel)..."
            if $DRY_RUN; then
                echo -e "${YELLOW}[DRY-RUN]${NC} Would install $ext_count extensions"
            else
                xargs -P4 -I{} "$cursor_bin" --install-extension {} --force 2>/dev/null \
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

    # OpenLogs CLI
    if ! command -v openlogs &> /dev/null; then
        if command -v npm &> /dev/null; then
            log_info "Installing OpenLogs..."
            run npm i -g openlogs || log_warn "OpenLogs installation failed"
        else
            log_warn "npm not found, skipping OpenLogs installation"
        fi
    else
        log_info "OpenLogs already installed"
    fi

    # Agent Browser CLI
    if ! command -v agent-browser &> /dev/null; then
        if command -v npm &> /dev/null; then
            log_info "Installing agent-browser..."
            run npm i -g agent-browser || log_warn "agent-browser installation failed"
        else
            log_warn "npm not found, skipping agent-browser installation"
        fi
    else
        log_info "agent-browser already installed"
    fi

    return 0
}

claude_setup() {
    log_info "Setting up Claude Code configuration..."

    # Create directories
    run mkdir -p "$HOME/.claude/skills"
    run mkdir -p "$HOME/.codex/skills"
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

    # Copy shared agent skills into the canonical machine-wide store
    if [[ -d "$DOTFILES_DIR/agents/skills" ]]; then
        log_info "Copying shared agent skills to ~/.agents/skills/..."
        for skill_dir in "$DOTFILES_DIR/agents/skills"/*/; do
            if [[ -d "$skill_dir" ]]; then
                skill_name=$(basename "$skill_dir")
                log_info "  - $skill_name"
                run rm -rf "$HOME/.agents/skills/$skill_name"
                run cp -R "$skill_dir" "$HOME/.agents/skills/$skill_name"
            fi
        done
    fi

    # Mirror shared agent skills into Claude and Codex.
    log_info "Creating shared skill symlinks in ~/.claude/skills/ and ~/.codex/skills/..."
    for skill_dir in "$HOME/.agents/skills"/*/; do
        if [[ -d "$skill_dir" ]]; then
            skill_name=$(basename "$skill_dir")
            ensure_symlink "$skill_dir" "$HOME/.claude/skills/$skill_name"
            ensure_symlink "$skill_dir" "$HOME/.codex/skills/$skill_name"
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

post_install_validation() {
    if [[ "$INSTALL_VALIDATE" != "true" ]]; then
        log_info "Skipping post-install validation (INSTALL_VALIDATE=false)"
        return 0
    fi

    if [[ ! -f "$DOTFILES_DIR/scripts/validate.sh" ]]; then
        log_warn "Validation script not found, skipping post-install validation"
        return 0
    fi

    log_info "Running post-install validation..."
    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN]${NC} bash $DOTFILES_DIR/scripts/validate.sh"
        return 0
    fi

    bash "$DOTFILES_DIR/scripts/validate.sh" || return 1
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

    preflight_checks || return 1
    setup_sudo_session || log_warn "Could not establish sudo session upfront; privileged steps may require manual intervention"

    # ── Phase 1: System defaults (sequential) ────────────────────
    log_phase "1/6" "System defaults"
    run_setup macos_defaults_setup "macOS preferences" || true

    # ── Phase 2: Prerequisites (sequential) ──────────────────────
    log_phase "2/6" "Prerequisites"
    run_setup xcode_cl_tools "Xcode command line tools" || true
    run_setup brew_setup "Homebrew packages" || true

    # ── Phase 3: Configuration (instant, sequential) ─────────────
    log_phase "3/6" "Configuration"
    run_setup secrets_setup "Decrypt secrets" || true
    run_setup zsh_setup "Shell defaults" || true
    run_setup dotfile_setup "Shell dotfiles" || true
    run_setup config_setup "App configurations" || true

    # ── Phase 4: App setup (parallel) ────────────────────────────
    log_phase "4/6" "App setup (parallel)"
    run_setup_bg vscode_setup "VS Code"
    run_setup_bg cursor_setup "Cursor"
    run_setup_bg ai_tools_setup "AI coding tools"
    run_setup_bg autocommit_setup "Dotfiles auto-backup agent"
    wait_phase

    # ── Phase 5: Final setup (sequential) ────────────────────────
    log_phase "5/6" "Final setup"
    run_setup claude_setup "Claude Code configuration" || true
    run_setup mackup_setup "Mackup app settings backup" || true
    run_setup dock_setup "Dock configuration" || true
    run_setup choosy_default_browser_setup "Choosy default browser association" || true
    run_setup iina_default_player_setup "IINA default media association" || true

    # ── Phase 6: Validation (sequential) ─────────────────────────
    log_phase "6/6" "Validation"
    run_setup post_install_validation "Post-install validation" || true

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

    if [[ -n "$BACKUP_DIR" ]]; then
        echo -e "${DIM}Backups: ${BACKUP_DIR}${NC}"
    fi

    if $DRY_RUN; then
        echo ""
        echo -e "${YELLOW}This was a dry run. No changes were made.${NC}"
        echo "Run without --dry-run to apply changes."
    fi

    echo ""
}

main "$@"
