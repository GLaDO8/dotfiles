#!/usr/bin/env bash
echo "Setting up your Mac..."

finish() {
	echo "Done!"
}

brew_setup(){
	# Check for Homebrew and install if we don't have it
	if test ! $(which brew); then
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	fi

	# Make sure we're using the latest Homebrew.
	brew update

	# Upgrade any already-installed formulae.
	brew upgrade

	# Install all our dependencies with bundle (See Brewfile)
	echo "Installing brew packages and brew cask apps..."
	brew bundle install --file=$HOME/dotfiles/Brewfile

	# Save Homebrew's installed location.
	BREW_PREFIX=$(brew --prefix)

	# Don't forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
	ln -sf "${BREW_PREFIX}/bin/gsha256sum" "${BREW_PREFIX}/bin/sha256sum" 2>/dev/null

	finish
}

zsh_setup(){
	#install oh-my-zsh
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

	# Make ZSH the default shell environment (zsh comes preinstalled on macOS)
	echo "Making zsh as the default shell environment..."
	chsh -s $(which zsh)

	#install powerline font
	git clone https://github.com/powerline/fonts.git --depth=1
	cd fonts
	./install.sh
	cd ..
	rm -rf fonts

	#install zsh themes
	echo "setting spaceship prompt as default..."
	git clone https://github.com/spaceship-prompt/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt" --depth=1
	ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"

	#install zsh plugins
	echo "installing zsh-syntax-highlighting package..."
	git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

	echo "installing zsh-auto-suggestions package..."
	git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

	echo "installing zsh-completions package"
	git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:=~/.oh-my-zsh/custom}/plugins/zsh-completions

	finish
}

dotfile_setup(){
	echo "Setting up shell dotfiles..."

	# Create symlinks for shell dotfiles in home directory
	echo "Creating symlinks for shell dotfiles..."
	rm -rf $HOME/.zshrc
	ln -sfv $HOME/dotfiles/zsh/.zshrc $HOME/.zshrc
	ln -sfv $HOME/dotfiles/.aliases $HOME/.aliases
	ln -sfv $HOME/dotfiles/.functions $HOME/.functions
	ln -sfv $HOME/dotfiles/.bash_profile $HOME/.bash_profile

	finish
}

config_setup(){
	echo "Setting up app configurations..."

	# Critical dotfiles (symlinks)
	ln -sfv $HOME/dotfiles/.gitconfig $HOME/.gitconfig
	ln -sfv $HOME/dotfiles/.tmux.conf $HOME/.tmux.conf
	ln -sfv $HOME/dotfiles/.bashrc $HOME/.bashrc
	ln -sfv $HOME/dotfiles/.npmrc $HOME/.npmrc

	# SSH config
	mkdir -p $HOME/.ssh
	chmod 700 $HOME/.ssh
	ln -sfv $HOME/dotfiles/ssh/config $HOME/.ssh/config

	# App configs (~/.config/)
	mkdir -p $HOME/.config/zed
	mkdir -p $HOME/.config/ghostty
	mkdir -p $HOME/.config/aichat
	mkdir -p $HOME/.config/gh

	ln -sfv $HOME/dotfiles/config/zed/settings.json $HOME/.config/zed/settings.json
	ln -sfv $HOME/dotfiles/config/zed/keymap.json $HOME/.config/zed/keymap.json
	ln -sfv $HOME/dotfiles/config/zed/tasks.json $HOME/.config/zed/tasks.json
	ln -sfv $HOME/dotfiles/config/ghostty/config $HOME/.config/ghostty/config
	ln -sfv $HOME/dotfiles/config/aichat/config.yaml $HOME/.config/aichat/config.yaml
	ln -sfv $HOME/dotfiles/config/gh/config.yml $HOME/.config/gh/config.yml

	finish
}

vscode_setup(){
	echo "Setting up VS Code..."

	# Settings
	VSCODE_USER="$HOME/Library/Application Support/Code/User"
	mkdir -p "$VSCODE_USER"
	ln -sfv $HOME/dotfiles/vscode/settings.json "$VSCODE_USER/settings.json"

	# Extensions
	if command -v code &> /dev/null; then
		echo "Installing VS Code extensions..."
		xargs -I {} code --install-extension {} < $HOME/dotfiles/vscode/extensions.txt
	else
		echo "VS Code CLI not found. Install extensions manually after installing VS Code."
	fi

	finish
}

