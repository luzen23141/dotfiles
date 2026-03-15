# 啟動：p10k Instant Prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# 啟動：Homebrew 環境初始化（快取 shellenv 輸出，避免每次啟動 fork）
if [[ -x /opt/homebrew/bin/brew ]]; then
  BREW_ENV_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/brew_shellenv.zsh"
  if [[ ! -f "$BREW_ENV_CACHE" || /opt/homebrew/bin/brew -nt "$BREW_ENV_CACHE" ]]; then
    /opt/homebrew/bin/brew shellenv > "$BREW_ENV_CACHE"
  fi
  source "$BREW_ENV_CACHE"
fi

# 基礎設定：路徑與應用程式
export DOTFILES="$HOME/dotfiles"
export ICLOUD_DATA="$HOME/Library/Mobile Documents/com~apple~CloudDocs/dotfiles_data"
export VIMINIT="source \"$DOTFILES/vim/vimrc\"" # vimrc 路徑

# XDG 設定：路徑
# - config: 配置相關
# - cache: 可隨意刪除，只影響速度
# - data: 可重建，但會影響部分紀錄或資料
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.data"

# XDG 設定：config
export GIT_CONFIG_GLOBAL="$XDG_CONFIG_HOME/.gitconfig" # git 全域設定
export DOCKER_CONFIG="$XDG_CONFIG_HOME/.docker" # docker 全域設定

# XDG 設定：cache
export COMPOSER_HOME="$XDG_CACHE_HOME/composer" # composer 路徑
export SHELL_SESSION_DIR="$XDG_CACHE_HOME/zsh_sessions" # zsh 各視窗 session 紀錄
[[ -d "$SHELL_SESSION_DIR" ]] || mkdir -p "$SHELL_SESSION_DIR"

# XDG 設定：data / history
export LESSHISTFILE="$XDG_DATA_HOME/.lesshst" # less history 檔案
export REDISCLI_HISTFILE="$XDG_DATA_HOME/.rediscli_history"
export HISTFILE="$XDG_DATA_HOME/.zsh_history" # zsh history 檔案

# 工具設定：Go
export GOPATH="$XDG_CACHE_HOME/go"
export GOCACHE="$GOPATH/cache"
export GOBIN="/opt/gobin"
export GOMODCACHE="$GOPATH/mod-cache"
export GOTMPDIR="$GOPATH/tmp"
export GOSUMDB="off"

# 工具設定：npm
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME/npm"
export NPM_CONFIG_PREFIX="$XDG_DATA_HOME/npm"

# 設定：PATH
# 自動移除重複 PATH 項目，保留第一次出現的順序
# 僅集中整理既有項目，不新增 path
export PNPM_HOME="$XDG_DATA_HOME/pnpm"
typeset -U path PATH
path=(
  "$PNPM_HOME"
  "$HOME/.antigravity/antigravity/bin"
  "/opt/homebrew/opt/curl/bin"
  "$DOTFILES/bin"
  "$HOME/.orbstack/bin"
  "/opt/bin"
  "$GOBIN"
  "$COMPOSER_HOME/vendor/bin"
  "$NPM_CONFIG_PREFIX/bin"
  $path
)
export PATH

# 設定：Shell 基本行為
export LC_CTYPE="en_US.UTF-8"
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY="YES"

# 工具設定：zsh-autosuggestions
export ZSH_AUTOSUGGEST_USE_ASYNC="true"

# 工具設定：z.lua
export _ZL_ADD_ONCE="1" # 僅在路徑變更時更新資料庫
export _ZL_CMD="j" # 指令名稱（預設為 z）
export _ZL_DATA="$XDG_DATA_HOME/.zlua" # 資料檔路徑

