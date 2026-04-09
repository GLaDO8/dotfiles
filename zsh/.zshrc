# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  SECRETS                                                                ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
[ -f "$HOME/.secrets" ] && source "$HOME/.secrets"

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  ENVIRONMENT                                                            ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
export BUN_INSTALL="$HOME/.bun"
export GOPATH="$HOME/go"
export GOROOT="/opt/homebrew/opt/go/libexec"
export NVM_DIR="$HOME/.nvm"
export PNPM_HOME="$HOME/Library/pnpm"

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  TELEMETRY - DISABLE ALL                                                ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
# Homebrew
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_GOOGLE_ANALYTICS=1
# General opt-out (used by many tools)
export DO_NOT_TRACK=1
# Deno - disable update check (no telemetry, just update checks)
export DENO_NO_UPDATE_CHECK=1
# .NET CLI
export DOTNET_CLI_TELEMETRY_OPTOUT=1
# AWS SAM CLI
export SAM_CLI_TELEMETRY=0
# Azure CLI
export AZURE_CORE_COLLECT_TELEMETRY=0
# GCloud
export CLOUDSDK_CORE_DISABLE_USAGE_REPORTING=true
# Helm
export HELM_DEBUG=false
# Kubectl Krew
export KREW_DISABLE_GITHUB_API=1
# Volta
export VOLTA_TELEMETRY_DISABLED=1
# OpenAI Codex (uses DO_NOT_TRACK above, but being explicit)
export CODEX_TELEMETRY=false

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  PATH (single declaration, no duplicates)                               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
typeset -U path PATH
path=(
  "$HOME/.cargo/bin"
  "$HOME/.local/bin"
  "$HOME/.npm-global/bin"
  "$HOME/.cache/lm-studio/bin"
  "$HOME/.opencode/bin"
  "$HOME/.atuin/bin"
  "$BUN_INSTALL/bin"
  "$GOPATH/bin"
  "$GOROOT/bin"
  "$PNPM_HOME"
  /opt/homebrew/bin
  /usr/local/bin
  /usr/bin
  /bin
  /usr/sbin
  /sbin
)
export PATH

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  SHELL OPTIONS                                                          ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
setopt inc_append_history share_history hist_ignore_all_dups hist_reduce_blanks
setopt autocd interactivecomments nomatch notify

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  COMPLETIONS                                                            ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
command -v docker >/dev/null 2>&1 && fpath=("$HOME/.docker/completions" $fpath)

export LS_COLORS='di=1;34:ln=36:so=35:pi=33:ex=1;32:bd=1;33:cd=1;33:su=1;31:sg=1;31:tw=34;42:ow=34;43:*.tar=31:*.gz=31:*.zip=31:*.zst=31:*.jpg=35:*.png=35:*.svg=35:*.mp4=35:*.mp3=35:*.md=33:*.json=33:*.yml=33:*.yaml=33:*.toml=33:*.conf=33:*.js=32:*.ts=32:*.tsx=32:*.jsx=32:*.py=32:*.rb=32:*.rs=32:*.go=32:*.sh=32:*.zsh=32:*.swift=32'

# Autocomplete settings (zsh-autocomplete plugin)
zstyle ':autocomplete:*' min-input 1
zstyle ':autocomplete:*' delay 0.1
zstyle ':autocomplete:*' timeout 1.0
zstyle ':autocomplete:*:*' list-lines 16
zstyle ':autocomplete:*complete*:*' insert-unambiguous yes
zstyle '*:compinit' arguments -C

# Matching and display
zstyle ':completion:*:*' matcher-list 'm:{[:lower:]-}={[:upper:]_}' '+r:|[.]=**'
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-packed no

# bun completions
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  PROMPT                                                                 ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:git:*' formats '%b'
setopt PROMPT_SUBST
PROMPT='%B%F{yellow}%T%f %F{cyan}%~%f %F{magenta}${vcs_info_msg_0_}%f %F{white}$%f%b '

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  PLUGINS (antidote)                                                     ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
if [[ -f /opt/homebrew/share/antidote/antidote.zsh ]]; then
  source /opt/homebrew/share/antidote/antidote.zsh
  antidote load ~/.zsh_plugins.txt 2> >(command grep -v 'unhandled ZLE widget' >&2)
fi

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  KEYBINDINGS (after plugin load)                                        ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
setopt nolistrowsfirst

# Tab completion
bindkey '\t' menu-select
bindkey "$terminfo[kcbt]" menu-select
bindkey -M menuselect '\r' .accept-line

# Word navigation
bindkey "^[[1;3D" backward-word     # Alt+Left
bindkey "^[[1;3C" forward-word      # Alt+Right
bindkey "^[b" backward-word         # Option+Left
bindkey "^[f" forward-word          # Option+Right
bindkey "^[[1;5D" backward-word     # Ctrl+Left
bindkey "^[[1;5C" forward-word      # Ctrl+Right

# Autosuggestions config
ZSH_AUTOSUGGEST_STRATEGY=(match_prev_cmd completion history)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  TOOL INITS (cached — run `zsh-refresh-cache` after tool updates)       ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
_zsh_cache="$HOME/.cache/zsh-inits"

_cache_init_script() {
  local cache_file=$1
  shift

  local tmp_file="${cache_file}.tmp"
  "$@" > "$tmp_file" && mv "$tmp_file" "$cache_file"
}

