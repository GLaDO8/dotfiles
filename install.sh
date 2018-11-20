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
	brew tap homebrew/bundle
	brew bundle

	# Save Homebrew’s installed location.
	BREW_PREFIX=$(brew --prefix)
	
	# Install GNU core utilities (those that come with macOS are outdated).
	# Don’t forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
	brew install coreutils
	ln -s "${BREW_PREFIX}/bin/gsha256sum" "${BREW_PREFIX}/bin/sha256sum"

	# Install some other useful utilities like `sponge`.
	brew install moreutils
	# Install GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed.
	brew install findutils
	# Install GNU `sed`, overwriting the built-in `sed`.
	brew install gnu-sed --with-default-names

	finish
}

dotfile_setup(){
	# Make ZSH the default shell environment
	echo "Making zsh as the default shell environment..."
	chsh -s $(which zsh)

	echo "setting up personal dotfiles..."
	cd ~
	git clone https://github.com/GLaDOS-root/dotfiles.git

	# Removes .zshrc from $HOME (if it exists) and symlinks the .zshrc file from the .dotfiles
	echo "Creating symlinks for dotfiles..."
	rm -rf $HOME/.zshrc
	ln -s $HOME/dotfiles/.zshrc $HOME/.zshrc

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

macos_defaultss_setup(){
	# Set macOS preferences
	# We will run this last because this will reload the shell
	echo "Settings macOS preferences..."
	source .macos

	finish
}
