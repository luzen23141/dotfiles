# 啟動：p10k Instant Prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# 啟動：Homebrew 環境初始化（快取 shellenv 輸出，避免每次啟動 fork）
# 僅支援 Apple Silicon（/opt/homebrew）；不支援 Intel Mac（/usr/local），請勿改為雙架構偵測。
#
# 快取寫入必須「先寫暫存檔再 mv」：直接 `> 快取` 會先截斷檔案，
# 若同時開多個終端（或 brew 中途失敗），其他 shell 會 source 到 0 byte 的空檔，
# 而 mtime 又比 brew 新 → 快取永久毒化，之後每個新終端都失去 /opt/homebrew/bin 與 FPATH。
if [[ -x /opt/homebrew/bin/brew ]]; then
  BREW_ENV_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/brew_shellenv.zsh"
  # -f 且 -s：必須是非空的一般檔案。0 byte 視為毒化；若被誤建成目錄（-s 對目錄也成立、source 會失敗、
  # mv 會把暫存檔搬進目錄裡），同樣視為無效並先移除，否則永遠無法自我修復
  if [[ ! -f "$BREW_ENV_CACHE" || ! -s "$BREW_ENV_CACHE" || /opt/homebrew/bin/brew -nt "$BREW_ENV_CACHE" ]]; then
    [[ -d "$BREW_ENV_CACHE" ]] && command rm -rf -- "$BREW_ENV_CACHE"
    mkdir -p "${BREW_ENV_CACHE:h}"
    if /opt/homebrew/bin/brew shellenv > "$BREW_ENV_CACHE.$$" && [[ -s "$BREW_ENV_CACHE.$$" ]]; then
      command mv -f "$BREW_ENV_CACHE.$$" "$BREW_ENV_CACHE"
    else
      command rm -f "$BREW_ENV_CACHE.$$"
    fi
  fi
  # 快取仍不可用時直接 eval，寧可多 fork 一次也不能讓 PATH 缺 Homebrew
  if [[ -f "$BREW_ENV_CACHE" && -s "$BREW_ENV_CACHE" ]]; then
    source "$BREW_ENV_CACHE"
  else
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi

# 基礎設定：路徑與應用程式
export DOTFILES="$HOME/dotfiles"
export ICLOUD_DATA="$HOME/Library/Mobile Documents/com~apple~CloudDocs/dotfiles_data"
# VIMINIT 的值是當 Ex 命令執行，而 Ex 的 " 是註解起始字元：
# 寫成 source "path" 會讓 source 吃到空參數，vimrc 靜默不載入（實測 viminfofile= / nonumber，
# 與完全沒設 VIMINIT 的結果相同），連 vim/vimrc 指定的 viminfofile 也失效 → viminfo 落回 ~/.viminfo。
# 路徑含空白時要用反斜線轉義（source /a\ b/vimrc），不可改回雙引號。
export VIMINIT="source $DOTFILES/vim/vimrc" # vimrc 路徑

# XDG 設定：路徑
# - config: 配置相關
# - cache: 可隨意刪除，只影響速度
# - data: 可重建，但會影響部分紀錄或資料
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.data"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME/.vim" "$XDG_CACHE_HOME/zsh"

# XDG 設定：config
export GIT_CONFIG_GLOBAL="$XDG_CONFIG_HOME/.gitconfig" # git 全域設定
export DOCKER_CONFIG="$XDG_CONFIG_HOME/.docker" # docker 全域設定

# XDG 設定：cache
export COMPOSER_CACHE_DIR="$XDG_CACHE_HOME/composer" # composer 下載快取（可刪）
export PIP_CACHE_DIR="$XDG_CACHE_HOME/pip" # 預設在 ~/Library/Caches/pip
# OMZL::completion.zsh 用 $ZSH_CACHE_DIR 當 zstyle cache-path；不設會落回 ~/.zcompcache
export ZSH_CACHE_DIR="$XDG_CACHE_HOME/zsh"
# 不設 SHELL_SESSION_DIR：/etc/zshrc_Apple_Terminal 在 ~/.zshrc 之前就把它硬寫成
# ${ZDOTDIR:-$HOME}/.zsh_sessions，這裡設了不會生效；且該機制只在 Apple Terminal
# （有 TERM_SESSION_ID）啟用，Ghostty / Orca 下根本不會產生 session 檔

