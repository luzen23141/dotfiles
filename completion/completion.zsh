# 1password cli提示
compdef _op op
_op() {
    # 移除佔位函數，載入真正的補全實作後重新呼叫
    unfunction _op
    eval "$(op completion zsh)"
    compdef _op op
    _op "$@"
}

compdef _s s
_s() {
  local -a folders
  folders=(~/.config/sshAlias/*(N:t))
  _describe 'folders' folders
}

# ── git 系列的 alias / function / bin 腳本 ────────────────────
# 語法 `compdef _git 短名=git-子命令`：讓 _git 直接套用該子命令的補全器，
# 所以 `gc feat<TAB>` 補的是分支名，而不是 git 的子命令清單。
# 只有「參數語意與某個 git 子命令一致」的才列入；無參數或只吃自由文字的
# （gsu / gsur / grh / gcm / ga. / gai / gito / gct / gcam / gcaim / gpr / groa / grom）
# 刻意不加，補出無意義的候選比沒有補全更糟。
compdef g=git

# alias → snippet/aliasGit.zsh
compdef _git gc=git-checkout    # git checkout
compdef _git gb=git-branch      # git branch
compdef _git gba=git-branch     # git branch -a
compdef _git gp=git-push        # git push
compdef _git gpf=git-push       # git push --force-with-lease
compdef _git gl=git-pull        # git pull -p
compdef _git gs=git-status      # git status
compdef _git grv=git-remote     # git remote -v
compdef _git grs=git-restore    # git restore --staged
compdef _git gwl=git-worktree   # git worktree list
compdef _git gwp=git-worktree   # git worktree prune

# function → snippet/aliasGit.zsh
compdef _git gm=git-merge       # 會把存在的 origin/<branch> 改寫，補分支名正是所需
compdef _git ga=git-add         # git add "${1:-.}"

# bin 腳本：gca / gcd 都是 git checkout <固定分支> "$@"，剩餘參數與 checkout 相同
compdef _git gca=git-checkout
compdef _git gcd=git-checkout

# ── eza 系列 alias（snippet/aliasConfig.zsh）────────────────────
# 這幾個都是 eza 加不同旗標，補全需求完全相同。
# 「短名=命令」形式會去查 _comps[目標]，查不到就把 `compdef: unknown command` 印在 prompt 上；
# 本檔在 compinit 之後、prompt 之後才跑，eza 沒裝時會疊四行錯誤，所以先確認再註冊。
(( $+_comps[eza] )) && compdef la=eza laa=eza las=eza laas=eza

# ── docker compose：dcu / dcd 補服務名 ─────────────────────────
# 刻意純文字解析 compose 檔，不用 `docker compose config --services`：
# 後者會連線 daemon，補全時把 OrbStack 叫起來是不可接受的副作用。
_dc_services() {
  local dir="${DOCKER_COMPOSE_DIR:-$HOME/Code/dockerCompose}" f
  local -a services
  for f in "$dir"/docker-compose.yml "$dir"/docker-compose.yaml; do
    [[ -r "$f" ]] || continue
    # 取 services: 區塊下第一層鍵名，遇到下一個頂層鍵就停。
    # 縮排寬度不寫死：以區塊內第一行的縮排當基準（不是第一個「純鍵」），
    # 否則第一個服務只要帶 anchor（web: &webbase）或行內值（web: nginx）就不算純鍵，
    # 基準會掉到下一層的嵌套鍵上 —— 實測會輸出 volumes 而讓 web、db 消失，
    # 補出看起來像真的錯誤候選比拿到空清單更糟。
    # services: 後允許接註解，鍵名後也允許接值，這兩種寫法都不會再靜默回傳空清單。
    services=(${(f)"$(awk '
      function ind(s) { match(s, /^[[:space:]]*/); return RLENGTH }
      /^services:([[:space:]]|#|$)/ { inblock = 1; next }
      inblock && /^[^[:space:]#]/ { inblock = 0; next }
      inblock && !base && /^[[:space:]]+[^[:space:]#]/ { base = ind($0) }
      inblock && base && ind($0) == base && /^[[:space:]]+[a-zA-Z0-9_.-]+:([[:space:]]|$)/ {
        sub(/:.*$/, ""); gsub(/[[:space:]]/, ""); print
      }
    ' "$f")"})
    break
  done
  (( $#services )) || return 1
  _describe -t services 'compose 服務' services
}
compdef _dc_services dcu
compdef _dc_services dcd
