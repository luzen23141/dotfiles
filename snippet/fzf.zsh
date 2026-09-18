# fzf 互動接線（鍵位 + fzf-tab 補全樣式）
#
# 本檔不可提前載入：.zshrc 用 OMZL::key-bindings.zsh 的 atload 觸發，
# 因為下列兩者都會蓋掉這裡的設定，必須確保它們先跑完：
#   OMZL::key-bindings.zsh → 把 ^R 綁給 history-incremental-search，晚載入就吃掉 fzf 的 ^R
#   OMZL::completion.zsh   → 設 zstyle ':completion:*:*:*:*:*' menu select，與 fzf-tab 互斥
# 環境變數（FZF_*）不在此處，統一放 .zshrc 的「工具設定：fzf」以便即時生效。

# 只載入 key-bindings（^R 歷史、^T 檔案、Alt-C 目錄），刻意不載入 fzf 的 completion.zsh：
# 那份會把 ^I（TAB）綁成 fzf-completion，蓋掉 fzf-tab 的 fzf-tab-complete，
# 等於裝了 fzf-tab 卻按不到（實測 bindkey '^I' 會顯示 fzf-completion）。
# `**<TAB>` 觸發器因此失效，但 fzf-tab 已在所有補全情境提供更完整的替代。
# 加存在性判斷：這是 keg 內部路徑（不是 brew link 出來的 bin），fzf 沒裝或改版換路徑時
# 直接 source 會在每次開終端噴錯，而 fzf 只是加分功能，不該讓它拖垮 shell 啟動。
_fzf_keybindings="${HOMEBREW_PREFIX:-/opt/homebrew}/opt/fzf/shell/key-bindings.zsh"
[[ -r "$_fzf_keybindings" ]] && source "$_fzf_keybindings"
unset _fzf_keybindings

# 這裡刻意不再 bindkey '^I'：fzf-tab.zsh:397-398 載入時已綁好 emacs 與 viins 兩個 keymap，
# 而本檔之前唯一會搶 ^I 的是 OMZL::completion.zsh，它需要 COMPLETION_WAITING_DOTS
#（全 repo 沒有任何地方設）。補一行不帶 -M 的 bindkey 只蓋得到 main，真出事時 vicmd 仍是壞的，
# 屬於看似安全其實無效的防禦。真正的風險點是上面那段「不要載入 fzf 的 completion.zsh」。

# ── fzf-tab ───────────────────────────────────────────────────
# 原生選單與 fzf-tab 互斥，且必須用與 OMZ 相同的 pattern 才蓋得掉（zstyle 依 pattern 特異性匹配）
zstyle ':completion:*' menu no
zstyle ':completion:*:*:*:*:*' menu no

# fzf-tab 預設不吃 FZF_DEFAULT_OPTS（README:119），要共用得明確 opt-in，
# 否則得在 fzf-flags 再抄一份 flag，兩邊各改一次遲早不同步。
zstyle ':fzf-tab:*' use-fzf-default-opts yes
# 不要在這裡設 --height：lib/-ftb-fzf:89 會依候選數量算出動態高度
#   --height=$(( min(max(候選數, fzf-min-height), LINES/3*2) ))
# 而 fzf-flags 在 :97 是最後才附加的參數，fzf 對重複 flag 取最後一個，
# 一設死就等於把「只有兩個候選時視窗只佔幾行」這個行為換成永遠固定高度。
# FZF_DEFAULT_OPTS 裡的 --height 60% 不受影響：:89 的命令列參數本來就贏過環境變數。
# 用 < > 在補全群組（檔案／目錄／別名…）之間切換
zstyle ':fzf-tab:*' switch-group '<' '>'

# 預覽：目錄用 eza 列內容，檔案用 bat 上色（兩者皆已由 Brewfile 安裝）
# 不必為 j 設預覽：j 走 z.lua 自帶的 fzf 整合（_zlua_zsh_fzf_complete 自己開 fzf 再直接 cd，
# 全程沒有 compadd），候選根本沒進 completion system，fzf-tab 不會被呼叫。
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --icons --color=always $realpath'
zstyle ':fzf-tab:complete:(cat|bat|vim|vimp|glow|less):*' \
  fzf-preview 'bat --color=always --style=numbers --line-range :200 $realpath'
# kill/ps：預覽該 PID 的完整指令列
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' \
  fzf-preview 'ps -p $word -o pid,ppid,%cpu,%mem,command'
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-flags --preview-window=down:4:wrap
# git：預覽 diff / log
zstyle ':fzf-tab:complete:git-(add|diff|restore):*' \
  fzf-preview 'git diff --color=always $word'
zstyle ':fzf-tab:complete:git-(checkout|switch|branch):*' \
  fzf-preview 'git log --oneline --graph --color=always -20 $word'
