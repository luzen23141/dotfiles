# Git 相關別名
alias g="git"
alias gp="git push"
alias gpf="git push --force-with-lease"
alias gl="git pull -p"  # -p 拉取時清除遠端已刪除分支的本地追蹤分支
alias gc="git checkout"
alias gb="git branch"
alias gm="git merge"
alias gs="git status"
alias grv="git remote -v"
alias gcb="git clear branch"
alias gsu="git submodule update --init --recursive"
alias gai="command cat ~/.config/.gitignore_global >> .git/info/exclude && cat .git/info/exclude"

# 開啟 PR 頁面（讀取 .aConfig main_branch，預設 master）
function gito() {
  source "$DOTFILES"/helperFunc/configHelper
  git open origin "$(getAConfig main_branch master)"
}
alias grh="git reset HEAD^"
alias gba="git branch -a"
alias gsur="git submodule update --recursive --remote"
alias grs="git restore --staged"
alias gcm="git_check_mainBranch"
alias ga.="git add . && git status"

function ga() {
  git add "${1:-.}" && git status
}

function gma() {
  source "$DOTFILES"/helperFunc/configHelper
  local mine_branch
  mine_branch="$(getAConfig mine_branch alex)"
  echo "執行指令 git merge origin/$mine_branch --no-edit"
  git merge origin/"$mine_branch" --no-edit

  local merge_check
  merge_check="$(getAConfig merge_mine_check "")"
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


