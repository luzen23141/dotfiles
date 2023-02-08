# 1password cli提示
compdef _op op
_op() {
    # 移除占位函数
    unfunction _op
    eval "$(op completion zsh)";
    _op "$@"
}
