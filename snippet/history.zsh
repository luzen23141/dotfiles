## History wrapper
function history {
  if [[ $# -eq 0 ]]; then
    # if no arguments provided, show full history starting from 1
    builtin fc -t '$HIST_STAMPS' -l 1
  else
    # otherwise, run `fc -l` with a custom format
    builtin fc -t '$HIST_STAMPS' -l "$@"
  fi
}

#alias history="omz_history -t '$HIST_STAMPS'"
## History file configuration
HISTSIZE=100000
SAVEHIST=20000

# History command configuration
# https://zsh.sourceforge.io/Doc/Release/Options.html#History
setopt extended_history       # record timestamp of command in HISTFILE
setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
# setopt hist_ignore_dups       # ignore duplicated commands history list
setopt HIST_IGNORE_ALL_DUPS   # 如果重複的話，刪除舊的指令
setopt hist_ignore_space      # ignore commands that start with space
setopt hist_verify            # show command with history expansion to user before running it
setopt share_history          # share command history data
