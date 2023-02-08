# 1password cli提示
compdef _op op
_op() {
    # 移除占位函数
    unfunction _op
    eval "$(op completion zsh)";
    _op "$@"
}

compdef _s s
_s() {
  local folders
  folders=($(ls ~/.config/sshAlias))
  _describe 'folders' folders
}