# 編譯旗標：C/C++ 工具鏈（平常不需要，編譯 C 擴充套件時手動啟用）
# PKG_CONFIG_PATH：讓 pkg-config 找到 Homebrew 版 curl 的 metadata（版本、路徑）
# LDFLAGS        ：讓連結器（linker）找到 Homebrew curl 的 .dylib 函式庫
# CPPFLAGS       ：讓編譯器找到 Homebrew curl 的 .h header 檔案
#
# 使用場景：
#   curl 相關   → 強制使用 Homebrew 版 curl（比系統版新）
#   Swoole 編譯 → pecl install swoole 或 phpize && ./configure 時若需要 curl 支援：
#                 export PKG_CONFIG_PATH LDFLAGS CPPFLAGS
#                 pecl install swoole
#
# export PKG_CONFIG_PATH="/opt/homebrew/opt/curl/lib/pkgconfig"
# export LDFLAGS="-L/opt/homebrew/opt/curl/lib"
# export CPPFLAGS="-I/opt/homebrew/opt/curl/include"

# zinit 設定：路徑
# HOME_DIR: 安裝根目錄
# MAN_DIR / PLUGINS_DIR / COMPLETIONS_DIR / SNIPPETS_DIR: 各類資源目錄
# ZCOMPDUMP_PATH: compdump 快取位置
# OPTIMIZE_OUT_DISK_ACCESSES: 減少磁碟存取
declare -A ZINIT
ZINIT[HOME_DIR]="$XDG_CACHE_HOME/zinit"
ZINIT[MAN_DIR]="$XDG_CACHE_HOME/zinit/man"
ZINIT[PLUGINS_DIR]="$XDG_CACHE_HOME/zinit/plugins"
ZINIT[COMPLETIONS_DIR]="$XDG_CACHE_HOME/zinit/completions"
ZINIT[SNIPPETS_DIR]="$XDG_CACHE_HOME/zinit/snippets"
ZINIT[ZCOMPDUMP_PATH]="$XDG_CACHE_HOME/zinit/zcompdump"
ZINIT[OPTIMIZE_OUT_DISK_ACCESSES]="1"

# zinit 設定：載入與初始化
# 若尚未安裝 zinit，首次啟動時自動 clone
ZINIT_HOME="${XDG_CACHE_HOME}/zinit/zinit.git"
if [[ ! -f "$ZINIT_HOME/zinit.zsh" ]]; then
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# zinit 設定：主題與本地 snippets
zinit ice depth"1" # git clone depth
zinit light romkatv/powerlevel10k
zinit snippet "$DOTFILES/p10k.zsh"
zinit snippet "$DOTFILES/snippet/history.zsh"
zinit snippet "$DOTFILES/snippet/aliasConfig.zsh"

# OMZ 備註：可選 plugins
# OMZP::safe-paste        避免貼上後直接執行
# OMZP::colored-man-pages 顯示彩色 man page
# OMZP::command-not-found 顯示指令安裝提示，但會拖慢 command not found 回應
# OMZP::sudo              Operation not permitted 時，按兩次 esc 自動補 sudo

# zinit 設定：核心互動功能（即時載入）
zinit wait lucid depth"1" for \
  atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
    zdharma-continuum/fast-syntax-highlighting \
  blockf \
    zsh-users/zsh-completions \
  atload"!_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions \
  atload"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" blockf \
    "$DOTFILES/completion"

# zinit 設定：常用工具（延遲載入）
zinit wait'1' lucid depth"1" light-mode for \
  zsh-users/zsh-history-substring-search \
  djui/alias-tips \
  skywind3000/z.lua \
  OMZL::completion.zsh \
  OMZL::key-bindings.zsh \
  OMZP::safe-paste \
  OMZP::colored-man-pages \
  OMZP::sudo
#   OMZL::git.zsh  # 移除原因：與自訂 git alias 衝突；觀察中，確認無副作用後可刪除此行

# zinit 設定：較少使用工具（延遲載入）
zinit wait'2' lucid depth"1" light-mode for \
  paulirish/git-open

# export OPENCODE_DISABLE_CLAUDE_CODE=1  # 停用 opencode 內建的 claude code 整合（衝突時啟用）