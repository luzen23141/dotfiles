# 系統
alias es='exec $(echo $SHELL)'

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

# git
alias g="git"
alias gp="git push"
alias gpf="git push --force-with-lease"
alias gl="git pull -p"  # -a 追加到 .git/FETCH_HEAD 而不是覆蓋它 ; -p 清除遠端已經不存在的分支的追蹤分支
alias gc="git checkout"
#alias gcm="git checkout master"
# alias gcam="git commit -am"
alias gb="git branch"
alias gm="git merge"
alias gs="git status"
#alias gca="git checkout alex"
alias grv="git remote -v"
#alias gma="git merge origin/alex --no-edit"
#alias grom="git rebase origin/master"
alias gcb="git clear branch"
alias gsu="git submodule update --init --recursive"
alias gito="git open origin master"
alias gai="cat ~/.config/.gitignore_global >> .git/info/exclude && cat .git/info/exclude"
# alias gcd="git checkout dev"
alias grh="git reset HEAD^"
alias gba="git branch -a"
alias gsur="git submodule update --recursive --remote"
alias grs="git restore --staged"
alias gcm="git_check_mainBranch"
alias ga.="git add . && git status"

# docker
alias dc="docker-check && docker compose"
alias dp="docker-check && docker ps"

# laradock
alias dcd="cd ~/Code/dockerCompose && docker compose down"
alias dcu="cd ~/Code/dockerCompose && docker-check && docker compose up -d"
alias docker-check='
if ! docker ps > /dev/null 2>&1; then
  /Applications/OrbStack.app/Contents/MacOS/OrbStack &
  sleep 5
fi'

## php多版本
alias php73='"$HOMEBREW_PREFIX"/opt/php@7.3/bin/php'
alias pecl73='"$HOMEBREW_PREFIX"/opt/php@7.3/bin/pecl'
alias composer73='"$HOMEBREW_PREFIX"/opt/php@7.3/bin/php "$HOMEBREW_PREFIX"/bin/composer'
alias php74='"$HOMEBREW_PREFIX"/opt/php@7.4/bin/php'
alias pecl74='"$HOMEBREW_PREFIX"/opt/php@7.4/bin/pecl'
alias composer74='"$HOMEBREW_PREFIX"/opt/php@7.4/bin/php "$HOMEBREW_PREFIX"/bin/composer'
alias php80='"$HOMEBREW_PREFIX"/opt/php@8.0/bin/php'
alias pecl80='"$HOMEBREW_PREFIX"/opt/php@8.0/bin/pecl'
alias composer80='"$HOMEBREW_PREFIX"/opt/php@8.0/bin/php "$HOMEBREW_PREFIX"/bin/composer'
alias php81='"$HOMEBREW_PREFIX"/opt/php@8.1/bin/php'
alias pecl81='"$HOMEBREW_PREFIX"/opt/php@8.1/bin/pecl'
alias composer81='"$HOMEBREW_PREFIX"/opt/php@8.1/bin/php "$HOMEBREW_PREFIX"/bin/composer'
# hyperf框架多版本
alias hy80='"$HOMEBREW_PREFIX"/opt/php@8.0/bin/php bin/hyperf.php'
alias hy73='"$HOMEBREW_PREFIX"/opt/php@7.3/bin/php bin/hyperf.php'
alias hy74='"$HOMEBREW_PREFIX"/opt/php@7.4/bin/php bin/hyperf.php'
alias hy='php bin/hyperf.php'

# git commit且push
function gcp() {
  git commit -am "$1" && git push -u origin "$(git rev-parse --abbrev-ref HEAD)"
}
function ga() {
  git add "$1" && git status
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

#function rebuild() {
#    git pull && echo '' >> readme.md && git commit -am 'rebuild' && git push &&
#    git tag $1 && git push origin $1
#}
#
#function gt () {
#    git tag $1 && git push origin $1
#}

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

function gma() {
  config_file=".aConfig"

  # 檢查是否存在 .aConfig 檔案
  if [ -f "$config_file" ]; then
    # 讀取 .aConfig 檔案中的內容
    config_value=$(grep "mine_branch=" "$config_file" | cut -d'=' -f2-)

    if [ -n "$config_value" ]; then
      echo "執行指令 git merge origin/$config_value --no-edit"
      git merge origin/"$config_value" --no-edit
    else
      echo "未找到 mine_branch= 指令，執行預設指令 git merge origin/alex --no-edit"
      git merge origin/alex --no-edit
    fi

    config_value=$(grep "merge_mine_check=" "$config_file" | cut -d'=' -f2-)
    if [ -n "$config_value" ]; then
      echo "執行指令 $config_value"
      eval "$config_value"
    fi

  else
      echo "未找到 $config_file ，執行預設指令 git merge origin/alex --no-edit"
      git merge origin/alex --no-edit
  fi
}


#function polling() {
#  while true; do
#    date +"%H:%M:%S"
#    curl https://min-api.cryptocompare.com/data/price\?fsym="$1"\&tsyms=USD
#    sleep "$2"
#    printf "\n\n"
#  done
#}

#function gitpr() {
#  git open origin master --suffix compare/master..."$(git rev-parse --abbrev-ref HEAD)"
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

# rebase master
# function grm() {
#   current="$(git rev-parse --abbrev-ref HEAD)"
#   git checkout master && git pull && git checkout "$current" && git rebase origin/master && git push
# }

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
