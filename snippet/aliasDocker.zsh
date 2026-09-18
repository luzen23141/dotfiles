# Docker 相關別名
alias dc="docker_check && docker compose"
alias dp="docker_check && docker ps"

# Laradock 相關別名（用 function 才能把服務名傳進 compose，例如 dcu nginx）
# 目錄抽成變數：completion/completion.zsh 的 _dc_services 也要讀同一個 compose 檔來補服務名
# 不 export：只有本 shell 的 alias 與補全函式要讀，subshell 會自然繼承，不必污染子程序環境
typeset -g DOCKER_COMPOSE_DIR="${DOCKER_COMPOSE_DIR:-$HOME/Code/dockerCompose}"
dcd() {
  (cd "$DOCKER_COMPOSE_DIR" && docker compose down "$@")
}
dcu() {
  (cd "$DOCKER_COMPOSE_DIR" && docker_check && docker compose up -d "$@")
}
function docker_check() {
  if ! docker ps > /dev/null 2>&1; then
    open -a OrbStack
    local i=0
    while ! docker ps > /dev/null 2>&1 && [ $i -lt 15 ]; do
      sleep 1
      i=$((i + 1))
    done
  fi
}