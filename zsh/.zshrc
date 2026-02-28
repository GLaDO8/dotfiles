export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

export BUN_INSTALL="$HOME/.bun"
export GOPATH="$HOME/go"
export GOROOT="/opt/homebrew/opt/go/libexec"

typeset -U path PATH
path=(
  "$HOME/.cargo/bin"
  "$HOME/.local/bin"
  "$HOME/.npm-global/bin"
  "$HOME/.cache/lm-studio/bin"
  "$BUN_INSTALL/bin"
  "$GOPATH/bin"
  "$GOROOT/bin"
  "/opt/homebrew/bin"
  "/usr/local/bin"
  "/usr/bin"
  "/bin"
  "/usr/sbin"
  "/sbin"
)
export PATH

# Unlock macOS Keychain for SSH sessions (needed for Claude Code)
claude() {
    if [ -n "$SSH_CONNECTION" ] && [ -z "$KEYCHAIN_UNLOCKED" ]; then
        security unlock-keychain ~/Library/Keychains/login.keychain-db
        export KEYCHAIN_UNLOCKED=true
    fi
    command claude "$@"
}

# LS_COLORS for completion menu coloring (macOS doesn't set this by default)
export LS_COLORS='di=1;34:ln=36:so=35:pi=33:ex=1;32:bd=1;33:cd=1;33:su=1;31:sg=1;31:tw=34;42:ow=34;43:*.tar=31:*.gz=31:*.zip=31:*.zst=31:*.jpg=35:*.png=35:*.svg=35:*.mp4=35:*.mp3=35:*.md=33:*.json=33:*.yml=33:*.yaml=33:*.toml=33:*.conf=33:*.js=32:*.ts=32:*.tsx=32:*.jsx=32:*.py=32:*.rb=32:*.rs=32:*.go=32:*.sh=32:*.zsh=32:*.swift=32'

# History / behavior
setopt inc_append_history share_history hist_ignore_all_dups hist_reduce_blanks
setopt autocd interactivecomments nomatch notify

# Additional fpath for Homebrew completions
fpath=(/opt/homebrew/share/zsh/site-functions $fpath)

# Docker CLI completions (load only when Docker is present)
if command -v docker >/dev/null 2>&1; then
  fpath=("$HOME/.docker/completions" $fpath)
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Autocomplete: live-filtered completion menu as you type
# ═══════════════════════════════════════════════════════════════════════════════

# Start showing completions after 1 character (0 = immediately, too noisy)
zstyle ':autocomplete:*' min-input 1

# 100ms delay to avoid lag on fast typing
zstyle ':autocomplete:*' delay 0.1

# Cap completion wait time (prevents hangs on slow completers like package managers)
zstyle ':autocomplete:*' timeout 1.0

# Show 8 lines in the dropdown (tune to taste)
zstyle ':autocomplete:*:*' list-lines 16

# Auto-insert the unambiguous common prefix before showing menu
zstyle ':autocomplete:*complete*:*' insert-unambiguous yes

# Pass cache flag to compinit for speed
zstyle '*:compinit' arguments -C

# bun completions
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"

# Minimal custom prompt: time | directory | git branch
autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:git:*' formats '%b'
setopt PROMPT_SUBST
PROMPT='%B%F{yellow}%T%f %F{cyan}%~%f %F{magenta}${vcs_info_msg_0_}%f %F{white}$%f%b '

# Antidote plugins (fast loader)
if [[ -f /opt/homebrew/share/antidote/antidote.zsh ]]; then
  source /opt/homebrew/share/antidote/antidote.zsh
  antidote load ~/.zsh_plugins.txt 2> >(command grep -v 'unhandled ZLE widget' >&2)
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Keybinding overrides (must be after plugin load)
# ═══════════════════════════════════════════════════════════════════════════════

# List completions in columns (top-to-bottom) instead of rows (left-to-right)
setopt nolistrowsfirst

# Tab: insert top completion / cycle through menu
bindkey '\t' menu-select
bindkey "$terminfo[kcbt]" menu-select  # Shift+Tab: reverse cycle

# Enter in menu: accept and run (don't just exit menu)
bindkey -M menuselect '\r' .accept-line

# Autosuggestions: use completion + history strategy (ghost text for file paths too)
ZSH_AUTOSUGGEST_STRATEGY=(match_prev_cmd completion history)

# Prevent autosuggestions from being slow on long buffers
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# ═══════════════════════════════════════════════════════════════════════════════
# SUPERCHARGED ZSH: Tool Initializations
# ═══════════════════════════════════════════════════════════════════════════════

# Zoxide (smarter cd) - 10x faster than autojump, learns your cd patterns
# Usage: z <partial-path> (e.g., "z intel" → ~/Documents/python-intel)
eval "$(zoxide init zsh)"

# mcfly (neural network history search) - context-aware, learns per-directory patterns
# Replaces Ctrl+R with AI-powered history search
export MCFLY_KEY_SCHEME=vim  # Use vim keybindings in mcfly interface
export MCFLY_FUZZY=2         # Enable fuzzy search (2 = moderate fuzzy matching)
export MCFLY_RESULTS=50      # Show more results
export MCFLY_INTERFACE_VIEW=BOTTOM  # Show at bottom of screen
eval "$(mcfly init zsh)"

# Direnv (auto .env loading) - automatically loads .envrc files
# Run `direnv allow` once per directory to authorize
eval "$(direnv hook zsh)"

