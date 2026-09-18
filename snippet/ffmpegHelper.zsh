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
  trap 'command rm -f "$temp_output"' EXIT
  
  # 執行 ffmpeg 並捕獲輸出（隱藏進度信息）
  if ! ffmpeg -hide_banner -loglevel info -i "$reference" -i "$comparison" -lavfi "[0:v]setpts=PTS-STARTPTS[v0];[1:v]setpts=PTS-STARTPTS[v1];[v0][v1]ssim;[0:v]setpts=PTS-STARTPTS[v0];[1:v]setpts=PTS-STARTPTS[v1];[v0][v1]psnr" -f null - > "$temp_output" 2>&1; then
    echo "錯誤：ffmpeg 品質計算失敗" >&2
    command rm -f "$temp_output"
    trap - EXIT
    return 1
  fi
  
  # 提取 SSIM 平均值
  local ssim_avg
  ssim_avg=$(grep "SSIM" "$temp_output" | grep "All:" | tail -1 | sed -n 's/.*All:\([0-9.]*\).*/\1/p')
  
  # 提取 PSNR 平均值
  local psnr_avg
  psnr_avg=$(grep "PSNR" "$temp_output" | grep "average:" | tail -1 | sed -n 's/.*average:\([0-9.]*\).*/\1/p')
  
  # 清理臨時檔案（command rm 刻意繞過 trash alias）
  command rm -f "$temp_output"
  trap - EXIT

  if [[ -z "$ssim_avg" || -z "$psnr_avg" ]]; then
    echo "錯誤：無法從 ffmpeg 輸出解析 SSIM/PSNR" >&2
    return 1
  fi
  
  # 返回結果（用空格分隔）
  echo "$ssim_avg $psnr_avg"
}

# vmaf_v1.0.16 模型需要 speed_chroma 特徵擷取器，
# 而它只在 libvmaf 以 -Denable_float=true 編譯時才註冊
# （Homebrew 的 libvmaf 沒開，會報 could not initialize feature extractor）。
# 自行編譯的版本放在 $_FFMPEG_VMAF_LIB，透過 DYLD_LIBRARY_PATH 覆蓋 brew 版本：
#   curl -sfL https://github.com/Netflix/vmaf/archive/refs/tags/v3.2.0.tar.gz | tar xz
#   cd vmaf-3.2.0
#   meson setup build libvmaf --prefix=$HOME/.local/opt/libvmaf-float \
#     --buildtype=release -Denable_float=true
#   meson compile -C build && meson install -C build
_FFMPEG_VMAF_LIB="${HOME}/.local/opt/libvmaf-float/lib"

# 以支援 speed_chroma 的 libvmaf 執行 ffmpeg
_ffmpeg_vmaf_ffmpeg() {
  if [ -f "$_FFMPEG_VMAF_LIB/libvmaf.3.dylib" ]; then
    DYLD_LIBRARY_PATH="$_FFMPEG_VMAF_LIB${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" \
      command ffmpeg "$@"
  else
    command ffmpeg "$@"
  fi
}

# VMAF 模型路徑（Netflix vmaf_v1.0.16_3d0h）
# 回傳 0=找到，1=不存在（已印出錯誤訊息到 stderr）
_ffmpeg_vmaf_model() {
  local model="${DOTFILES:-$HOME/dotfiles}/vmaf_v1.0.16_3d0h.json"
  if [ ! -f "$model" ]; then
    echo "錯誤：VMAF 模型檔案不存在: $model" >&2
    return 1
  fi
  if [ ! -f "$_FFMPEG_VMAF_LIB/libvmaf.3.dylib" ]; then
    echo "錯誤：找不到支援 vmaf_v1.0.16 的 libvmaf: $_FFMPEG_VMAF_LIB" >&2
    echo "      請依 snippet/ffmpegHelper.zsh 註解編譯 libvmaf (-Denable_float=true)" >&2
    return 1
  fi
  echo "$model"
}

# 計算兩個影片的 VMAF 平均分數
# 用法：_ffmpeg_calculate_vmaf <reference> <comparison>
# 輸出：VMAF 平均分數（0-100）
_ffmpeg_calculate_vmaf() {
  # 強制禁用調試輸出
  set +x
  {
    setopt localoptions 2>/dev/null
    unsetopt xtrace verbose 2>/dev/null
  } 2>/dev/null

  local reference="$1"
  local comparison="$2"

  local model
  model=$(_ffmpeg_vmaf_model) || return 1

  local cpu_cores
  cpu_cores=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)

  local log_file
  log_file=$(mktemp -t vmaf_log)
  trap 'command rm -f "$log_file"' EXIT

  # libvmaf 第一路輸入為待測影片，第二路為參考影片（順序不可交換）
  if ! _ffmpeg_vmaf_ffmpeg -hide_banner -loglevel error \
    -i "$comparison" -i "$reference" \
    -lavfi "[0:v]setpts=PTS-STARTPTS[dist];[1:v]setpts=PTS-STARTPTS[ref];[dist][ref]libvmaf=model=path=${model}:log_path=${log_file}:log_fmt=json:n_threads=${cpu_cores}:shortest=1" \
    -f null - > /dev/null 2>&1; then
    echo "錯誤：ffmpeg VMAF 計算失敗" >&2
    command rm -f "$log_file"
    trap - EXIT
    return 1
  fi

  local vmaf_score
  if command -v jq &> /dev/null; then
    vmaf_score=$(jq -r '.pooled_metrics.vmaf.mean' "$log_file" 2>/dev/null)
  else
    vmaf_score=$(grep -o '"mean":[0-9.]*' "$log_file" | head -1 | sed 's/"mean"://')
  fi

  command rm -f "$log_file"
  trap - EXIT

  if [[ -z "$vmaf_score" || "$vmaf_score" == "null" ]]; then
    echo "錯誤：無法從 VMAF 結果解析分數" >&2
    return 1
  fi

  printf "%.2f\n" "$vmaf_score"
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
