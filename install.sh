#!/bin/bash

# dotFiles档案预计放的位子
DOTFILES_TMP="$HOME"/dotfiles

# 如果沒有git 代表應該是沒有安裝X xcode
if ! command -v git > /dev/null 2>&1; then
  xcode-select --install
fi

if [ ! -d "$DOTFILES_TMP" ]; then
  git clone https://github.com/luzen23141/dotfiles.git "$DOTFILES_TMP"
fi

zsh "$DOTFILES_TMP"/fresh.sh
