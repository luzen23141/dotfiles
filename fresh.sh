#!/bin/zsh

echo "正在設定你的 Mac..."

export DOTFILES="$HOME/dotfiles"

cd "$(dirname "$0")" || { echo "Path Error"; exit 1; }

# 檢查 Homebrew 是否已安裝，若無則自動安裝
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

# 若 $HOME/.zshrc 已存在則先備份，再建立軟連結指向 dotfiles 中的 .zshrc
if [ -e "$HOME/.zshrc" ] || [ -L "$HOME/.zshrc" ]; then
  backup_zshrc="$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
  mv "$HOME/.zshrc" "$backup_zshrc"
  echo "已備份既有 .zshrc 至 $backup_zshrc"
fi
ln -s "$DOTFILES"/.zshrc "$HOME"/.zshrc

# 更新 Homebrew 套件清單
brew update

# 透過 bundle 安裝所有相依套件（詳見 Brewfile）
brew bundle --file "$DOTFILES"/Brewfile

# 指定 iTerm2 偏好設定目錄
defaults write com.googlecode.iterm2 PrefsCustomFolder -string "~/dotfiles/appConfig/iterm2"

# 讓 iTerm2 從指定目錄載入偏好設定
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true

