#! /bin/zsh
export ITERM_FONT="Hack Nerd Font Mono"
export ITERM_COLORS="Solarized Dark"

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.data"
export GIT_CONFIG_GLOBAL="$XDG_CONFIG_HOME/.gitconfig"
export LESSHISTFILE="$XDG_CONFIG_HOME/.lesshst"
export REDISCLI_HISTFILE="$XDG_CONFIG_HOME/.rediscli_history"
export LC_CTYPE=en_US.UTF-8

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# 設定zinit 安裝路徑
declare -A ZINIT
ZINIT[HOME_DIR]=$HOME/.cache/zinit
ZINIT[MAN_DIR]=$HOME/.cache/zinit/man
ZINIT[PLUGINS_DIR]=$HOME/.cache/zinit/plugins
ZINIT[COMPLETIONS_DIR]=$HOME/.cache/zinit/completions
ZINIT[SNIPPETS_DIR]=$HOME/.cache/zinit/snippets
ZINIT[ZCOMPDUMP_PATH]=$HOME/.cache/zinit/zcompdump

_ZL_NO_ALIASES=off

# 設定 vimrc 路徑
export VIMINIT="source $DOTFILES/vim/vimrc"

# 設定 z.lua 路徑 (自動跳轉插件)
export _ZL_DATA=$XDG_CACHE_HOME/.zlua

# 設定 composer 路徑
export COMPOSER_HOME=$XDG_CACHE_HOME/composer

# 設定 history 檔路徑
export HISTFILE=$XDG_CACHE_HOME/.zsh_history

# 載入 zinit ，如果未下載過會自動抓
ZINIT_HOME="${XDG_CACHE_HOME}/zinit/zinit.git"
if [[ ! -f $ZINIT_HOME/zinit.zsh ]]; then
	mkdir -p "$(dirname $ZINIT_HOME)"
	git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# 載入 fig
# zi ice lucid wait
# zi snippet "$HOME/.fig/shell/zshrc.pre.zsh"
# zi ice lucid wait
# zi snippet "$HOME/.fig/shell/zshrc.post.zsh"

# 載入 powerlevel10k 主題
zi ice depth"1" # git clone depth
zi light romkatv/powerlevel10k
zi snippet $DOTFILES/p10k.zsh

# OMZL::history.zsh  # 有時間戳格式的.zsh_history
# OMZP::safe-paste  # 避免貼上後直接執行
# OMZP::colored-man-pages  # 有顏色的man page
# OMZP::command-not-found 顯示command not found的command如何獲得，會造成command not found 時，回傳的速度比較慢
# OMZP::sudo Operation not permitted時，按兩次esc 自動加 sudo
zi wait lucid depth"1" for \
  OMZL::history.zsh \
  OMZL::completion.zsh \
  OMZL::key-bindings.zsh \
  OMZL::git.zsh \
  OMZP::safe-paste \
  OMZP::colored-man-pages \
  OMZP::sudo \
  atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
    zdharma-continuum/fast-syntax-highlighting \
  blockf \
    zsh-users/zsh-completions \
  atload"!_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions \
  atload"zicompinit; zicdreplay" blockf \
    $DOTFILES/completion \
  aliases pick"$DOTFILES/aliasConfig.zsh" \
    $DOTFILES

zi wait lucid depth"1" light-mode for \
  zsh-users/zsh-history-substring-search \
  djui/alias-tips \
  skywind3000/z.lua \
  paulirish/git-open

# User configuration
# export TERM="xterm-256color"

# You may need to manually set your language environment
# export LC_ALL=en_US.UTF-8
# export LANG=en_US.UTF-8
# export PATH="~/.local/bin:$DOTFILES/plugins/gitOpen:/usr/local/sbin:$PATH"
export PATH="$DOTFILES/bin:$HOME/.orbstack/bin:/usr/local/sbin:$PATH"
export GOPATH="$HOME/Code/go"

# This speed up zsh-autosuggetions by a lot
export ZSH_AUTOSUGGEST_USE_ASYNC="true"

export DOCKER_CONFIG="$HOME/.config/.docker"

# laravel octane 需要用到，詳細原因還沒確認
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES


