#!/usr/bin/env bash
echo "Setting up your Mac..."

brew_setup(){
	# Check for Homebrew and install if we don't have it
	if test ! $(which brew); then
	/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
	fi

	# Make sure we’re using the latest Homebrew.
	brew update

	# Upgrade any already-installed formulae.
	brew upgrade

	#first, specify where you want all your applications to be installed
	cask_args appdir: '/Applications'

	# Install all our dependencies with bundle (See Brewfile)
	echo "Installing brew packages and brew cask apps..."
	brew bundle install

	# Save Homebrew’s installed location.
	BREW_PREFIX=$(brew --prefix)

	# Don’t forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
	ln -s "${BREW_PREFIX}/bin/gsha256sum" "${BREW_PREFIX}/bin/sha256sum"


	finish
}

zsh_setup(){
	#install oh-my-zsh
	sudo -i sh -c "$(wget -O- https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

	# Make ZSH the default shell environment (zsh comes preinstalled on macOS)
	echo "Making zsh as the default shell environment..."
	sudo chsh -s $(which zsh)

	#install powerline font
	git clone https://github.com/powerline/fonts.git --depth=1
	cd fonts
	./install.sh
	cd ..
	rm -rf fonts

	#install zsh themes
	echo "setting spaceship prompt as default..."
	git clone https://github.com/denysdovhan/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt"
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
	echo "setting up personal dotfiles..."
	cd ~
	git clone https://github.com/GLaDOS-root/dotfiles.git

	# create symlinks for dotfiles in home directory
	echo "Creating symlinks for dotfiles..."
	rm -rf $HOME/.zshrc
	ln -sv $HOME/dotfiles/zsh/.zshrc $HOME/.zshrc
	ln -sv $HOME/dotfiles/.aliases $HOME/.aliases
	ln -sv $HOME/dotfiles/.functions $HOME/.functions
	ln -sv $HOME/dotfiles/.bash_profile $HOME/.bash_profile

	finish
}

claude_setup(){
	echo "Setting up Claude Code configuration..."
	mkdir -p $HOME/.claude

	# Remove existing symlinks/files
	rm -f $HOME/.claude/CLAUDE.md
	rm -f $HOME/.claude/settings.json
	rm -f $HOME/.claude/statusline-command.sh
	rm -rf $HOME/.claude/commands  # Deprecated, skills are now in ~/.claude/skills/

	# Create symlinks
	echo "Creating Claude symlinks..."
	ln -sv $HOME/dotfiles/claude/CLAUDE.md $HOME/.claude/CLAUDE.md
	ln -sv $HOME/dotfiles/claude/settings.json $HOME/.claude/settings.json
	ln -sv $HOME/dotfiles/claude/statusline-command.sh $HOME/.claude/statusline-command.sh

	# Personal skills: symlink dotfiles skills to ~/.claude/skills/
	# Note: npx skills will also add community skills here as symlinks
	echo "Setting up personal skills..."
	mkdir -p $HOME/.claude/skills
	for skill_dir in $HOME/dotfiles/claude/skills/*/; do
		skill_name=$(basename "$skill_dir")
		rm -f "$HOME/.claude/skills/$skill_name"
		ln -sv "$skill_dir" "$HOME/.claude/skills/$skill_name"
	done

	chmod +x $HOME/dotfiles/claude/statusline-command.sh

	# Install community skills
	if command -v npx &> /dev/null; then
		echo "Installing community skills..."
		bash $HOME/dotfiles/claude/install-community-skills.sh
	fi

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

	finish
}

xcode_cl_tools(){
	echo "installing xcode command line tools..."

	#check for installation
	if [$(xcode-select -p)]; then
	echo "xcode command line tools already installed. skipping installation..."
	fi

	echo "do you want to install command line tools?(Y/N)(recommended)"
	read answer
	if [${answer} == 'y']; then
	xcode-select install
	fi

	finish
}

macos_defaults_setup(){
	# Set macOS preferences
	# We will run this last because this will reload the shell
	echo "Settings macOS preferences..."
	source .macos
	echo "Preferences set!"

	finish
}
# zsh_setup
brew_setup
dotfile_setup
claude_setup
xcode_cl_tools
# macos_defaults_setup
