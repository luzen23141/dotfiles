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