# XDG 設定：data / history
export LESSHISTFILE="$XDG_DATA_HOME/.lesshst" # less history 檔案
export REDISCLI_HISTFILE="$XDG_DATA_HOME/.rediscli_history"
export HISTFILE="$XDG_DATA_HOME/.zsh_history" # zsh history 檔案
export COMPOSER_HOME="$XDG_DATA_HOME/composer" # 內含 auth.json 與 global 套件，屬 data（放 cache 會被清掉）

# 工具設定：Go
export GOPATH="$XDG_CACHE_HOME/go"
export GOCACHE="$GOPATH/cache"
# 通用 user bin，pipx（PIPX_BIN_DIR）也裝在此，PATH 另有一筆獨立項目
# 曾設為 /opt/gobin，但 /opt 屬 root，go install 一律 permission denied
export GOBIN="$HOME/.local/bin"
export GOMODCACHE="$GOPATH/mod-cache"
export GOTMPDIR="$GOPATH/tmp"

# 工具設定：Java
# Homebrew 的 openjdk 全是 keg-only（不 link 進 /opt/homebrew/bin），本機也沒有系統 JVM，
# 因此 java / javac / JAVA_HOME 都必須自己指定；陣列順序即優先級（先 17，未裝時退回不帶版號）
for _jdk in openjdk@17 openjdk; do
  [[ -x "/opt/homebrew/opt/$_jdk/bin/java" ]] || continue
  export JAVA_HOME="/opt/homebrew/opt/$_jdk"
  break
done
unset _jdk

# 工具設定：npm
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME/npm"
export NPM_CONFIG_PREFIX="$XDG_DATA_HOME/npm"

# 設定：PATH
# typeset -U 自動移除重複項目，保留第一次出現的順序
# 陣列順序即搜尋優先級，越前面越優先
export PNPM_HOME="$XDG_DATA_HOME/pnpm"
export BUN_INSTALL="$XDG_DATA_HOME/bun" # bin 與全域套件屬 data，不可放 cache（清快取會被砍）
export BUN_INSTALL_CACHE_DIR="$XDG_CACHE_HOME/bun/install/cache"
mkdir -p \
  "${NPM_CONFIG_USERCONFIG:h}" \
  "$NPM_CONFIG_CACHE" \
  "$NPM_CONFIG_PREFIX" \
  "$PNPM_HOME" \
  "$PNPM_HOME/bin" \
  "$BUN_INSTALL/bin" \
  "$GOBIN"
# fpath 一併去重：下方會 prepend 自訂補全目錄，重複 source .zshrc 時不該讓它無限累積
typeset -U path PATH fpath FPATH
path=(
  "$BUN_INSTALL/bin"
  "$PNPM_HOME/bin"
  "$PNPM_HOME"
  "$HOME/.antigravity/antigravity/bin"
  "/opt/homebrew/opt/curl/bin"
  "$DOTFILES/bin"
  "$HOME/.orbstack/bin"
  "$HOME/.local/bin"
  "$COMPOSER_HOME/vendor/bin"
  "$NPM_CONFIG_PREFIX/bin"
  $path
  # JetBrains Toolbox：維持最低優先級（原本是 PATH 尾端 append），避免遮蔽系統指令
  "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
)
# JDK 的 bin 只在偵測到 JAVA_HOME 時加入；不可直接寫進上面的陣列，
# 否則未安裝時會展開出空字串項目（空項目＝當前目錄，會被當成 PATH 搜尋範圍）
[[ -n "$JAVA_HOME" ]] && path=("$JAVA_HOME/bin" $path)
export PATH

# 設定：Shell 基本行為
# LANG 必須設：只設 LC_CTYPE 時部分 CLI（perl、python locale）會落回 C 而警告或誤判編碼
export LANG="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"
# 已有 VIMINIT 指定 vimrc，但 git commit / fc / less 走的是 EDITOR/VISUAL，需另外指定
export EDITOR="vim"
export VISUAL="vim"
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY="YES"

# 設定：互動行為（setopt）
# complete_in_word / always_to_end / 關 flowcontrol 已由 OMZL::completion.zsh 處理，不在此重設
setopt auto_cd                # 直接輸入目錄名即 cd
setopt interactive_comments   # 允許在 prompt 上用 # 註解（zsh 互動 shell 預設關閉）
setopt extended_glob          # 進階 glob：^排除、(#i)不分大小寫、a|b 等
setopt auto_pushd             # cd 自動壓入目錄堆疊，可用 cd -<TAB> 跳回
setopt pushd_ignore_dups      # 堆疊不留重複項
setopt pushd_silent           # pushd/popd 不印出整個堆疊