zsh-refresh-cache() {
  echo "Regenerating cached init scripts..."
  mkdir -p "$_zsh_cache"
  _cache_init_script "$_zsh_cache/zoxide.zsh" zoxide init zsh
  _cache_init_script "$_zsh_cache/direnv.zsh" direnv hook zsh
  _cache_init_script "$_zsh_cache/fzf.zsh" fzf --zsh
  _cache_init_script "$_zsh_cache/atuin.zsh" atuin init zsh
  echo "Done. Restart your shell to pick up changes."
}

# Ensure the cache directory exists for manual refreshes.
mkdir -p "$_zsh_cache"

# fzf config (before sourcing its init)
_fzf_fd_excludes=(
  --exclude .git
  --exclude .next
  --exclude .nuxt
  --exclude .output
  --exclude .svelte-kit
  --exclude .turbo
  --exclude .yarn
  --exclude coverage
  --exclude dist
  --exclude build
  --exclude out
  --exclude target
  --exclude node_modules
)

export FZF_DEFAULT_COMMAND="fd --type f --hidden ${_fzf_fd_excludes[*]}"
export FZF_CTRL_T_COMMAND="{ fd --type d --hidden ${_fzf_fd_excludes[*]}; fd --type f --hidden ${_fzf_fd_excludes[*]}; }"
export FZF_ALT_C_COMMAND="fd --type d --hidden ${_fzf_fd_excludes[*]}"

# Source cached inits
for f in "$_zsh_cache"/*.zsh; do
  [[ -s "$f" ]] && source "$f"
done

# Fall back to a live fzf init if the cached file is missing/empty or its widgets
# are unavailable in the current shell.
if (( ! ${+widgets[fzf-file-widget]} || ! ${+widgets[fzf-cd-widget]} )); then
  source <(fzf --zsh)
fi

# fzf rebinds for Zellij (Ctrl+T conflicts with Zellij tab mode)
bindkey -M emacs '^F' fzf-file-widget  # Ctrl+F → fuzzy file path
bindkey -M viins '^F' fzf-file-widget
bindkey -M vicmd '^F' fzf-file-widget
bindkey -M emacs '^E' fzf-cd-widget    # Ctrl+E → fuzzy cd
bindkey -M viins '^E' fzf-cd-widget
bindkey -M vicmd '^E' fzf-cd-widget

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  ALIASES & FUNCTIONS                                                    ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
# Git
alias gs="git status"
alias gcm="git commit -m"
alias ga="git add"
gacp() { git add . && git commit -m "$1" && git push; }
gac()  { git add . && git commit -m "$1"; }

# eza (ls replacement)
alias ls='eza --group-directories-first'
alias l='eza --group-directories-first'
alias l1='eza -1 --group-directories-first'
alias ll='eza --long --header --group --git'
alias la='eza --long --header --group --git --all'
alias lt='eza --long --header --group --git --sort=modified'
alias ltr='eza --long --header --group --git --sort=modified -r'
alias lS='eza --long --header --group --git --sort=size'
alias tree='eza --tree --level=2 --group-directories-first'
alias ltree='eza --tree --level=2 --long --header --group --git --icons'

# Navigation
alias obsidian='cd ~/Library/Mobile\ Documents/iCloud~md~obsidian/Documents'

# Tools
alias claude-usage="$HOME/.claude/usage-monitor.sh"
alias cw="zellij --layout claude"

# External alias/function files
[ -f "$HOME/.aliases" ] && source "$HOME/.aliases"
[ -f "$HOME/.functions" ] && source "$HOME/.functions"

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  AI HELPER (Ctrl+G — explain command in buffer via Claude)              ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
function _ai_help() {
  local cmd="$BUFFER"
  if [[ -n "$cmd" ]]; then
    echo ""
    echo "───────────────────────────────────────────────────"
    claude --print "Explain this shell command concisely and suggest any improvements: $cmd"
    echo "───────────────────────────────────────────────────"
  else
    echo ""
    echo "Type a command first, then press Ctrl+G for AI help"
  fi
  zle reset-prompt
}
zle -N _ai_help
bindkey '^G' _ai_help

# Unlock macOS Keychain for SSH sessions (needed for Claude Code over SSH)
claude() {
  if [ -n "$SSH_CONNECTION" ] && [ -z "$KEYCHAIN_UNLOCKED" ]; then
    security unlock-keychain ~/Library/Keychains/login.keychain-db
    export KEYCHAIN_UNLOCKED=true
  fi
  command claude "$@"
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  LAZY-LOADED TOOLS (deferred until first use)                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
# NVM — loads on first call to nvm/node/npm/npx (~300ms saved per shell)
nvm()  { unset -f nvm node npm npx; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"; [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"; nvm "$@"; }
node() { nvm use default >/dev/null 2>&1; unset -f node; node "$@"; }
npm()  { nvm use default >/dev/null 2>&1; unset -f npm;  npm  "$@"; }
npx()  { nvm use default >/dev/null 2>&1; unset -f npx;  npx  "$@"; }

# Google Cloud SDK — only if installed
if command -v gcloud >/dev/null 2>&1; then
  [ -f "$HOME/GCP/google-cloud-sdk/path.zsh.inc" ] && . "$HOME/GCP/google-cloud-sdk/path.zsh.inc"
  [ -f "$HOME/GCP/google-cloud-sdk/completion.zsh.inc" ] && . "$HOME/GCP/google-cloud-sdk/completion.zsh.inc"
fi

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/shreyasgupta/Downloads/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/shreyasgupta/Downloads/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/shreyasgupta/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/shreyasgupta/Downloads/google-cloud-sdk/completion.zsh.inc'; fi
