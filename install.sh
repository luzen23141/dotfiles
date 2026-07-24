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
  if ! git -C "$DOTFILES" pull --ff-only; then
    echo "錯誤: git pull 失敗，中止 setup（請先解決衝突或手動同步）"
    exit 1
  fi
fi

cd "$DOTFILES" || { echo "無法進入 $DOTFILES"; exit 1; }

# === 階段 2: 系統環境 setup ===

echo "正在設定你的 Mac..."

# 2.1 Homebrew（僅 Apple Silicon /opt/homebrew；已安裝但不在 PATH 時也要補上 shellenv）
brew_bin=""
if command -v brew > /dev/null 2>&1; then
  brew_bin="$(command -v brew)"
elif [ -x /opt/homebrew/bin/brew ]; then
  brew_bin="/opt/homebrew/bin/brew"
fi

if [ -z "$brew_bin" ]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ $? -ne 0 ]; then
    echo "Homebrew 安裝失敗"
    exit 1
  fi
  echo "Homebrew 安裝完成"
  if [ -x /opt/homebrew/bin/brew ]; then
    brew_bin="/opt/homebrew/bin/brew"
  else
    echo "錯誤: 找不到 /opt/homebrew/bin/brew（僅支援 Apple Silicon）"
    exit 1
  fi
fi

brew_shellenv_line="eval \"\$($brew_bin shellenv)\""
if ! grep -Fqx "$brew_shellenv_line" "$HOME/.zprofile" 2>/dev/null; then
  echo "$brew_shellenv_line" >> "$HOME/.zprofile"
fi
eval "$("$brew_bin" shellenv)"

# 2.2 XDG / viminfo 目錄（幂等）
mkdir -p \
  "${XDG_CONFIG_HOME:-$HOME/.config}" \
  "${XDG_CACHE_HOME:-$HOME/.cache}" \
  "${XDG_DATA_HOME:-$HOME/.data}" \
  "${XDG_CACHE_HOME:-$HOME/.cache}/.vim"

# 2.3 .zshrc symlink（幂等：已正確指向則跳過）
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

# 2.4 Brew bundle
brew update
brew bundle --file "$DOTFILES/Brewfile"

# === 階段 3: 從 iCloud 備份還原設定（restore）===
#
# 注意：restore 會用 iCloud 備份覆蓋現有設定，並關閉/重開部分 app。
# 全新電腦才需要；日常更新請跳過，以免覆蓋當前設定。
BACKUP_SCRIPT="$DOTFILES/bin/backup.sh"
BACKUP_JSON="$HOME/Library/Mobile Documents/com~apple~CloudDocs/dotfiles_data/backup.json"

# 用 /dev/tty 讀取，確保 `bash <(curl ...)` 管線模式下仍可互動
if [ -r /dev/tty ]; then
  printf "\n是否從 iCloud 備份還原設定 (restore)？全新電腦按 y，日常更新直接 Enter 跳過 [y/N] " > /dev/tty
  read -r restore_ans < /dev/tty || restore_ans=""
else
  restore_ans=""
  echo "（非互動環境，略過 restore；稍後可手動執行：bash $BACKUP_SCRIPT restore）"
fi

if [[ "$restore_ans" =~ ^[Yy]$ ]]; then
  # 等待 iCloud 同步 backup.json（可能尚未下載完成）
  if [ ! -f "$BACKUP_JSON" ]; then
    echo "找不到 $BACKUP_JSON"
    echo "請先登入 iCloud，並等待 dotfiles_data 同步下載完成。"
    if [ -r /dev/tty ]; then
      printf "同步完成後按 Enter 繼續（或 Ctrl-C 中止）..." > /dev/tty
      read -r _ < /dev/tty || true
    fi
  fi

  if [ -f "$BACKUP_JSON" ] && jq empty "$BACKUP_JSON" > /dev/null 2>&1; then
    echo "開始還原設定..."
    # backup.sh 已內建 GIT_SSH_COMMAND=accept-new，處理首次 SSH host key；
    # ssh 金鑰本身也在備份中，restore 會先還原 ~/.ssh 再 clone git 專案。
    bash "$BACKUP_SCRIPT" restore || echo "[警告] restore 過程有錯誤，請檢視上方輸出後手動補救"
  else
    echo "[略過] 仍找不到或無法讀取 backup.json。稍後可手動執行：bash $BACKUP_SCRIPT restore"
  fi
else
  echo "已略過 restore。"
fi

echo "完成！"
