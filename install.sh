#!/bin/bash

# dotFiles 檔案預計放的位置
DOTFILES_TMP="$HOME"/dotfiles
EXPECTED_HTTPS_REMOTE="https://github.com/luzen23141/dotfiles.git"
EXPECTED_SSH_REMOTE="git@github.com:luzen23141/dotfiles.git"

# 如果沒有 git，代表尚未安裝 Xcode
if ! command -v git > /dev/null 2>&1; then
  xcode-select --install
  echo "安裝mac xcode完成後，再重新執行此腳本"
  exit 0
fi

if [ ! -d "$DOTFILES_TMP" ]; then
  git clone "$EXPECTED_HTTPS_REMOTE" "$DOTFILES_TMP"
else
  if [ ! -d "$DOTFILES_TMP/.git" ]; then
    echo "錯誤: $DOTFILES_TMP 已存在，但不是 git repository"
    exit 1
  fi

  current_remote=$(git -C "$DOTFILES_TMP" remote get-url origin 2>/dev/null || true)
  if [ "$current_remote" != "$EXPECTED_HTTPS_REMOTE" ] && [ "$current_remote" != "$EXPECTED_SSH_REMOTE" ]; then
    echo "錯誤: $DOTFILES_TMP 已存在，但不是預期的 dotfiles repository"
    exit 1
  fi
fi

"$DOTFILES_TMP"/fresh.sh