# fzf (fuzzy finder foundation) - powers Ctrl+T and Alt+C
# Ctrl+T: fuzzy file finder, Alt+C: fuzzy cd, Ctrl+R: handled by mcfly
source <(fzf --zsh)

# aichat - use directly: `aichat "question"` or `aichat -e "natural language command"`
# Note: Shell integration (Alt+E) not available in v0.30.0

# ═══════════════════════════════════════════════════════════════════════════════
# Enhanced Completion Settings
# ═══════════════════════════════════════════════════════════════════════════════

# Case-insensitive + prefix matching (works well with autocomplete's insert-unambiguous)
zstyle ':completion:*:*' matcher-list 'm:{[:lower:]-}={[:upper:]_}' '+r:|[.]=**'

# Descriptions for completions
zstyle ':completion:*:descriptions' format '[%d]'

# Group completions by category
zstyle ':completion:*' group-name ''

# Colors for completion listings (files, dirs, etc.)
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Don't pack columns tightly — gives more breathing room
zstyle ':completion:*' list-packed no

# ═══════════════════════════════════════════════════════════════════════════════
# Custom AI Helper Function (leverages Claude CLI)
# ═══════════════════════════════════════════════════════════════════════════════

# AI command help - press Ctrl+G to get AI explanations
# - With text in buffer: explains the command and suggests improvements
# - With empty buffer: prompts you to describe what you want
function _ai_help() {
  local cmd="$BUFFER"
  if [[ -n "$cmd" ]]; then
    echo ""
    echo "───────────────────────────────────────────────────"
    claude --print "Explain this shell command concisely and suggest any improvements: $cmd"
    echo "───────────────────────────────────────────────────"
  else
    echo ""
    echo "───────────────────────────────────────────────────"
    echo "💡 Type a command first, then press Ctrl+G for AI help"
    echo "   Or use Alt+E for AI-powered completions (aichat)"
    echo "───────────────────────────────────────────────────"
  fi
  zle reset-prompt
}
zle -N _ai_help
bindkey '^G' _ai_help

# ═══════════════════════════════════════════════════════════════════════════════
# Word Navigation Keybindings
# ═══════════════════════════════════════════════════════════════════════════════

# Alt+Arrow for word-by-word movement
bindkey "^[[1;3D" backward-word   # Alt+Left  - jump back one word
bindkey "^[[1;3C" forward-word    # Alt+Right - jump forward one word

# Also support Option key on macOS (sends different escape sequence)
bindkey "^[b" backward-word       # Option+Left  (alternate)
bindkey "^[f" forward-word        # Option+Right (alternate)

# Ctrl+Arrow as additional option (common in many editors)
bindkey "^[[1;5D" backward-word   # Ctrl+Left
bindkey "^[[1;5C" forward-word    # Ctrl+Right

# Shift+Arrow - let Ghostty handle these for text selection
# (Removed zsh bindings so Ghostty's adjust_selection works)

# ═══════════════════════════════════════════════════════════════════════════════
# Aliases
# ═══════════════════════════════════════════════════════════════════════════════

alias obsidian='cd ~/Library/Mobile\ Documents/iCloud~md~obsidian/Documents && claude'
alias gs="git status"
alias gcm="git commit -m"
alias ga="git add"
gacp() { git add . && git commit -m "$1" && git push; }
gac()  { git add . && git commit -m "$1"; }
[ -f "$HOME/.aliases" ] && source "$HOME/.aliases"
[ -f "$HOME/.functions" ] && source "$HOME/.functions"

# Added by LM Studio CLI (lms)
alias claude-usage="$HOME/.claude/usage-monitor.sh"
alias cw="zellij --layout claude"

# Google Cloud SDK (optional)
if command -v gcloud >/dev/null 2>&1; then
  [ -f "$HOME/GCP/google-cloud-sdk/path.zsh.inc" ] && . "$HOME/GCP/google-cloud-sdk/path.zsh.inc"
  [ -f "$HOME/GCP/google-cloud-sdk/completion.zsh.inc" ] && . "$HOME/GCP/google-cloud-sdk/completion.zsh.inc"
fi

# pnpm
export PNPM_HOME="/Users/shreyasgupta/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/shreyasgupta/.cache/lm-studio/bin"
# End of LM Studio CLI section

# eza aliases - comprehensive ls replacement
# Basic listings (match traditional ls behavior)
alias ls='eza --group-directories-first'                    # Simple ls
alias l='eza --group-directories-first'                     # Quick shorthand
alias l1='eza -1 --group-directories-first'                 # One per line

# Long format listings
alias ll='eza --long --header --group --git'                # Long with git status
alias la='eza --long --header --group --git --all'          # Long + hidden files
alias lla='eza --long --header --group --git --all'         # Explicit long + all

# Sorting variants
alias lt='eza --long --header --group --git --sort=modified'       # By time
alias ltr='eza --long --header --group --git --sort=modified -r'   # Newest last
alias lS='eza --long --header --group --git --sort=size'           # By size

# Tree views
alias tree='eza --tree --level=2 --group-directories-first'
alias ltree='eza --tree --level=2 --long --header --group --git --icons'
alias ltreea='eza --tree --level=2 --long --header --group --git --icons --all'

# opencode
export PATH=/Users/shreyasgupta/.opencode/bin:$PATH

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/shreyasgupta/.lmstudio/bin"
# End of LM Studio CLI section

# Secrets (API keys, tokens) — loaded from ~/.secrets (gitignored)
[ -f "$HOME/.secrets" ] && source "$HOME/.secrets"

