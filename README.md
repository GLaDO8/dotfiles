# dotfiles

Curated dotfiles for end-to-end macOS machine setup.

## First-run bootstrap

Use this on a brand-new Mac before a full restore if you need `1Password`, `1Password CLI`, `Chrome`, and `Dia` first:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/GLaDO8/dotfiles/main/bootstrap.sh)"
```

Bootstrap now also installs `git` and `gh`, persists Homebrew shellenv in `~/.zprofile`, and clones the dotfiles repo to `~/dotfiles` by default. Set `RUN_DOTFILES_INSTALL=true` if you want bootstrap to immediately launch the full installer after cloning.

## Full restore

After cloning:

```bash
./install.sh
```

Notes:

- `install.sh` runs macOS-only preflight checks, applies defaults first, then restores Homebrew packages with per-item progress.
- Brewfile installs are soft-fail. If one formula or cask breaks, the rest continue.
- Existing files that would be replaced are backed up under `~/.dotfiles-backup/`.
- Mac App Store installs are skipped by default. Run `INSTALL_MAS=true ./install.sh` later if you want them.
- `brew upgrade` is skipped by default for speed. Set `BREW_UPGRADE=true` if you want it.
- The installer finishes with `scripts/validate.sh` unless you set `INSTALL_VALIDATE=false`.

## Brewfile

The `Brewfile` is the inventory of formulas, casks, MAS apps, and Go tools for this machine.
