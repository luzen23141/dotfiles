#! /bin/zsh

exit 0

iCloud_folder=$HOME/iCloud
hash_file=$HOME/dotfiles/log/backupIcloudHash

echo "$(date "+%Y-%m-%d %H:%M:%S") 開始同步bash"

# 讀取上次的哈希值
if [ -f "$hash_file" ]; then
  previous_hash=$(cat "$hash_file")
else
  previous_hash=""
fi

# 計算當前資料夾的哈希值
current_hash=$(find -L "$iCloud_folder" -type f -exec shasum -a 256 {} + | awk '{print $1}' | sort | shasum -a 256 | awk '{print $1}')

# 比較哈希值
if [ "$current_hash" != "$previous_hash" ]; then
  export PATH="/usr/local/bin:$PATH"
  rclone sync "$iCloud_folder" gd_luzen23141:/iCloud -v

  # 檢查 rclone sync 是否成功
  if [ $? -eq 0 ]; then
    # 同步成功，儲存當前的哈希值
    echo "$current_hash" > "$hash_file"
  else
    # 同步失敗，顯示錯誤訊息
    echo "Failed to sync the folders."
  fi
else
  echo "hash相同，未執行同步"
fi

echo -e "\n"
