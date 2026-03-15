# ============================================
# FFmpeg 共用輔助函式
# ============================================

[[ -n "$_FFMPEG_HELPER_LOADED" ]] && return 0
_FFMPEG_HELPER_LOADED=1

# 格式化檔案大小
_ffmpeg_format_size() {
  local size=$1
  if [ "$size" -gt 1073741824 ]; then
    echo "$(echo "scale=2; $size / 1073741824" | bc)GB"
  elif [ "$size" -gt 1048576 ]; then
    echo "$(echo "scale=2; $size / 1048576" | bc)MB"
  elif [ "$size" -gt 1024 ]; then
    echo "$(echo "scale=2; $size / 1024" | bc)KB"
  else
    echo "${size}B"
  fi
}

# 顯示錯誤訊息並返回
_ffmpeg_error() {
  echo ""
  echo "❌ 錯誤：$1"
  [ -n "$2" ] && echo "   $2"
  echo ""
  return 1
}

# 顯示警告訊息
_ffmpeg_warn() {
  echo "⚠️  警告：$1"
  [ -n "$2" ] && echo "   $2"
}

# 檢查必要命令是否存在
_ffmpeg_check_dependencies() {
  local missing_cmds=()
  
  command -v ffmpeg &> /dev/null || missing_cmds+=("ffmpeg")
  command -v ffprobe &> /dev/null || missing_cmds+=("ffprobe")
  command -v bc &> /dev/null || missing_cmds+=("bc")
  
  if [ ${#missing_cmds[@]} -gt 0 ]; then
    echo ""
    echo "❌ 錯誤：缺少必要的命令"
    echo ""
    for cmd in "${missing_cmds[@]}"; do
      echo "   • $cmd"
    done
    echo ""
    echo "💡 安裝方法："
    echo "   brew install ffmpeg bc"
    echo ""
    return 1
  fi
  return 0
}

# 計算兩個影片的 SSIM 和 PSNR
_ffmpeg_calculate_quality() {
  # 強制禁用調試輸出
  set +x
  {
    setopt localoptions 2>/dev/null
    unsetopt xtrace verbose 2>/dev/null
  } 2>/dev/null
  
  local reference="$1"
  local comparison="$2"
  
  # 建立臨時檔案儲存 ffmpeg 輸出
  local temp_output
  temp_output=$(mktemp)
  
  # 執行 ffmpeg 並捕獲輸出（隱藏進度信息）
  ffmpeg -hide_banner -loglevel info -i "$reference" -i "$comparison" -lavfi "[0:v]setpts=PTS-STARTPTS[v0];[1:v]setpts=PTS-STARTPTS[v1];[v0][v1]ssim;[0:v]setpts=PTS-STARTPTS[v0];[1:v]setpts=PTS-STARTPTS[v1];[v0][v1]psnr" -f null - > "$temp_output" 2>&1
  
  # 提取 SSIM 平均值
  local ssim_avg
  ssim_avg=$(grep "SSIM" "$temp_output" | grep "All:" | tail -1 | sed -n 's/.*All:\([0-9.]*\).*/\1/p')
  
  # 提取 PSNR 平均值
  local psnr_avg
  psnr_avg=$(grep "PSNR" "$temp_output" | grep "average:" | tail -1 | sed -n 's/.*average:\([0-9.]*\).*/\1/p')
  
  # 清理臨時檔案（command rm 刻意繞過 trash alias）
  command rm -f "$temp_output"
  
  # 返回結果（用空格分隔）
  echo "${ssim_avg:-0} ${psnr_avg:-0}"
}

# 驗證速度倍率參數（atempo 限制 0.5-100.0）
# 用法：_ffmpeg_validate_speed <value>
# 回傳 0=合法，1=不合法（已印出錯誤訊息）
_ffmpeg_validate_speed() {
  local val="$1"
  if ! [[ "$val" =~ ^[0-9]+\.?[0-9]*$ ]]; then
    echo ""
    echo "❌ 錯誤：速度倍率必須是正數，收到: $val"
    echo ""
    return 1
  fi
  if (( $(echo "$val < 0.5 || $val > 100.0" | bc -l) )); then
    echo ""
    echo "❌ 錯誤：速度倍率必須在 0.5-100.0 之間，收到: $val"
    echo "   (ffmpeg atempo 濾鏡限制)"
    echo ""
    return 1
  fi
  return 0
}
