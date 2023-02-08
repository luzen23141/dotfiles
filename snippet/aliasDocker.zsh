# docker
alias dc="docker-check && docker compose"
alias dp="docker-check && docker ps"

# laradock
alias dcd="cd ~/Code/dockerCompose && docker compose down"
alias dcu="cd ~/Code/dockerCompose && docker-check && docker compose up -d"
alias docker-check='
if ! docker ps > /dev/null 2>&1; then
  /Applications/OrbStack.app/Contents/MacOS/OrbStack &
  sleep 5
fi'