ai_tools_setup(){
	echo "Installing AI coding tools..."

	# Claude Code (native installation - recommended over npm)
	if ! command -v claude &> /dev/null; then
		echo "Installing Claude Code..."
		curl -fsSL https://claude.ai/install.sh | bash
	else
		echo "Claude Code already installed, skipping..."
	fi

	# OpenAI Codex CLI
	if ! command -v codex &> /dev/null; then
		echo "Installing OpenAI Codex..."
		npm i -g @openai/codex
	else
		echo "OpenAI Codex already installed, skipping..."
	fi

	finish
}

claude_setup(){
	echo "Setting up Claude Code configuration..."

	# Create directories
	mkdir -p $HOME/.claude/skills
	mkdir -p $HOME/.agents/skills

	# Remove existing files/symlinks (clean slate)
	rm -f $HOME/.claude/CLAUDE.md
	rm -f $HOME/.claude/settings.json
	rm -f $HOME/.claude/statusline-command.sh

	# Copy config files from backup (actual files, not symlinks)
	echo "Copying Claude config files..."
	if [ -d "$HOME/dotfiles/claude/backup" ]; then
		cp $HOME/dotfiles/claude/backup/CLAUDE.md $HOME/.claude/ 2>/dev/null
		cp $HOME/dotfiles/claude/backup/settings.json $HOME/.claude/ 2>/dev/null
		cp $HOME/dotfiles/claude/backup/statusline-command.sh $HOME/.claude/ 2>/dev/null
		chmod +x $HOME/.claude/statusline-command.sh 2>/dev/null
	fi

	# Copy personal skills
	echo "Copying personal skills to ~/.claude/skills/..."
	if [ -d "$HOME/dotfiles/claude/backup/skills" ]; then
		for skill_dir in $HOME/dotfiles/claude/backup/skills/*/; do
			if [ -d "$skill_dir" ]; then
				skill_name=$(basename "$skill_dir")
				echo "  - $skill_name"
				rm -rf "$HOME/.claude/skills/$skill_name"
				cp -R "$skill_dir" "$HOME/.claude/skills/$skill_name"
			fi
		done
	fi

	# Copy community skills
	echo "Copying community skills to ~/.agents/skills/..."
	if [ -d "$HOME/dotfiles/claude/backup/agents-skills" ]; then
		for skill_dir in $HOME/dotfiles/claude/backup/agents-skills/*/; do
			if [ -d "$skill_dir" ]; then
				skill_name=$(basename "$skill_dir")
				echo "  - $skill_name"
				rm -rf "$HOME/.agents/skills/$skill_name"
				cp -R "$skill_dir" "$HOME/.agents/skills/$skill_name"
			fi
		done
	fi

	# Create symlinks in ~/.claude/skills/ for community skills
	echo "Creating community skill symlinks in ~/.claude/skills/..."
	for skill_dir in $HOME/.agents/skills/*/; do
		if [ -d "$skill_dir" ]; then
			skill_name=$(basename "$skill_dir")
			if [ ! -e "$HOME/.claude/skills/$skill_name" ]; then
				ln -sv "../../.agents/skills/$skill_name" "$HOME/.claude/skills/$skill_name"
			fi
		fi
	done

	# Create settings.local.json template if it doesn't exist
	if [ ! -f "$HOME/.claude/settings.local.json" ]; then
		echo "Creating settings.local.json template for secrets..."
		cat > "$HOME/.claude/settings.local.json" << 'EOF'
{
  "env": {
    "VERCEL_TOKEN": "<YOUR_VERCEL_TOKEN>"
  }
}
EOF
	fi

	echo "Claude Code setup complete!"
	finish
}

xcode_cl_tools(){
	echo "Installing xcode command line tools..."

	# Check for installation
	if xcode-select -p &>/dev/null; then
		echo "Xcode command line tools already installed. Skipping..."
		finish
		return
	fi

	echo "Do you want to install command line tools? (y/N) (recommended)"
	read answer
	if [[ "${answer}" == 'y' || "${answer}" == 'Y' ]]; then
		xcode-select --install
	fi

	finish
}

macos_defaults_setup(){
	# Set macOS preferences
	# We will run this last because this will reload the shell
	echo "Setting macOS preferences..."
	source $HOME/dotfiles/.macos
	echo "Preferences set!"

	finish
}

# Main execution order (apps first, then configs)
brew_setup           # 1. Install all Homebrew packages/casks
# zsh_setup          # 2. Oh-my-zsh (optional, uncomment if needed)
dotfile_setup        # 3. Shell configs
config_setup         # 4. App configs (after apps installed)
vscode_setup         # 5. VS Code (after VS Code installed)
ai_tools_setup       # 6. Claude Code + OpenAI Codex (native install)
claude_setup         # 7. Claude Code configs
xcode_cl_tools       # 8. Xcode CLI
# macos_defaults_setup # 9. macOS prefs (optional, reloads shell)
