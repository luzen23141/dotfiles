## php多版本管理
# 動態生成 PHP 版本別名的函數
_setup_php_version_aliases() {
  local versions=("7.3" "7.4" "8.0" "8.1" "8.3")
  
  for version in "${versions[@]}"; do
    local short_ver="${version//./}"  # 移除點號，例如 7.3 -> 73
    local php_path="$HOMEBREW_PREFIX/opt/php@$version/bin"
    
    # 檢查該版本是否已安裝
    if [[ -d "$php_path" ]]; then
      # PHP 別名
      alias "php${short_ver}=${php_path}/php"
      # PECL 別名
      alias "pecl${short_ver}=${php_path}/pecl"
      # Composer 別名
      alias "composer${short_ver}=${php_path}/php \$HOMEBREW_PREFIX/bin/composer"
      # Hyperf 框架別名
      alias "hy${short_ver}=${php_path}/php bin/hyperf.php"
    fi
  done
}

# 執行別名設置
_setup_php_version_aliases

# Hyperf 框架預設別名
alias hy='php bin/hyperf.php'
