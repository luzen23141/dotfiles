# 歷史記錄時間格式
HIST_STAMPS="%Y-%m-%d %H:%M:%S"

# 歷史記錄包裝函數
function history {
  if [[ $# -eq 0 ]]; then
    # 無參數：從第 1 筆開始顯示完整歷史
    builtin fc -t "$HIST_STAMPS" -l 1
  else
    # 有參數：以自訂格式執行 fc -l
    builtin fc -t "$HIST_STAMPS" -l "$@"
  fi
}

# 歷史記錄檔案設定
HISTSIZE=100000
SAVEHIST=100000

# 歷史記錄行為設定
# https://zsh.sourceforge.io/Doc/Release/Options.html#History
setopt extended_history       # 記錄指令的執行時間戳
setopt hist_expire_dups_first # HISTFILE 超過 HISTSIZE 時優先刪除重複項
# setopt hist_ignore_dups       # 已由 HIST_IGNORE_ALL_DUPS 取代（只忽略相鄰重複 vs 全部重複）
setopt HIST_IGNORE_ALL_DUPS   # 如果重複的話，刪除舊的指令
setopt hist_ignore_space      # 忽略以空白開頭的指令
setopt hist_verify            # 展開歷史後先顯示指令讓使用者確認再執行
setopt share_history          # 跨 shell session 共享歷史記錄
