#!/usr/bin/env bash
#
# dotfiles 安裝/更新腳本
#
# 使用情境：
#   1. 全新電腦：curl 直接執行（會自動 clone repo 後再 setup）
#      bash <(curl -fsSL https://raw.githubusercontent.com/luzen23141/dotfiles/main/install.sh)
#   2. 已安裝過：直接執行本檔（會 git pull --ff-only 拉取最新設定後 setup）
#      bash "$HOME/dotfiles/install.sh"

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
EXPECTED_HTTPS_REMOTE="https://github.com/luzen23141/dotfiles.git"
EXPECTED_SSH_REMOTE="git@github.com:luzen23141/dotfiles.git"

# === 階段 1: 取得 dotfiles repo ===

# 沒有 git 代表尚未安裝 Xcode Command Line Tools
if ! command -v git > /dev/null 2>&1; then
  xcode-select --install
  echo "請等 Xcode Command Line Tools 安裝完成後，重新執行此腳本"
  exit 0
fi

if [ ! -d "$DOTFILES" ]; then
  echo "Clone dotfiles 到 $DOTFILES"
  git clone "$EXPECTED_HTTPS_REMOTE" "$DOTFILES"
else
  if [ ! -d "$DOTFILES/.git" ]; then
    echo "錯誤: $DOTFILES 已存在但不是 git repository"
    exit 1
  fi

  current_remote=$(git -C "$DOTFILES" remote get-url origin 2>/dev/null || true)
  if [ "$current_remote" != "$EXPECTED_HTTPS_REMOTE" ] && [ "$current_remote" != "$EXPECTED_SSH_REMOTE" ]; then
    echo "錯誤: $DOTFILES 已存在但 remote 不符（current=$current_remote）"
    exit 1
  fi

  echo "拉取最新 dotfiles 設定..."
  git -C "$DOTFILES" pull --ff-only || echo "警告: git pull 失敗，繼續以本地版本 setup"
fi

cd "$DOTFILES" || { echo "無法進入 $DOTFILES"; exit 1; }

# === 階段 2: 系統環境 setup ===

echo "正在設定你的 Mac..."

# 2.1 Homebrew
if ! command -v brew > /dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ $? -ne 0 ]; then
    echo "Homebrew 安裝失敗"
    exit 1
  fi
  echo "Homebrew 安裝完成"

  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# 2.2 .zshrc symlink（幂等：已正確指向則跳過）
target="$DOTFILES/.zshrc"
if [ -L "$HOME/.zshrc" ] && [ "$(readlink "$HOME/.zshrc")" = "$target" ]; then
  echo ".zshrc 已是指向 dotfiles 的 symlink，跳過"
else
  if [ -e "$HOME/.zshrc" ] || [ -L "$HOME/.zshrc" ]; then
    backup_zshrc="$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
    mv "$HOME/.zshrc" "$backup_zshrc"
    echo "已備份既有 .zshrc 至 $backup_zshrc"
  fi
  ln -s "$target" "$HOME/.zshrc"
  echo "已建立 .zshrc symlink"
fi

# 2.3 Brew bundle
brew update
brew bundle --file "$DOTFILES/Brewfile"

echo "完成！"