# 工具設定：fzf
# 接線（鍵位與 fzf-tab 樣式）在 snippet/fzf.zsh，必須延遲到 OMZ key-bindings 之後才載入；
# 這裡只放環境變數，讓 1 秒內手動執行 fzf 也吃得到設定。
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='--height 60% --layout=reverse --border --cycle --info=inline'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range :200 {}' --preview-window=right:60%"
export FZF_CTRL_R_OPTS='--reverse --preview-window=hidden'
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_ALT_C_OPTS="--preview 'eza -1 --icons --color=always {}'"

# 工具設定：bat 當 man pager
# macOS 的 man 走 mandoc（/usr/bin/man:1445 硬寫 MANDOC=/usr/bin/mandoc，本機沒有 groff），
# 輸出到非 tty 時用 overstrike（backspace）表示粗體：col -b 除去它得到純文字、-x 把 tab 轉空白，
# 再交給 bat -l man 重新上色。
# 不設 MANROFFOPT：那是 Linux man-db + groff 的變數，macOS 的 man 完全不讀
#（grep -c MANROFFOPT /usr/bin/man 為 0，A/B 實測輸出一致），設了只是誤導。
# 設了 MANPAGER 就必須拿掉 OMZP::colored-man-pages（見下方 zinit 區塊）：
# /usr/bin/man:1231 是 `if [ -z "$MANPAGER" ]` 才回退 PAGER，而該 plugin 只設 PAGER，必定失效。
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# 工具設定：zsh-autosuggestions
export ZSH_AUTOSUGGEST_USE_ASYNC="true"

# 工具設定：alias-tips
# 排除泛用的 g（git）：git merge / git add 這類提示由 snippet/aliasGit.zsh 的
# _git_fn_alias_tip 產生（function 形式的縮寫 alias-tips 認不出），避免同時印兩行
export ZSH_PLUGINS_ALIAS_TIPS_EXCLUDES="g"

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
  mkdir -p "${ZINIT_HOME:h}"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# zinit 設定：主題
zinit ice depth"1" # git clone depth
zinit light romkatv/powerlevel10k

# 本地設定檔：直接 source，不可用 zinit snippet
# zinit snippet 會把本地檔「複製」進 ZINIT[SNIPPETS_DIR] 並固定使用那份副本，
# 之後改 $DOTFILES 下的源檔不會生效，非得 zinit update 才同步。
# 實測踩過：在 snippet/history.zsh 新增 setopt 後，新終端仍讀到 7 月的舊副本。
source "$DOTFILES/p10k.zsh"
source "$DOTFILES/snippet/history.zsh"
source "$DOTFILES/snippet/aliasConfig.zsh"

# OMZ 備註：可選 plugins
# OMZP::safe-paste        避免貼上後直接執行
# OMZP::colored-man-pages 已刻意不用：它只設 PAGER，而 /usr/bin/man:1231 只在 MANPAGER 為空時
#                         才回退 PAGER，上面設了 MANPAGER=bat 後它必定失效，只剩多一次 env fork
# OMZP::command-not-found 顯示指令安裝提示，但會拖慢 command not found 回應
# OMZP::sudo              Operation not permitted 時，按兩次 esc 自動補 sudo

# 補全：自訂補全目錄入 fpath，讓 compinit 掃到其中的 _xxx 檔案（如 completion/_docker）
# 必須早於 compinit；completion.zsh 不是 _ 開頭，compinit 會忽略，由下方 atload 單獨 source
fpath=("$DOTFILES/completion" $fpath)

