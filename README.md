# dotfiles

Curated dotfiles for end-to-end macOS machine setup.

This repo is split into two layers:

- `bootstrap.sh` gets a brand-new Mac into a usable state so the repo can be cloned and restored.
- `install.sh` does the full machine restore from the checked-out repo.

## What This Repo Manages

This repo currently manages:

- Homebrew taps, formulae, casks, Mac App Store apps, and Go-installed tools through [Brewfile](/Users/shreyasgupta/local-documents/dotfiles/Brewfile)
- Shell dotfiles like `.zshrc`, `.zsh_plugins.txt`, `.bash_profile`, `.bashrc`
- Git, SSH, tmux, npm, ignore, and Mackup config
- App config under `config/` for tools like Zed, Ghostty, Helix, Neovim, Yazi, Zellij, aichat, GitHub CLI, Atuin, Karabiner, Nicotine+, `uv`, and Choosy
- VS Code and Cursor settings plus extension lists
- Claude Code config, hooks, shared agent skills, and agent docs
- Dock layout and macOS defaults
- Backed-up macOS preference domains for Dock/Desktop, trackpad, key repeat, and keyboard shortcuts
- Optional secrets restore from `secrets/secrets.yaml` through `sops`
- Validation and backup workflows for keeping the repo in sync with the machine

## New Mac Setup

### Fastest path

Run bootstrap directly from GitHub:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/GLaDO8/dotfiles/main/bootstrap.sh)"
```

That script will:

- install Homebrew if needed
- persist Homebrew shell setup in `~/.zprofile`
- install `git` and `gh`
- install `1password`, `1password-cli`, `google-chrome`, and `thebrowsercompany-dia`
- clone this repo to `~/dotfiles` by default

Then run the full restore:

```bash
cd ~/dotfiles
./install.sh
```

### One-command bootstrap + full restore

If you want bootstrap to immediately hand off to the full installer:

```bash
RUN_DOTFILES_INSTALL=true /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/GLaDO8/dotfiles/main/bootstrap.sh)"
```

### If the repo is already cloned

```bash
cd ~/dotfiles
./install.sh
```

### Dry-run the installer first

```bash
cd ~/dotfiles
./install.sh --dry-run
```

## Installer Behavior

[install.sh](/Users/shreyasgupta/local-documents/dotfiles/install.sh) is the main restore script. It is organized into phases:

1. System defaults
2. Prerequisites
3. Configuration
4. App setup
5. Final setup
6. Validation

Important behavior:

- Runs macOS-only preflight checks before mutating anything
- Starts a sudo keepalive session up front when possible
- Restores Brewfile entries with per-item progress
- Soft-fails Brewfile installs so one bad package does not stop the entire restore
- Caches installed Homebrew and MAS state to avoid repeated `brew list` and `mas list` calls
- Backs up replaced regular files into `~/.dotfiles-backup/`
- Runs some independent setup tasks in parallel
  These currently include VS Code, Cursor, AI tools, and the autocommit agent
- Can set Choosy as the default browser when `duti` is available
- Can set IINA as the default handler for common media file types when `duti` is available
- Finishes with [scripts/validate.sh](/Users/shreyasgupta/local-documents/dotfiles/scripts/validate.sh) unless disabled

Environment toggles:

- `INSTALL_MAS=true` to include Mac App Store installs from the Brewfile
- `BREW_UPGRADE=true` to run `brew upgrade` before restore
- `INSTALL_VALIDATE=false` to skip the validation pass
- `DOTFILES_DIR=/some/path` to point the installer at a non-default checkout
- `BACKUP_ROOT=/some/path` to change where replaced files are backed up

Example:

```bash
INSTALL_MAS=true BREW_UPGRADE=true ./install.sh
```

## What Each Script Does

### Top-level scripts

- [bootstrap.sh](/Users/shreyasgupta/local-documents/dotfiles/bootstrap.sh)
  Minimal first-run bootstrap for a new Mac. Installs a small base toolchain, persists Homebrew shellenv, clones the repo, and can optionally run the full installer.

- [install.sh](/Users/shreyasgupta/local-documents/dotfiles/install.sh)
  Full restore script. Installs packages, links configs, restores app/editor setup, configures Claude, Dock, defaults, and runs validation.

- [scripts/validate.sh](/Users/shreyasgupta/local-documents/dotfiles/scripts/validate.sh)
  Validation pass for symlinks, Homebrew, shell setup, and Git/SSH/GPG. Supports JSON output and targeted checks.

- [scripts/backup.sh](/Users/shreyasgupta/local-documents/dotfiles/scripts/backup.sh)
  Reverse-sync tool. Copies tracked config back into the repo, discovers untracked packages and configs, and can help update the Brewfile.

- [scripts/install-autocommit.sh](/Users/shreyasgupta/local-documents/dotfiles/scripts/install-autocommit.sh)
  Installs or uninstalls the launchd agent for automated dotfiles backup commits.

- [scripts/dotfiles-autocommit.sh](/Users/shreyasgupta/local-documents/dotfiles/scripts/dotfiles-autocommit.sh)
  Background autocommit daemon. Detects changes in `~/dotfiles`, commits with `--no-gpg-sign`, and pushes to `origin/master`.

- [scripts/dotfiles-ssh.sh](/Users/shreyasgupta/local-documents/dotfiles/scripts/dotfiles-ssh.sh)
  SSH wrapper used by the autocommit daemon so launchd pushes go through the 1Password SSH agent reliably.

### Library scripts

- `scripts/lib/common.sh`
  Shared logging, JSON output helpers, scan helpers, and file utilities.

- `scripts/lib/brew.sh`
  Homebrew validation logic used by `validate.sh`.

- `scripts/lib/symlinks.sh`
  Symlink validation and repair logic for tracked dotfiles and config trees.

- `scripts/lib/shell.sh`
  Shell-specific validation and repair logic.

- `scripts/lib/git-ssh.sh`
  Validation/fix helpers for Git identity, SSH, and GPG/SSH signing setup.

- `scripts/lib/backup-config.sh`
  Config-sync logic for copying machine state back into the repo.

- `scripts/lib/backup-brew.sh`
  Brewfile sync and discovery helpers for brew, cask, MAS, and Go inventory.

- `scripts/lib/backup-scout.sh`
  Discovery helpers for apps and config that are not yet tracked.

- `scripts/lib/gum.sh`
  Interactive TUI helpers used by the backup workflow.

## Coverage

The current install flow covers:

- Brew taps
- Brew formulae
- Brew casks
- Optional MAS apps
- Optional Go-installed tools from the Brewfile
- Shell dotfiles
- Git, SSH, tmux, npm, ignore, and Mackup config
- App config under `config/`
- Choosy rules and basic Choosy preferences
- Choosy as the default browser for `http`, `https`, and common HTML document types
- VS Code settings plus extension install attempts
- Cursor settings, keybindings, and extension install attempts
- Claude Code config, hooks, shared agent skills, and plugin metadata
- Dock preferences and app list
- IINA as the default handler for common audio/video types
- macOS defaults via `.macos`
- Tracked macOS preference exports under `macos/preferences/`
- Optional secrets decryption via `sops`
- Validation after restore

## What Is Not Covered Yet

The repo does not currently guarantee full restoration of:

- Login flows and app authentication
  You still need to sign into 1Password, GitHub, App Store, Claude, Cursor, etc.

- Hardware-level or System Settings permissions
  Accessibility, Full Disk Access, Input Monitoring, notification permissions, login items, and similar macOS prompts still require manual approval.

- All application state
  Some apps store data in databases, containers, iCloud, or internal app-managed state that is intentionally not mirrored here.

- Full offline bootstrap
  The default path expects network access and GitHub availability.

- End-to-end MAS automation
  MAS installs are skipped by default because they depend on App Store sign-in and purchase settings.

- Universal editor CLI availability
  VS Code and Cursor extension installation is attempted only if the CLI binary is available.

- Full secret material distribution
  Secret decryption depends on your local `age` key existing at `~/.config/sops/age/keys.txt`.

- Every possible config under `~/.config`
  The backup tooling can discover untracked configs, but not everything in `~/.config` is automatically restored unless it is explicitly mapped into the repo.

## Common Commands

Bootstrap a new Mac:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/GLaDO8/dotfiles/main/bootstrap.sh)"
```

