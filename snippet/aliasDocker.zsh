# Docker 相關別名
alias dc="docker-check && docker compose"
alias dp="docker-check && docker ps"

# Laradock 相關別名
alias dcd="cd ~/Code/dockerCompose && docker compose down"
alias dcu="cd ~/Code/dockerCompose && docker-check && docker compose up -d"
function docker-check() {
  if ! docker ps > /dev/null 2>&1; then
    /Applications/OrbStack.app/Contents/MacOS/OrbStack &
    local i=0
    while ! docker ps > /dev/null 2>&1 && [ $i -lt 15 ]; do
      sleep 1
      i=$((i + 1))
    done
  fi
}