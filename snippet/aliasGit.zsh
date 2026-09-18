# Git 相關別名
alias g="git"
alias gp="git push"
alias gpf="git push --force-with-lease"
alias gl="git pull -p"  # -p 拉取時清除遠端已刪除分支的本地追蹤分支
alias gc="git checkout"
alias gb="git branch"
# gm alex → git merge origin/alex（僅在 origin/alex 確實存在時改寫）
# 逐一檢查「非 flag 的參數」，故 gm --no-ff alex、gm alex --no-edit 都會走 origin；
# tag / SHA / 純本地分支（無同名 origin/）則原樣傳遞。
# value_opts 是會吃下一個參數當值的選項，需跳過以免把 -m 的訊息當成分支名改寫。
function gm() {
  local -a args=("$@") value_opts=(-m -s -X --strategy --strategy-option --into-name)
  local i=1 opts_ended=0
  while (( i <= $#args )); do
    if (( ! opts_ended )) && [[ "${args[i]}" == -* ]]; then
      [[ "${args[i]}" == -- ]] && opts_ended=1
      (( ${value_opts[(Ie)${args[i]}]} )) && (( i++ ))
      (( i++ ))
      continue
    fi
    git rev-parse --verify --quiet "origin/${args[i]}" >/dev/null 2>&1 \
      && args[i]="origin/${args[i]}"
    (( i++ ))
  done
  git merge "${args[@]}"
}
alias gs="git status"
alias grv="git remote -v"
alias gcb="git clear branch"
alias gsu="git submodule update --init --recursive"
alias gwl="git worktree list"
alias gwp="git worktree prune"

# 將全域 gitignore 合併進本 repo 的 exclude（已存在的行不重複附加）
function gai() {
  local global_ignore="${XDG_CONFIG_HOME:-$HOME/.config}/.gitignore_global"
  local exclude

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "錯誤：目前不在 Git 倉庫中。" >&2
    return 1
  fi
  if [[ ! -f "$global_ignore" ]]; then
    echo "錯誤：找不到 $global_ignore" >&2
    return 1
  fi

  exclude="$(git rev-parse --git-path info/exclude)"
  mkdir -p "$(dirname "$exclude")"
  touch "$exclude"

  # 先載入既有 exclude，之後以 O(1) 查重
  typeset -A existing
  local line added=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    existing[$line]=1
  done < "$exclude"

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ -z "${existing[$line]}" ]]; then
      print -r -- "$line" >> "$exclude"
      existing[$line]=1
      added=$((added + 1))
    fi
  done < "$global_ignore"

  echo "已合併 $global_ignore → $exclude（新增 $added 行）"
  command cat "$exclude"
}

# 開啟 PR 頁面（讀取 .aConfig main_branch，預設 master）
function gito() {
  : "${DOTFILES:=$HOME/dotfiles}"
  source "$DOTFILES"/helperFunc/envHelper
  git open origin "$(get_env_value main_branch master)"
}
alias grh="git reset 'HEAD^'"
alias gba="git branch -a"
alias gsur="git submodule update --recursive --remote"
alias grs="git restore --staged"
alias gcm="git_check_mainBranch"
alias ga.="git add . && git status"

function ga() {
  git add "${1:-.}" && git status
}

function gma() {
  : "${DOTFILES:=$HOME/dotfiles}"
  source "$DOTFILES"/helperFunc/envHelper
  local mine_branch
  mine_branch="$(get_env_value mine_branch alex)"
  echo "執行指令 git merge origin/$mine_branch --no-edit"
  git merge origin/"$mine_branch" --no-edit

  local merge_check
  merge_check="$(get_env_value merge_mine_check "")"
  if [ -n "$merge_check" ]; then
    local cmd_parts=("${(@z)merge_check}")
    echo "執行指令 $merge_check"
    "${cmd_parts[@]}"
  fi
}

# 快速建立或更新 tmp commit
alias gct="git_commit_tmp"
function git_commit_tmp() {
  # 取得當前用戶的 git email
  local current_user
  current_user=$(git config user.email)
  
  # 取得最新的 commit message 和 author email
  local last_commit_msg last_commit_author
  last_commit_msg=$(git log -1 --pretty=%s 2>/dev/null)
  last_commit_author=$(git log -1 --pretty=%ae 2>/dev/null)
  
  # 先 add 所有改動
  git add .
  
  # 檢查是否有改動需要 commit
  if git diff --cached --quiet; then
    echo "沒有任何改動需要 commit"
    return 0
  fi
  
  # 如果最新的 commit 是 "tmp"、作者是本人且尚未推上遠端，才用 amend
  local current_branch remote_has_tmp=0
  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if git rev-parse --verify "origin/$current_branch" >/dev/null 2>&1; then
    if git merge-base --is-ancestor HEAD "origin/$current_branch"; then
      remote_has_tmp=1
    fi
  fi

  if [[ "$last_commit_msg" == "tmp" ]] && [[ "$last_commit_author" == "$current_user" ]] && [[ $remote_has_tmp -eq 0 ]]; then
    echo "更新現有的 tmp commit (amend)"
    git commit --amend --no-edit
  else
    echo "建立新的 tmp commit"
    git commit -m "tmp"
  fi
}

# alias-tips 只比對 `alias` 表與 git alias（function 只被它用來「取消」提示，
# 見 alias-tips.plugin.zsh 把 functions grep 成名稱行），所以 function 形式的
# gm / ga 打完長指令不會有提示。以下用同一個 preexec 機制自行補上。
# 對應的 alias-tips 泛用提示（g merge …）已在 .zshrc 用 EXCLUDES="g" 關掉，避免重複兩行。
typeset -gA GIT_FN_ALIAS_TIPS=(
  'git merge' gm
  'git add'   ga
)
function _git_fn_alias_tip() {
  local long short
  for long short in "${(kv)GIT_FN_ALIAS_TIPS[@]}"; do
    [[ "$1" == "$long" || "$1" == "$long "* ]] || continue
    print -P "%F{blue}${ZSH_PLUGINS_ALIAS_TIPS_TEXT:-Alias tip: }%B${short}${1#$long}%b%f"
    return 0
  done
}
autoload -Uz add-zsh-hook
add-zsh-hook preexec _git_fn_alias_tip