Bootstrap and immediately run the full restore:

```bash
RUN_DOTFILES_INSTALL=true /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/GLaDO8/dotfiles/main/bootstrap.sh)"
```

Run a full restore:

```bash
./install.sh
```

Preview the restore:

```bash
./install.sh --dry-run
```

Run validation:

```bash
./scripts/validate.sh
```

Run validation and auto-fix what it can:

```bash
./scripts/validate.sh --fix
```

Back up current machine state into the repo:

```bash
./scripts/backup.sh
```

Scout for new packages/config without syncing:

```bash
./scripts/backup.sh --scout
```

Install the autocommit launchd agent:

```bash
./scripts/install-autocommit.sh
```

Uninstall the autocommit launchd agent:

```bash
./scripts/install-autocommit.sh --uninstall
```

## Repo Layout

- `Brewfile`
  Package inventory for Homebrew, cask, MAS, and Go tools
- `config/`
  App config files restored into `~/.config`
- `zsh/`, `vscode/`, `cursor/`, `ssh/`, `dock/`
  Managed config inputs for the installer
- `claude/`
  Claude Code config, hooks, plugins, and agent docs
- `agents/`
  Shared skills and other reusable agent assets
- `macos/preferences/`
  Exported macOS preference domains restored by the installer

## Shared Skills Layout

Shared cross-agent skills use a three-layer model:

- Dotfiles repo source of truth: `agents/skills/`
- Machine-wide canonical install path: `~/.agents/skills/`
- Agent-specific mirrors:
  `~/.claude/skills/<name>` and `~/.codex/skills/<name>` are symlinks to `~/.agents/skills/<name>`

This keeps one real copy of each shared skill on disk while making the same skill visible to both Claude and Codex. Codex built-ins continue to live alongside this in:

- `~/.codex/skills/.system/` and other Codex-managed paths

Backup behavior with this layout:

- `scripts/backup.sh` syncs the canonical shared skill store from `~/.agents/skills/` back into `agents/skills/`
- The mirrored symlinks in `~/.claude/skills/` and `~/.codex/skills/` are not backed up separately
- `install.sh` restores shared skills to `~/.agents/skills/` first, then recreates the Claude and Codex symlinks
- `scripts/`
  Installer helpers, validation, backup, and automation scripts
- `secrets/`
  Encrypted secrets material for optional restore

## Notes

- This repo is macOS-oriented and the main installer expects Darwin.
- The normal model is `bootstrap.sh` first, then `install.sh`.
- If you want an offline fallback, keep a local clone or external copy of the repo in addition to GitHub.
