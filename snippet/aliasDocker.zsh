# Docker 相關別名
alias dc="docker_check && docker compose"
alias dp="docker_check && docker ps"

# Laradock 相關別名
alias dcd="(cd ~/Code/dockerCompose && docker compose down)"
alias dcu="(cd ~/Code/dockerCompose && docker_check && docker compose up -d)"
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