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

# git commit且push
function gcp() {
  git commit -am "$1" && git push -u origin "$(git rev-parse --abbrev-ref HEAD)"
}
function ga() {
  git add "$1" && git status
}

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

#function gitpr() {
#  git open origin master --suffix compare/master..."$(git rev-parse --abbrev-ref HEAD)"
#}

# rebase master
# function grm() {
#   current="$(git rev-parse --abbrev-ref HEAD)"
#   git checkout master && git pull && git checkout "$current" && git rebase origin/master && git push
# }
