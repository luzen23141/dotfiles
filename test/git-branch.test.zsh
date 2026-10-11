#!/bin/zsh
# 主分支／開發分支解析的行為測試：在 /tmp 暫存 repo 中實際執行 gcm / gcd / a-set
# 執行：zsh test/git-branch.test.zsh

DOTFILES=${0:A:h:h}
export DOTFILES
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
BIN=$DOTFILES/bin
fail=0

# 建立 repo：第一個參數為初始分支，其餘為額外的本地分支
new_repo() {
  local dir=$(mktemp -d /tmp/gitbranch.XXXXXX)
  git -C "$dir" init -q -b "$1"
  git -C "$dir" commit -q --allow-empty -m init
  shift
  local b
  for b in "$@"; do git -C "$dir" branch "$b"; done
  git -C "$dir" checkout -q --detach
  echo "$dir"
}

current() { git -C "$1" rev-parse --abbrev-ref HEAD; }

check() {
  if [[ "$2" == "$3" ]]; then
    echo "ok   $1"
  else
    echo "FAIL $1: 預期 [$3]，實際 [$2]"
    fail=1
  fi
}

r=$(new_repo master)
(cd "$r" && "$BIN"/gcm -q)
check "只有 master 時 gcm 切到 master" "$(current "$r")" master

r=$(new_repo master main)
(cd "$r" && "$BIN"/gcm -q)
check "main 與 master 並存時 gcm 優先 main" "$(current "$r")" main

r=$(new_repo master)
remote=$(new_repo main)
git -C "$r" remote add origin "$remote"
git -C "$r" fetch -q origin
(cd "$r" && "$BIN"/gcm -q)
check "僅 origin/main 存在時 gcm 建立追蹤分支 main" "$(current "$r")" main

r=$(new_repo master develop)
(cd "$r" && "$BIN"/gcd -q)
check "只有 develop 時 gcd 切到 develop" "$(current "$r")" develop

r=$(new_repo master dev)
git -C "$r" config a.devBranch staging
(cd "$r" && "$BIN"/gcd -q 2>/dev/null)
check "設定的開發分支不存在時報錯" "$?" 1
check "設定的開發分支不存在時不切換" "$(current "$r")" HEAD

r=$(new_repo trunk)
(cd "$r" && "$BIN"/gcm -q 2>/dev/null)
check "沒有任何候選主分支時報錯" "$?" 1

r=$(new_repo master release)
mkdir "$r/sub"
git -C "$r" checkout -q release
(cd "$r/sub" && "$BIN"/a-set m >/dev/null && git checkout -q --detach && "$BIN"/gcm -q)
check "子目錄 a set m 後 gcm 切到該分支" "$(current "$r")" release

exit $fail
