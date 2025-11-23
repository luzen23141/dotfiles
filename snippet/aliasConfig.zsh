source "$DOTFILES"/snippet/aliasFfmpeg.zsh
source "$DOTFILES"/snippet/aliasFfmpeg_h265.zsh
source "$DOTFILES"/snippet/aliasFfmpeg_av1.zsh
source "$DOTFILES"/snippet/aliasDocker.zsh
source "$DOTFILES"/snippet/aliasPhp.zsh
source "$DOTFILES"/snippet/aliasGit.zsh

# 系統
alias es='zinit update --all --parallel 16 && exec $(echo $SHELL)'

# brew 改用au auc
#alias bu="brew update && brew upgrade && brew cleanup && brew doctor"
#alias buc="brew update && brew upgrade --cask --greedy && mas upgrade"

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
#alias la="ls -lAh"
alias la="eza --icons --git -alhg --time-style '+%Y-%m-%d %H:%M'"
alias laa="eza --icons --git -alhg --total-size --time-style '+%Y-%m-%d %H:%M'"
alias las="eza --icons -s size --git -alhg --time-style '+%Y-%m-%d %H:%M'"
alias laas="eza --icons -s size --git -alhg --total-size --time-style '+%Y-%m-%d %H:%M'"
alias cat="bat --paging=never"

alias a="python3 \$(echo \$DOTFILES)/bin/a.py"
#alias a="python3 \$(echo \$DOTFILES)/bin/a.py"
alias au="\$(echo \$DOTFILES)/bin/a-update"
alias auc="\$(echo \$DOTFILES)/bin/a-update cask"

# golang
#alias gof="go fmt ./..."
#alias gov="go vet ./..."
#alias gor="go run ."
#alias gomt="go mod tidy"
#alias gomi="go mod init"
#alias gofvmt="go mod tidy && go fmt ./... && go vet ./..."

# python
alias py="/opt/homebrew/bin/python3"

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

  openApp=$1
  openPath=$2

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
  _zlua -e "$openPath" | xargs "$openApp"
}

#iterm2 當前視窗執行a指令，並且另開分頁執行b指令
#function asdfTest
#{
#    osascript <<EOF
#    tell application "iTerm2"
#        tell the current window
#            create tab with default profile
#            tell the last session of the last tab
#                delay 0.1
#                write text "j accounting_firms && cd frontend && nrd"
#            end tell
#        end tell
#    end tell
#EOF
#    oorbs && j accounting_firms && cd backend && dcu
#}

#function polling() {
#  while true; do
#    date +"%H:%M:%S"
#    curl https://min-api.cryptocompare.com/data/price\?fsym="$1"\&tsyms=USD
#    sleep "$2"
#    printf "\n\n"
#  done
#}

#function f() {
#  eval "$(~/.local/bin/fig init zsh pre --rcfile zshrc)"
#  eval "$(~/.local/bin/fig init zsh post --rcfile zshrc)"
#}

# 程式資料夾捷徑
#alias phpstorm="/usr/local/bin/phpstorm"
#alias goland="/usr/local/bin/goland"
#alias datagrip="/usr/local/bin/datagrip"

alias btc="curl https://min-api.cryptocompare.com/data/price\?fsym=BTC\&tsyms=USD"
alias eth="curl https://min-api.cryptocompare.com/data/price\?fsym=ETH\&tsyms=USD"
#alias s="cd ~/.config/sshAlias && sh"
# alias j="z"

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
  while true; do
    date +"%H:%M:%S"
    # 執行指令，指令可能為function 或者 alias
    eval "$1"
    # 需要前一個指令執行完成
    wait
    sleep "$2"
    printf "\n\n"
  done
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
