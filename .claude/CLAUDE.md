# Dotfiles Repository

Personal macOS dotfiles managed with symlinks (restore) and file copies (backup).

## Directory Structure

- `zsh/` — Zsh shell configuration
- `config/` — `~/.config/` app configs (zed, ghostty, aichat, gh, zellij, helix, nvim, yazi)
- `claude/` — Claude Code configuration backup (CLAUDE.md, settings.json, hooks, skills, plugins)
- `vscode/` — VS Code settings and extensions
- `cursor/` — Cursor settings, keybindings, and extensions
- `scripts/` — Maintenance scripts
  - `backup.sh` — Interactive backup with discovery (gum-powered)
  - `dotfiles-autocommit.sh` — Launchd daemon for auto-commit/push
  - `validate.sh` — Symlink integrity checker
  - `lib/` — Shared libraries (common.sh, symlinks.sh, gum.sh, backup-*.sh)
- `dock/` — Dock app configuration
- `ssh/` — SSH config (no keys!)
- `Brewfile` — Homebrew packages, casks, and Mac App Store apps

## Key Scripts

| Script | Purpose |
|--------|---------|
| `install.sh` | Full system restore — symlinks configs, installs brew packages, sets up apps |
| `scripts/backup.sh` | Interactive backup — syncs configs, discovers new packages/apps/configs |
| `scripts/backup.sh --quick` | Non-interactive config sync + commit |
| `scripts/dotfiles-autocommit.sh` | Launchd daemon — auto-commits and pushes changes |
| `scripts/validate.sh` | Validates all symlinks point to correct targets |
| `claude/backup.sh` | Claude Code config backup (also runs on SessionEnd hook) |

## Config Management Pattern

- **Restore (install.sh):** Creates symlinks from system locations → dotfiles
- **Backup (scripts/backup.sh):** Copies files from system locations → dotfiles
- **Auto-commit:** Launchd daemon periodically commits and pushes changes

## Path Reference

See `locations.md` for a complete mapping of all config files and their system/dotfiles paths.

## Conventions

- All symlink targets are defined in `scripts/lib/symlinks.sh` (EXPECTED_SYMLINKS array)
- Config directories mirror `~/.config/` structure under `config/`
- Claude configs are copied (not symlinked) because `~/.claude/` doesn't support external symlinks well
- The Brewfile is the source of truth for packages — `brew bundle` handles install, `scripts/backup.sh` handles discovery

## Do NOT

- Commit secrets, `.env` files, API keys, or tokens
- Store SSH private keys (only `ssh/config` is tracked)
- Modify `settings.local.json` in the repo (it's machine-specific)
