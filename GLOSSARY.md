# Glossary

## 主分支 (main branch)
一個 repo 最終整合與發 PR 的目標分支。由 repo 明確設定決定；未設定時依候選順序取第一個存在的分支。
不同於 git 的「初始分支」(`init.defaultBranch`)：後者只決定 `git init` 新 repo 時的分支名，與既有 repo 的主分支無關。

## 開發分支 (dev branch)
團隊日常整合用、尚未進主分支的共用分支。決定方式同主分支，候選順序獨立。

## 候選分支 (branch candidates)
未明確設定時，依序嘗試的分支名稱清單。分支「存在」指本地或 `origin` 上有同名分支。
明確設定的分支不存在時視為錯誤，不退回候選分支。