# 補全：compinit 初始化（由下方 fzf-tab 的 atinit 呼叫，一次性，跑完自我卸載）
#
# ZINIT[COMPINIT_OPTS]=-C 的坑：-C 是「完全信任既有 zcompdump，不掃 fpath 有沒有新的 _xxx」。
# 實測（zsh -f + 獨立 dump）新增 fp/_zzztest 後：compinit -C → _comps 沒有它；不加 -C → 有。
# 所以只要 dump 已存在，新加進 completion/ 的補全檔就靜默失效（例如換台機器 git pull 之後）。
_zsh_compinit_once() {
  local dump="${ZINIT[ZCOMPDUMP_PATH]}"
  # 直接刪 dump 而不是只拿掉 -C：compinit 判斷 dump 過期只比對「fpath 內 _xxx 的檔案數 +
  # zsh 版本」（compinit:490），不比對清單內容。實測把 _bbbcmd 換成 _cccmd（數量不變）後，
  # 就算跑不帶 -C 的完整 compinit 也是 cccmd=無、已刪的 bbbcmd=_bbbcmd 還在、dump mtime 不動；
  # 刪掉 dump 才會真正重建（實測 cccmd=_cccmd、bbbcmd=無）。改名一個補全檔就會踩到。
  # 觸發條件：
  #   dump 為 0 byte → -C 會照單全收，實測 `compinit -C -d <0 byte>` 的 _comps 總數為 0，
  #     連 _git 都沒有而且不報錯（與本檔開頭修掉的 brew shellenv 空快取是同型毒化）。
  #     dump 不存在本身不危險（compinit:486 是 `if [[ -f ]]`，直接落到完整掃描），
  #     這裡用 ! -s 一併收進來只是省一個分支。
  #   completion/ 比 dump 新 → 有新增、刪除或改名補全檔。只監測這一個目錄：監整個 fpath
  #     每次啟動要多幾十次 stat，不值得。zinit 那邊新增的 _xxx 由 es 保證（它會 rm dump 再
  #     exec $SHELL）；brew 裝出來的新補全沒人觸發，得自己跑一次 es。
  # 重建只多約 18ms，且在 prompt 之後的延遲區塊，感知不到；compdump 寫出的 mtime 即是當下，
  # 所以下次啟動 dump 自然比目錄新，會自動退回 -C，不需要額外 touch。
  [[ ! -s "$dump" || "$DOTFILES/completion" -nt "$dump" ]] && command rm -f "$dump"
  ZINIT[COMPINIT_OPTS]=-C
  zicompinit
  zicdreplay
  unfunction _zsh_compinit_once
}

# zinit 設定：核心互動功能（即時載入）
# 順序有硬性依賴，不可調換：
#   1. zsh-completions 先入 fpath（blockf 阻止 plugin 亂改 fpath）
#   2. fzf-tab 的 atinit 做單次 zicompinit —— fzf-tab 必須在 compinit 之後、
#      且在任何會包裝 zle widget 的 plugin（F-Sy-H、autosuggestions）之前載入
#   3. atload 接自訂 compdef：必須等 compinit 定義出 compdef 才能呼叫
#      （實測在 .zshrc 頂層直接 source 會噴 command not found: compdef）
#   4. F-Sy-H → autosuggestions
zinit wait lucid depth"1" for \
  blockf \
    zsh-users/zsh-completions \
  atinit"_zsh_compinit_once" \
  atload"source \"\$DOTFILES/completion/completion.zsh\"" \
    Aloxaf/fzf-tab \
  zdharma-continuum/fast-syntax-highlighting \
  atload"!_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions

# zinit 設定：常用工具（延遲載入）
# 註：不要加 zsh-users/zsh-history-substring-search —— 該 plugin 本體不含任何 bindkey，
# 而下方 OMZL::key-bindings.zsh 會把 ↑↓ 綁給 up-line-or-beginning-search（前綴搜尋），
# 載入順序在後必定覆蓋，等於載了一個永遠按不到的 plugin。
#
# z.lua 的 atload'zicdreplay' 是必要的，不是保險：zinit 的 compdef 只是收集用的 stub，
# 真正註冊靠 zicdreplay，而上面那次 replay 在 wait'' 就跑完了。z.lua 在這裡才載入，
# 它自己呼叫的 4 筆 compdef（含 j=_zlua）會卡在 ZINIT_COMPDEF_REPLAY 沒人處理 ——
# 實測 j 因此完全沒有補全。掛在 z.lua 自己身上而非別的 plugin，才不會因為那個 plugin
# 被移除就靜默退化。（zicdreplay 不清空佇列，重播後仍留 4 筆，但 compdef 是覆蓋語意，冪等。）
zinit wait'1' lucid depth"1" light-mode for \
  djui/alias-tips \
  atload'zicdreplay' \
    skywind3000/z.lua \
  OMZL::completion.zsh \
  atload"source \"\$DOTFILES/snippet/fzf.zsh\"" \
    OMZL::key-bindings.zsh \
  OMZP::safe-paste \
  OMZP::sudo

# zinit 設定：較少使用工具（延遲載入）
zinit wait'2' lucid depth"1" light-mode for \
  paulirish/git-open

# export OPENCODE_DISABLE_CLAUDE_CODE=1  # 停用 opencode 內建的 claude code 整合（衝突時啟用）

