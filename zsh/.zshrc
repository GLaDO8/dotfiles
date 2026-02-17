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

# History / behavior
setopt inc_append_history share_history hist_ignore_all_dups hist_reduce_blanks
setopt autocd interactivecomments nomatch notify

# Completions (cached)
autoload -Uz compinit
zcompdump=${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump
mkdir -p "${zcompdump:h}"

# Additional fpath for zsh-completions and Homebrew completions
fpath=(/opt/homebrew/share/zsh/site-functions $fpath)

# Docker CLI completions (load only when Docker is present)
if command -v docker >/dev/null 2>&1; then
  fpath=("$HOME/.docker/completions" $fpath)
fi

compinit -C -d "$zcompdump"

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
  antidote load ~/.zsh_plugins.txt
fi

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

# fzf (fuzzy finder foundation) - powers Ctrl+T, Alt+C, and fzf-tab
# Ctrl+T: fuzzy file finder, Alt+C: fuzzy cd, Ctrl+R: handled by mcfly
source <(fzf --zsh)

# aichat - use directly: `aichat "question"` or `aichat -e "natural language command"`
# Note: Shell integration (Alt+E) not available in v0.30.0

# ═══════════════════════════════════════════════════════════════════════════════
# fzf-tab Configuration (ayu-dark themed)
# ═══════════════════════════════════════════════════════════════════════════════

# Color scheme matching your ayu-dark Ghostty theme
zstyle ':fzf-tab:*' fzf-flags --color=bg+:#1b3a5b,bg:#0b0e14,spinner:#ff8f40,hl:#ffb454 \
  --color=fg:#bfbdb6,header:#ffb454,info:#e6b450,pointer:#ff8f40 \
  --color=marker:#ff8f40,fg+:#bfbdb6,prompt:#e6b450,hl+:#ffb454

# Preview file contents when completing files
zstyle ':fzf-tab:complete:*:*' fzf-preview 'less ${(Q)realpath}'

# Preview directory contents when completing cd
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'

# Preview git diffs for git commands
zstyle ':fzf-tab:complete:git-(add|diff|restore):*' fzf-preview \
  'git diff $word | delta 2>/dev/null || git diff $word'

# Switch between completion groups with < and >
zstyle ':fzf-tab:*' switch-group '<' '>'

# Show completion group headers
zstyle ':fzf-tab:*' show-group full

# ═══════════════════════════════════════════════════════════════════════════════
# Enhanced Completion Settings
# ═══════════════════════════════════════════════════════════════════════════════

# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Menu selection with arrow keys
zstyle ':completion:*' menu select

# Descriptions for completions
zstyle ':completion:*:descriptions' format '[%d]'

# Group completions by category
zstyle ':completion:*' group-name ''

# Colors for completion listings (files, dirs, etc.)
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

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

# Midscene iOS Automation (vision model for UI grounding)
export MIDSCENE_MODEL_NAME="qwen/qwen3-vl-235b-a22b-instruct"
export MIDSCENE_MODEL_API_KEY="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"
export MIDSCENE_MODEL_BASE_URL="https://openrouter.ai/api/v1"
export MIDSCENE_MODEL_FAMILY="qwen3-vl"

