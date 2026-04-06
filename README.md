# dotfiles

Curated dotfiles for end-to-end macOS machine setup.

## First-run bootstrap

Use this on a brand-new Mac before cloning the repo if you need `1Password`, `1Password CLI`, `Chrome`, and `Dia` first:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/GLaDO8/dotfiles/main/bootstrap.sh)"
```

That gives you the minimum needed to sign into GitHub, restore passwords, and use VIA in a Chromium browser.

## Full restore

After cloning:

```bash
./install.sh
```

Notes:

- `install.sh` applies macOS defaults first, then restores Homebrew packages with per-item progress.
- Brewfile installs are soft-fail. If one formula or cask breaks, the rest continue.
- Mac App Store installs are skipped by default. Run `INSTALL_MAS=true ./install.sh` later if you want them.

## Brewfile

The `Brewfile` is the inventory of formulas, casks, MAS apps, and Go tools for this machine.
