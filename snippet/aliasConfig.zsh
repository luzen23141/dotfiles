# ── 外部 snippet ──────────────────────────────────────────────
source "$DOTFILES"/snippet/aliasFfmpeg.zsh
source "$DOTFILES"/snippet/aliasFfmpeg_h265.zsh
source "$DOTFILES"/snippet/aliasFfmpeg_av1.zsh
source "$DOTFILES"/snippet/aliasDocker.zsh
source "$DOTFILES"/snippet/aliasPhp.zsh
source "$DOTFILES"/snippet/aliasGit.zsh
source "$DOTFILES"/snippet/images.zsh

# ── 防呆 ──────────────────────────────────────────────────────
# 覆蓋檔案時需確認，rm 改為移到垃圾桶
alias cp='cp -i'
alias mv='mv -i'
alias ln='ln -i'
alias rm="trash"

# ── 系統 ──────────────────────────────────────────────────────
# 更新 zinit 插件並重啟 shell（command rm 刻意繞過 trash alias，compdump 為快取可直接刪除）
alias es='zinit update --all --parallel 16 && command rm -f "${ZINIT[ZCOMPDUMP_PATH]}" && exec $SHELL'
# 允許 sudo 套用 alias
alias sudo='sudo '

# ── 檔案瀏覽 ──────────────────────────────────────────────────
alias grep='grep --color=auto'
alias ls="ls -G"
alias cat="bat --paging=never"
alias la="eza --icons --git -alhg --time-style '+%Y-%m-%d %H:%M'"
alias laa="eza --icons --git -alhg --total-size --time-style '+%Y-%m-%d %H:%M'"
alias las="eza --icons -s size --git -alhg --time-style '+%Y-%m-%d %H:%M'"
alias laas="eza --icons -s size --git -alhg --total-size --time-style '+%Y-%m-%d %H:%M'"

# ── bin 指令 ──────────────────────────────────────────────────
alias a="python3 $DOTFILES/bin/a.py"
alias au="$DOTFILES/bin/a-update"       # cleanup 已內建於腳本
alias auc="$DOTFILES/bin/a-update cask"
alias cad='claude-profile.sh'

# ── 工具快捷 ──────────────────────────────────────────────────
alias oc="opencode"
alias vimc="vim +'%d|w'"           # 清空檔案後開啟 vim
alias cluade="claude"              # typo 防呆
alias atg="antigravity"
alias anti="antigravity"
alias btc='curl "https://min-api.cryptocompare.com/data/price?fsym=BTC&tsyms=USD"'
alias eth='curl "https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD"'

# ── screen ────────────────────────────────────────────────────
alias sc="screen_new"
alias scl="screen -ls"
alias scr="screen -r"
alias scd="screen_quit_session"

function screen_quit_session() {
  screen -X -S "$1" quit
}

function screen_new() {
  if [ $# -eq 0 ]; then
    screen
  elif [[ $1 == -* ]]; then
    screen "$@"
  else
    screen -S "$@"
  fi
}

# ── ao：用指定 IDE 開啟 z 路徑 ────────────────────────────────
# 用法：ao <app> <path>  (app 縮寫：p=phpstorm, g=goland, py=pycharm, s=sublime)
alias ao="a_open_path_by_app"
function a_open_path_by_app() {
  if [ -z "$2" ]; then
    echo "請輸入要開啟的應用程式名稱和路徑"
    return 1
  fi

  local openApp=$1
  local openPath=$2
  local matched_path

  case "$openApp" in
    "p"|"php") openApp="phpstorm" ;;
    "g"|"go")  openApp="goland" ;;
    "py"|"pyc") openApp="pycharm" ;;
    "s"|"sub"|"sublime") openApp="sublime" ;;
  esac

  echo "使用$openApp開啟$openPath"
  # 使用 z.lua 查詢路徑
  if command -v _zlua &> /dev/null; then
    matched_path="$(_zlua -e "$openPath" | head -n 1)"
  fi

  if [ -z "$matched_path" ]; then
    echo "找不到對應路徑: $openPath"
    return 1
  fi

  "$openApp" "$matched_path"
}

# ── vimp：從剪貼簿貼上內容寫入檔案 ──────────────────────────
# 用法：vimp <檔案路徑>
vimp() {
  local target_file=$1

  if [ -z "$target_file" ]; then
    echo "錯誤：請提供檔名，例如 vimp test.txt"
    return 1
  fi

  local old_stats="不存在"
  local backup_path=""
  local temp_file
  temp_file=$(mktemp)

  if [ -f "$target_file" ]; then
    old_stats="行數: $(wc -l < "$target_file" | tr -d ' '), 字元: $(wc -c < "$target_file" | tr -d ' ')"
    mkdir -p "$HOME/.ai_trash"
    backup_path="$HOME/.ai_trash/$(basename "$target_file")_$(date +%Y%m%d_%H%M%S)"
    command cp "$target_file" "$backup_path"
  fi

  if ! pbpaste > "$temp_file"; then
    command rm -f "$temp_file"
    echo "錯誤：無法讀取剪貼簿內容"
    return 1
  fi

  command mv "$temp_file" "$target_file"

  local new_stats="行數: $(wc -l < "$target_file" | tr -d ' '), 字元: $(wc -c < "$target_file" | tr -d ' ')"

  echo "--- 執行結果 ---"
  echo "原始狀態: $old_stats"
  if [ -n "$backup_path" ]; then
    echo "備份位置: $backup_path"
  fi
  echo "更新後　: $new_stats"
  echo "----------------"
}

# ── polling：定時重複執行指令 ─────────────────────────────────
# 用法：polling <指令> <間隔秒數>
function polling() {
  if [ "$#" -ne 2 ]; then
    echo "請提供兩個入參"
    return 1
  fi

  if ! [[ "$2" =~ ^[0-9]+$ ]]; then
    echo "第二個入參不是數字"
    return 1
  fi

  local cmd_parts=("${(@z)1}")
  if ! command -v "${cmd_parts[1]}" &> /dev/null; then
    echo "第一個入參不是合法的指令"
    return 1
  fi

  while true; do
    date +"%H:%M:%S"
    "${cmd_parts[@]}"
    sleep "$2"
    printf "\n\n"
  done
}

# ── s：SSH alias 腳本 ─────────────────────────────────────────
# 用法：s <腳本名>  (腳本存放於 ~/.config/sshAlias/)
alias s="sshAlias"
function sshAlias() {
    local script_dir=~/.config/sshAlias

    if [ -n "$1" ] && [ -f "$script_dir/$1" ]; then
        sh "$script_dir/$1"
    else
        printf '未找到腳本 %s\n\n' "$1"
        cd "$script_dir" && ls -alh || printf '腳本目錄 %s 不存在\n' "$script_dir"
    fi
}
