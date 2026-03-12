source "$DOTFILES"/snippet/aliasFfmpeg.zsh
source "$DOTFILES"/snippet/aliasFfmpeg_h265.zsh
source "$DOTFILES"/snippet/aliasFfmpeg_av1.zsh
source "$DOTFILES"/snippet/aliasDocker.zsh
source "$DOTFILES"/snippet/aliasPhp.zsh
source "$DOTFILES"/snippet/aliasGit.zsh
source "$DOTFILES"/snippet/images.zsh

# 系統
alias es='zinit update --all --parallel 16 && rm -f "${ZINIT[ZCOMPDUMP_PATH]}" && exec $SHELL'

# ./bin 指令縮寫
alias cad='claude-profile.sh'

# 防呆
# 防止誤刪檔案或覆蓋到已有檔案 (覆蓋檔案時會需要確認)
alias cp='cp -i'
alias mv='mv -i'
alias ln='ln -i'
# rm 指令不刪除，改為移到垃圾桶
alias rm="trash"

# 好用
alias grep='grep --color=auto'
alias ls="ls -G"
alias la="eza --icons --git -alhg --time-style '+%Y-%m-%d %H:%M'"
alias laa="eza --icons --git -alhg --total-size --time-style '+%Y-%m-%d %H:%M'"
alias las="eza --icons -s size --git -alhg --time-style '+%Y-%m-%d %H:%M'"
alias laas="eza --icons -s size --git -alhg --total-size --time-style '+%Y-%m-%d %H:%M'"
alias cat="bat --paging=never"

alias a="python3 $DOTFILES/bin/a.py"
alias au="$DOTFILES/bin/a-update && rm -f \"\${XDG_CACHE_HOME:-\$HOME/.cache}/brew_shellenv.zsh\" \"\${ZINIT[ZCOMPDUMP_PATH]}\""
alias auc="$DOTFILES/bin/a-update cask"

# Enable sudo in aliased
# http://askubuntu.com/questions/22037/aliases-not-available-when-using-sudo
alias sudo='sudo '

# screen
alias sc="screen_new"
alias scl="screen -ls"
alias scr="screen -r"
alias scd="screen_X_S_Input_quit"
function screen_X_S_Input_quit() {
    screen -X -S "$1" quit
}
function screen_new() {
    if [ $# -eq 0 ]; then
        screen
    elif [[ $1 == -* ]]; then  # 檢查第一個參數是否以 "-" 開頭
        screen "$@"  # 將所有傳入的參數直接傳遞給 screen
    else
        screen -S "$@"
    fi
}

alias ao="a_open_path_by_app"
function a_open_path_by_app() {
  if [ -z "$2" ]; then
    echo "請輸入要開啟的應用程式名稱和路徑"
    return 1
  fi

  local openApp=$1
  local openPath=$2
  local matched_path

  # 將$1 用switch來處理縮寫
  case "$openApp" in
    "p") openApp="phpstorm" ;;
    "php") openApp="phpstorm" ;;
    "g") openApp="goland" ;;
    "go") openApp="goland" ;;
    "py") openApp="pycharm" ;;
    "pyc") openApp="pycharm" ;;
    "sublime") openApp="sublime" ;;
    "s") openApp="sublime" ;;
    "sub") openApp="sublime" ;;
  esac

  echo "使用$openApp開啟$openPath"
  matched_path="$(_zlua -e "$openPath" | head -n 1)"

  if [ -z "$matched_path" ]; then
    echo "找不到對應路徑: $openPath"
    return 1
  fi

  "$openApp" "$matched_path"
}

alias btc="curl https://min-api.cryptocompare.com/data/price\?fsym=BTC\&tsyms=USD"
alias eth="curl https://min-api.cryptocompare.com/data/price\?fsym=ETH\&tsyms=USD"

function polling() {
  # 檢查是否剛好有兩個入參
  if [ "$#" -ne 2 ]; then
    echo "請提供兩個入參"
    return 1
  fi

  # 檢查第一個入參是否為合法的指令
  if ! command -v "$1" &> /dev/null; then
    echo "第一個入參不是合法的指令"
    return 1
  fi

  # 檢查第二個入參是否為數字
  if ! [[ "$2" =~ ^[0-9]+$ ]]; then
    echo "第二個入參不是數字"
    return 1
  fi

  # 執行指令
  local cmd_parts=("${(@z)1}")
  if ! command -v "${cmd_parts[1]}" &> /dev/null; then
    echo "第一個入參不是合法的指令"
    return 1
  fi

  while true; do
    date +"%H:%M:%S"
    "${cmd_parts[@]}"
    wait
    sleep "$2"
    printf "\n\n"
  done
}

# 工具快捷
alias vimc="vim +'%d|w'"
alias cluade="claude"
alias atg="antigravity"
alias anti="antigravity"

# 指令名稱：vimp [檔案路徑]
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
    old_stats=$(wc "$target_file" | awk '{print "行數: " $1 ", 字元: " $3}')
    mkdir -p "$HOME/.ai_trash"
    backup_path="$HOME/.ai_trash/$(basename "$target_file")_$(date +%Y%m%d_%H%M%S)"
    cp "$target_file" "$backup_path"
  fi

  if ! pbpaste > "$temp_file"; then
    command rm -f "$temp_file"
    echo "錯誤：無法讀取剪貼簿內容"
    return 1
  fi

  command mv "$temp_file" "$target_file"

  local new_stats=$(wc "$target_file" | awk '{print "行數: " $1 ", 字元: " $3}')

  echo "--- 執行結果 ---"
  echo "原始狀態: $old_stats"
  if [ -n "$backup_path" ]; then
    echo "備份位置: $backup_path"
  fi
  echo "更新後　: $new_stats"
  echo "----------------"
}

alias s="sshAlias"
function sshAlias() {
    local script_dir=~/.config/sshAlias

    if [ -n "$1" ] && [ -f "$script_dir/$1" ]; then
        sh "$script_dir/$1"
    else
        printf '未找到腳本 %s\n\n' "$1"
        cd "$script_dir" || printf '腳本目錄 %s 不存在\n' "$script_dir"
        ls -alh
    fi
}
