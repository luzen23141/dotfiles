#!/bin/sh

echo "Setting up your Mac..."

export DOTFILES="$HOME/dotfiles"

cd "$(dirname "$0")" || (echo "Path Error" && exit)

. "$DOTFILES"/dotfileFunction.sh

# submodule安裝
#git submodule init
#git submodule update

# Check for Homebrew and install if we don't have it
if ! command -v brew > /dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  statusInstallBrew=$?
  if [ $statusInstallBrew -eq 0 ]; then
      echo "Homebrew 安裝完成"
  else
      echo "Homebrew 安裝失敗"
      exit $statusInstallBrew
  fi

  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Removes .zshrc from $HOME (if it exists) and symlinks the .zshrc file from the .dotfiles
rm -rf "$HOME"/.zshrc
ln -s "$DOTFILES"/.zshrc "$HOME"/.zshrc

# Update Homebrew recipes
brew update

# Install all our dependencies with bundle (See Brewfile)
brew tap homebrew/bundle
brew install mas
brew bundle --file "$DOTFILES"/Brewfile

# Set default MySQL root password and auth type
#mysql -u root -e "ALTER USER root@localhost IDENTIFIED WITH mysql_native_password BY 'password'; FLUSH PRIVILEGES;"

# Install PHP extensions with PECL
#pecl install imagick redis swoole

# Install global Composer packages
#/usr/local/bin/composer global require laravel/installer laravel/valet beyondcode/expose spatie/global-ray spatie/visit

# Install Laravel Valet
#$HOME/.composer/vendor/bin/valet install

# Install Global Ray
#$HOME/.composer/vendor/bin/global-ray install

# Create a Sites directory
#mkdir $HOME/Sites

# Create sites subdirectories
#mkdir $HOME/Sites/blade-ui-kit
#mkdir $HOME/Sites/laravel

# Clone Github repositories
#$DOTFILES/clone.sh

# 建立軟連結
info '  Installing dotfiles'
for src in $(find "$DOTFILES/autoLink" -maxdepth 2 -name '*.symlink' -not -path '*.git*')
do
  dst="$HOME/.$(basename "${src%.*}")"
  link_file "$src" "$dst"
done

# Specify the preferences directory
defaults write com.googlecode.iterm2 PrefsCustomFolder -string "~/dotfiles/appConfig/iterm2"

# Tell iTerm2 to use the custom preferences in the directory
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true

