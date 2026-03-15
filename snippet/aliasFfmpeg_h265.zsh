# ============================================
# H.265 轉換相關輔助函數
# ============================================

# 格式化檔案大小
_h265_format_size() {
  local size=$1
  if command -v numfmt &> /dev/null; then
    numfmt --to=iec-i --suffix=B "$size" 2>/dev/null || echo "${size}B"
  else
    if [ "$size" -gt 1073741824 ]; then
      local result
      result=$(echo "scale=2; $size / 1073741824" | bc)
      echo "${result}GB"
    elif [ "$size" -gt 1048576 ]; then
      local result
      result=$(echo "scale=2; $size / 1048576" | bc)
      echo "${result}MB"
    elif [ "$size" -gt 1024 ]; then
      local result
      result=$(echo "scale=2; $size / 1024" | bc)
      echo "${result}KB"
    else
      echo "${size}B"
    fi
  fi
}

# 顯示錯誤訊息並返回
_h265_error() {
  echo ""
  echo "❌ 錯誤：$1"
  [ -n "$2" ] && echo "   $2"
  echo ""
  return 1
}

# 顯示警告訊息
_h265_warn() {
  echo "⚠️  警告：$1"
  [ -n "$2" ] && echo "   $2"
}

# 檢查必要命令是否存在
_h265_check_dependencies() {
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
_h265_calculate_quality() {
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

function toH265() {
  # 強制禁用調試輸出
  set +x
  {
    setopt localoptions 2>/dev/null
    unsetopt xtrace verbose 2>/dev/null
  } 2>/dev/null
  
  # 檢查入參是否包含檔名
  if [ -z "$1" ]; then
    echo ""
    echo "❌ 錯誤：請輸入檔名"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📖 使用說明"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  toH265 <input_file> [-s speed] [-m maxrate] [-c crf] [-p preset] [-ss start] [-to end] [-hw] [-d|--dry-run]"
    echo ""
    echo "📝 參數說明"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  input_file    - 輸入影片檔案（必填）"
    echo "  -s speed      - 播放速度倍率，範圍 0.5-100.0（可選，預設 2.5）"
    echo "                  範例: -s 1.0, -s 1.5, -s 2.5"
    echo "  -m maxrate    - 目標位元率，支持單位 k/M/G（可選，預設自動取得）"
    echo "                  範例: -m 2700k, -m 2.7M, -m 2700000"
    echo "  -c crf        - 品質參數 20-26，越低品質越好（可選，預設自動決定）"
    echo "                  範例: -c 20, -c 23, -c 26"
    echo "  -p preset     - 編碼預設 ultrafast/superfast/veryfast/faster/fast/medium/slow/slower/veryslow"
    echo "                  （可選，預設 slow）"
    echo "  -ss start     - 開始時間（可選）"
    echo "                  範例: -ss 00:01:30, -ss 90"
    echo "  -to end       - 結束時間（可選）"
    echo "                  範例: -to 00:05:00, -to 300"
    echo "  -hw           - 使用硬體加速編碼（可選，預設使用軟體編碼）"
    echo "  -d, --dry-run - 顯示完整命令但不執行（可選）"
    echo ""
    echo "💡 使用範例"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  toH265 input.mp4"
    echo "  toH265 input.mp4 -s 2.5"
    echo "  toH265 input.mp4 -s 2.5 -m 2700k"
    echo "  toH265 input.mp4 -ss 00:01:30 -to 00:05:00"
    echo "  toH265 input.mp4 -s 2.5 -m 2700k -c 23 -p medium"
    echo "  toH265 input.mp4 -m 2700k -c 23 -hw"
    echo "  toH265 input.mp4 -d"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    return 1
  fi

  # 檢查檔案是否存在
  if [ ! -f "$1" ]; then
    echo ""
    echo "❌ 錯誤：檔案 $1 不存在"
    echo ""
    return 1
  fi

  local input_file="$1"
  shift
  
  # 檢查必要的命令
  _h265_check_dependencies || return 1
  
  # 全局變數
  local maxrate crf speed use_hw_accel preset dry_run start_time end_time
  
  # 預設值
  speed="2.5"
  maxrate=""
  crf=""
  preset="slow"
  start_time=""
  end_time=""
  use_hw_accel=false
  dry_run=false
  
  # 解析flag參數
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s)
        if [ -z "$2" ]; then
          echo ""
          echo "❌ 錯誤：-s 需要指定速度倍率"
          echo ""
          return 1
        fi
        if ! [[ "$2" =~ ^[0-9]+\.?[0-9]*$ ]]; then
          echo ""
          echo "❌ 錯誤：速度倍率必須是正數，收到: $2"
          echo ""
          return 1
        fi
        # 檢查速度範圍 (ffmpeg atempo 限制: 0.5-100.0)
        if (( $(echo "$2 < 0.5 || $2 > 100.0" | bc -l) )); then
          echo ""
          echo "❌ 錯誤：速度倍率必須在 0.5-100.0 之間，收到: $2"
          echo "   (ffmpeg atempo 濾鏡限制)"
          echo ""
          return 1
        fi
        speed="$2"
        shift 2
        ;;
      -m)
        if [ -z "$2" ]; then
          echo ""
          echo "❌ 錯誤：-m 需要指定位元率"
          echo ""
          return 1
        fi
        if ! [[ "$2" =~ ^[0-9]+\.?[0-9]*[kKmMgG]?$ ]]; then
          echo ""
          echo "❌ 錯誤：maxrate 格式無效，收到: $2"
          echo "   應為: 數字 或 數字+單位(k/M/G)"
          echo "   範例: 2700k, 2.7M, 2700000"
          echo ""
          return 1
        fi
        maxrate="$2"
        shift 2
        ;;
      -c)
        if [ -z "$2" ]; then
          echo ""
          echo "❌ 錯誤：-c 需要指定 CRF 值"
          echo ""
          return 1
        fi
        if ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -lt 20 ] || [ "$2" -gt 26 ]; then
          echo ""
          echo "❌ 錯誤：crf 必須在 20-26 之間，收到: $2"
          echo ""
          return 1
        fi
        crf="$2"
        shift 2
        ;;
      -p)
        if [ -z "$2" ]; then
          echo ""
          echo "❌ 錯誤：-p 需要指定 preset"
          echo ""
          return 1
        fi
        # 驗證 preset 值
        case "$2" in
          ultrafast|superfast|veryfast|faster|fast|medium|slow|slower|veryslow)
            preset="$2"
            ;;
          *)
            echo ""
            echo "❌ 錯誤：無效的 preset: $2"
            echo "   可用值: ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow"
            echo ""
            return 1
            ;;
        esac
        shift 2
        ;;
      -ss)
        if [ -z "$2" ]; then
          echo ""
          echo "❌ 錯誤：-ss 需要指定開始時間"
          echo ""
          return 1
        fi
        start_time="$2"
        shift 2
        ;;
      -to)
        if [ -z "$2" ]; then
          echo ""
          echo "❌ 錯誤：-to 需要指定結束時間"
          echo ""
          return 1
        fi
        end_time="$2"
        shift 2
        ;;
      -hw)
        use_hw_accel=true
        shift
        ;;
      -d|--dry-run)
        dry_run=true
        shift
        ;;
      *)
        echo ""
        echo "❌ 錯誤：未知參數: $1"
        echo ""
        return 1
        ;;
    esac
  done

  # 驗證參數組合
  if [ "$use_hw_accel" = true ]; then
    if [ -n "$crf" ] || [ "$preset" != "slow" ]; then
      _h265_warn "硬體加速模式會忽略 -c (CRF) 和 -p (preset) 參數"
    fi
  fi
  
  # 如果 end_time 為 0，則不使用
  if [ "$end_time" = "0" ]; then
    end_time=""
  fi

  # 使用更通用的副檔名移除方式
  local filename="${input_file%.*}"
  local output_file="${filename}.h265.mp4"
  local audio_bitrate vf af

  # 檢查輸出檔案是否已存在（dry-run 模式跳過）
  if [ "$dry_run" = false ] && [ -f "$output_file" ]; then
    echo ""
    echo "⚠️  警告：輸出檔案已存在: $output_file"
    echo -n "是否覆蓋？[y/N] "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
      echo "已取消"
      return 0
    fi
  fi

  # 從ffprobe取得原始資訊
  echo ""
  echo "📊 正在分析來源檔案..."
  
  # 明確指定只查詢 bit_rate
  local orig_bitrate
  orig_bitrate=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 "$input_file" 2>&1)
  local ffprobe_exit=$?
  
  if [ $ffprobe_exit -ne 0 ] || [ -z "$orig_bitrate" ] || [ "$orig_bitrate" = "N/A" ]; then
    echo ""
    echo "❌ 錯誤：無法讀取影片位元率"
    echo "   ffprobe 輸出: $orig_bitrate"
    echo ""
    return 1
  fi
  
  # 驗證 orig_bitrate 是否為有效數字
  if ! [[ "$orig_bitrate" =~ ^[0-9]+$ ]]; then
    echo ""
    echo "❌ 錯誤：影片位元率不是有效數字: $orig_bitrate"
    echo ""
    return 1
  fi
  
  # 取得音頻位元率
  audio_bitrate=$(ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 "$input_file" 2>&1)
  local audio_probe_exit=$?
  
  if [ $audio_probe_exit -ne 0 ] || [ -z "$audio_bitrate" ] || [ "$audio_bitrate" = "N/A" ]; then
    echo "⚠️  警告：無法讀取音頻位元率，使用預設值 192k"
    audio_bitrate=192000
  elif ! [[ "$audio_bitrate" =~ ^[0-9]+$ ]]; then
    echo "⚠️  警告：音頻位元率不是有效數字 ($audio_bitrate)，使用預設值 192k"
    audio_bitrate=192000
  fi

  # 處理maxrate（使用 bc 處理浮點數）
  if [ -n "$maxrate" ]; then
    # 提取數字和單位
    local maxrate_num
    local unit
    # 移除最後一個字符（如果是單位）
    if [[ "$maxrate" =~ [kKmMgG]$ ]]; then
      maxrate_num="${maxrate%?}"
      unit="${maxrate: -1}"
      unit="${unit,,}"  # 轉換為小寫
    else
      maxrate_num="$maxrate"
      unit=""
    fi
    
    # 根據單位轉換（確保結果為整數）
    case "$unit" in
      k) maxrate="$(echo "scale=0; $maxrate_num * 1000 / 1" | bc)" ;;
      m) maxrate="$(echo "scale=0; $maxrate_num * 1000000 / 1" | bc)" ;;
      g) maxrate="$(echo "scale=0; $maxrate_num * 1000000000 / 1" | bc)" ;;
      *) maxrate="$(echo "scale=0; $maxrate_num / 1" | bc)" ;;
    esac
  else
    maxrate="$orig_bitrate"
  fi

  # 計算bufsize為maxrate的2倍
  local bufsize=$((maxrate * 2))

  # CRF自動決定（基於原始位元率，範圍 20-26）
  if [ -z "$crf" ]; then
    # 啟發式：位元率越高，CRF越低（品質越好）
    if [ "$orig_bitrate" -gt 5000000 ]; then
      crf=20
    elif [ "$orig_bitrate" -gt 2000000 ]; then
      crf=23
    else
      crf=26
    fi
  fi

  # 計算視頻速度（音頻速度的倒數）
  local video_speed
  
  # 如果速度為 1，不需要濾鏡
  if [ "$speed" = "1" ] || [ "$speed" = "1.0" ]; then
    vf=""
    af=""
  else
    video_speed="$(echo "scale=6; 1 / $speed" | bc)"
    
    # 設定視頻濾鏡
    vf="setpts=${video_speed}*PTS"
    
    # 處理音頻濾鏡（atempo 限制：單次 0.5-2.0，需要串聯）
    af=""
    local remaining_speed="$speed"
    
    # 如果速度 > 2.0，需要串聯多個 atempo
    while (( $(echo "$remaining_speed > 2.0" | bc -l) )); do
      if [ -n "$af" ]; then
        af="${af},atempo=2.0"
      else
        af="atempo=2.0"
      fi
      remaining_speed="$(echo "scale=6; $remaining_speed / 2.0" | bc)"
    done
    
    # 如果速度 < 0.5，需要串聯多個 atempo
    while (( $(echo "$remaining_speed < 0.5" | bc -l) )); do
      if [ -n "$af" ]; then
        af="${af},atempo=0.5"
      else
        af="atempo=0.5"
      fi
      remaining_speed="$(echo "scale=6; $remaining_speed / 0.5" | bc)"
    done
    
    # 添加最後的 atempo
    if [ -n "$af" ]; then
      af="${af},atempo=${remaining_speed}"
    else
      af="atempo=${remaining_speed}"
    fi
  fi

  # 轉換音頻位元率為k單位（用於顯示）
  local audio_bitrate_display=$((audio_bitrate / 1000))
  
  # 設定編碼器參數
  local video_codec encoder_mode
  if [ "$use_hw_accel" = true ]; then
    video_codec="hevc_videotoolbox"
    encoder_mode="硬體加速"
  else
    video_codec="libx265"
    encoder_mode="軟體編碼"
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📹 H.265 轉換設定"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📂 輸入檔案: $input_file"
  echo "📤 輸出檔案: $output_file"
  echo "⚡ 播放速度: ${speed}x"
  echo "🖥️  編碼模式: $encoder_mode ($video_codec)"
  if [ "$use_hw_accel" = false ]; then
    echo "⚙️  編碼預設: $preset"
  fi
  echo "📊 原始位元率: $orig_bitrate bps"
  echo "🎯 目標位元率: $maxrate bps"
  echo "📦 緩衝區大小: $bufsize bps"
  if [ "$use_hw_accel" = false ]; then
    echo "🎬 CRF 品質: $crf"
  fi
  echo "🔊 音頻位元率: ${audio_bitrate_display}k"
  [ -n "$vf" ] && echo "🏞️  視頻濾鏡: $vf"
  [ -n "$af" ] && echo "🎵 音頻濾鏡: $af"
  if [ -n "$start_time" ] || [ -n "$end_time" ]; then
    echo "⏱️  時間範圍: ${start_time:-00:00:00} → ${end_time:-結束}"
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if [ "$dry_run" = true ]; then
    echo "🔍 Dry-run 模式（不會執行）"
  else
    echo "⏳ 開始轉換..."
  fi
  echo ""

  # 建立ffmpeg命令（全局啟用硬體解碼以降低 CPU 負載）
  local ffmpeg_cmd
  
  if [ "$use_hw_accel" = true ]; then
    # 硬體加速編碼：使用 -b:v 而非 -crf
    local target_bitrate
    target_bitrate="$(echo "scale=0; $maxrate * 0.8 / 1" | bc)"
    ffmpeg_cmd=(
      ffmpeg -hide_banner
      -hwaccel videotoolbox
    )
    [ -n "$start_time" ] && ffmpeg_cmd+=(-ss "$start_time")
    [ -n "$end_time" ] && ffmpeg_cmd+=(-to "$end_time")
    ffmpeg_cmd+=(
      -i "$input_file"
      -map_metadata -1
      -map_chapters -1
      -c:v "$video_codec"
      -b:v "$target_bitrate"
      -maxrate "$maxrate"
      -bufsize "$bufsize"
      -vtag hvc1
      -threads 0
    )
    [ -n "$vf" ] && ffmpeg_cmd+=(-vf "$vf")
    ffmpeg_cmd+=(
      -c:a aac
      -b:a "$audio_bitrate"
    )
    [ -n "$af" ] && ffmpeg_cmd+=(-af "$af")
    ffmpeg_cmd+=("$output_file")
  else
    # 軟體編碼：啟用硬體解碼以降低 CPU 負載
    ffmpeg_cmd=(
      ffmpeg -hide_banner
      -hwaccel videotoolbox
    )
    [ -n "$start_time" ] && ffmpeg_cmd+=(-ss "$start_time")
    [ -n "$end_time" ] && ffmpeg_cmd+=(-to "$end_time")
    ffmpeg_cmd+=(
      -i "$input_file"
      -map_metadata -1
      -map_chapters -1
      -c:v "$video_codec"
      -crf "$crf"
      -preset "$preset"
      -vtag hvc1
      -maxrate "$maxrate"
      -bufsize "$bufsize"
      -threads 0
    )
    [ -n "$vf" ] && ffmpeg_cmd+=(-vf "$vf")
    ffmpeg_cmd+=(
      -c:a aac
      -b:a "$audio_bitrate"
    )
    [ -n "$af" ] && ffmpeg_cmd+=(-af "$af")
    ffmpeg_cmd+=("$output_file")
  fi

  # Dry-run 模式：顯示命令但不執行
  if [ "$dry_run" = true ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 完整 ffmpeg 命令"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    # 格式化顯示命令（每個參數一行）
    printf '%s' "${ffmpeg_cmd[0]}"
    for ((i=1; i<${#ffmpeg_cmd[@]}; i++)); do
      if [[ "${ffmpeg_cmd[i]}" == -* ]]; then
        printf ' \\
  %s' "${ffmpeg_cmd[i]}"
      else
        printf ' %s' "${ffmpeg_cmd[i]}"
      fi
    done
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "💡 移除 -d 或 --dry-run 參數以執行轉換"
    echo ""
    return 0
  fi

  # 建立臨時檔案並設定 trap 確保清理（command rm 刻意繞過 trash alias）
  local ffmpeg_stderr
  ffmpeg_stderr=$(mktemp)
  trap 'command rm -f "$ffmpeg_stderr"' EXIT INT TERM
  
  # 記錄開始時間
  local start_timestamp
  start_timestamp=$(date +%s)
  
  # 執行ffmpeg命令並捕獲錯誤輸出
  "${ffmpeg_cmd[@]}" 2> >(tee "$ffmpeg_stderr" >&2)
  local ffmpeg_exit_code=$?
  
  # 計算執行時間
  local end_timestamp
  end_timestamp=$(date +%s)
  local duration=$((end_timestamp - start_timestamp))

  echo ""
  if [ $ffmpeg_exit_code -eq 0 ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ 轉換完成"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📤 輸出檔案: $output_file"
    
    # 顯示執行時間
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    if [ $hours -gt 0 ]; then
      echo "⏱️  執行時間: ${hours}h ${minutes}m ${seconds}s"
    elif [ $minutes -gt 0 ]; then
      echo "⏱️  執行時間: ${minutes}m ${seconds}s"
    else
      echo "⏱️  執行時間: ${seconds}s"
    fi
    
    # 顯示檔案大小比較
    if command -v stat &> /dev/null; then
      local input_size
      local output_size
      input_size=$(stat -f%z "$input_file" 2>/dev/null || stat -c%s "$input_file" 2>/dev/null)
      output_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null)
      
      if [ -n "$input_size" ] && [ -n "$output_size" ] && [ "$input_size" -gt 0 ]; then
        local size_ratio
        local input_size_fmt
        local output_size_fmt
        size_ratio="$(echo "scale=2; $output_size * 100 / $input_size" | bc)"
        input_size_fmt=$(_h265_format_size "$input_size")
        output_size_fmt=$(_h265_format_size "$output_size")
        
        echo "📊 檔案大小: $input_size_fmt → $output_size_fmt (${size_ratio}%)"
      else
        echo "⚠️  無法取得檔案大小資訊"
      fi
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    return 0
  else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ 轉換失敗"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   ffmpeg 退出代碼: $ffmpeg_exit_code"
    echo ""
    
    # 顯示最後幾行錯誤訊息
    if [ -f "$ffmpeg_stderr" ] && [ -s "$ffmpeg_stderr" ]; then
      echo "   最後的錯誤訊息："
      while IFS= read -r line; do
        echo "   │ $line"
      done < <(tail -n 10 "$ffmpeg_stderr")
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    return 1
  fi
}

# 測試不同參數組合的函數
function toH265Test() {
  # 強制禁用調試輸出（同時支持 bash 和 zsh）
  set +x
  {
    setopt localoptions 2>/dev/null
    unsetopt xtrace verbose 2>/dev/null
  } 2>/dev/null
  
  # 設定 Ctrl+C 中斷處理
  trap 'echo ""; echo ""; echo "⚠️  測試已中斷"; kill -INT $$' INT TERM
  
  # 檢查依賴
  _h265_check_dependencies || return 1
  
  if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo ""
    echo "❌ 錯誤：缺少必要參數"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📖 使用說明"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  toH265Test <input_file> <start_time> <end_time> [-s speed] [-m maxrate]"
    echo ""
    echo "📝 參數說明"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  input_file  - 輸入影片檔案（必填）"
    echo "  start_time  - 開始時間（必填）"
    echo "              範例: 00:01:30, 90"
    echo "  end_time    - 結束時間（必填）"
    echo "              範例: 00:05:00, 300"
    echo "  -s speed    - 播放速度倍率（可選，預設 2.5）"
    echo "  -m maxrate  - 目標位元率（可選，預設自動）"
    echo ""
    echo "📊 測試組合"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  CRF: 22, 24, 26"
    echo "  Preset: medium, slow"
    echo "  模式: 軟體編碼 (6組), 硬體加速 (1組)"
    echo "  speed=1 時額外測試: 原始裁切 (1組，作為品質基準)"
    echo "  speed≠1 時: 使用 CRF22+medium 作為品質基準"
    echo ""
    echo "💡 使用範例"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  toH265Test input.mp4 00:01:00 00:02:00"
    echo "  toH265Test input.mp4 60 120 -s 1.0"
    echo "  toH265Test input.mp4 00:01:00 00:02:00 -s 2.5 -m 2700k"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    return 1
  fi

  local input_file="$1"
  local start_time="$2"
  local end_time="$3"
  shift 3

  # 檢查檔案是否存在
  if [ ! -f "$input_file" ]; then
    echo ""
    echo "❌ 錯誤：檔案 $input_file 不存在"
    echo ""
    return 1
  fi

  # 解析可選參數
  local speed="2.5"
  local maxrate=""
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s)
        if [ -z "$2" ]; then
          echo "❌ 錯誤：-s 需要指定速度倍率"
          return 1
        fi
        speed="$2"
        shift 2
        ;;
      -m)
        if [ -z "$2" ]; then
          echo "❌ 錯誤：-m 需要指定位元率"
          return 1
        fi
        maxrate="$2"
        shift 2
        ;;
      *)
        echo "❌ 錯誤：未知參數: $1"
        return 1
        ;;
    esac
  done

  # 測試組合
  local crf_values=(22 24 26)
  local preset_values=(medium slow)
  
  # 統計變數
  local total_tests=0
  local success_count=0
  local fail_count=0
  
  # 計算總測試數
  local total_combinations=7
  local reference_file=""
  
  # 如果 speed=1，增加原始裁切測試
  if [ "$speed" = "1" ] || [ "$speed" = "1.0" ]; then
    total_combinations=$((total_combinations + 1))  # +1 原始裁切
  fi
  
  # 用於收集測試結果的陣列
  local -a test_results_name
  local -a test_results_size
  local -a test_results_time
  local -a test_results_ssim
  local -a test_results_psnr
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🧪 H.265 參數測試"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📂 輸入檔案: $input_file"
  echo "⏱️ 時間範圍: $start_time → $end_time"
  echo "⚡ 播放速度: ${speed}x"
  [ -n "$maxrate" ] && echo "🎯 目標位元率: $maxrate"
  echo "📊 測試組合: $total_combinations 個"
  if [ "$speed" = "1" ] || [ "$speed" = "1.0" ]; then
    echo "   • 原始裁切: 1 個 (僅複製編碼，作為品質基準)"
  fi
  echo "   • 軟體編碼: CRF(22,24,26) × Preset(medium,slow) = 6 個"
  echo "   • 硬體加速: 1 個"
  if [ "$speed" != "1" ] && [ "$speed" != "1.0" ]; then
    echo "   • 品質基準: 使用 CRF22 + slow 作為參考"
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # 建立測試結果目錄
  local base_name="${input_file%.*}"
  local test_dir="${base_name}_h265_test"
  mkdir -p "$test_dir"
  
  echo "📁 測試輸出目錄: $test_dir"
  echo ""

  # 記錄總開始時間
  local total_start_time
  total_start_time=$(date +%s)

  # 如果 speed=1，先建立原始裁切版本作為參考
  if [ "$speed" = "1" ] || [ "$speed" = "1.0" ]; then
    total_tests=$((total_tests + 1))
    local orig_output="${test_dir}/original_copy.mp4"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔄 測試 [$total_tests/$total_combinations]"
    echo "   模式: 原始裁切 (僅複製編碼)"
    echo "   輸出: $(basename "$orig_output")"
    echo ""
    
    local test_start
    test_start=$(date +%s)
    
    # 使用 ffmpeg 直接裁切，不重新編碼
    ffmpeg -hide_banner -loglevel error -ss "$start_time" -to "$end_time" -i "$input_file" -c copy "$orig_output" 2>&1
    local exit_code=$?
    
    if [ $exit_code -eq 0 ] && [ -f "$orig_output" ]; then
      success_count=$((success_count + 1))
      reference_file="$orig_output"
      
      local test_end
      test_end=$(date +%s)
      local test_duration=$((test_end - test_start))
      
      if command -v stat &> /dev/null; then
        local file_size
        file_size=$(stat -f%z "$orig_output" 2>/dev/null || stat -c%s "$orig_output" 2>/dev/null)
        if [ -n "$file_size" ]; then
          local size_fmt
          size_fmt=$(_h265_format_size "$file_size")
          echo "✅ 完成 - 大小: $size_fmt, 時間: ${test_duration}s"
          
          # 收集測試結果（原始裁切沒有 SSIM/PSNR）
          test_results_name+=("Original_Copy")
          test_results_size+=("$file_size")
          test_results_time+=("$test_duration")
          test_results_ssim+=("1.000")
          test_results_psnr+=("∞")
        fi
      fi
    else
      echo "❌ 裁切失敗"
      fail_count=$((fail_count + 1))
    fi
    echo ""
  fi

  # 測試軟體編碼組合
  for crf in "${crf_values[@]}"; do
    for preset in "${preset_values[@]}"; do
      total_tests=$((total_tests + 1))
      
      local output_name="${test_dir}/test_sw_crf${crf}_${preset}.mp4"
      
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "🔄 測試 [$total_tests/$total_combinations]"
      echo "   模式: 軟體編碼 (libx265)"
      echo "   CRF: $crf"
      echo "   Preset: $preset"
      echo ""
      
      # 構建命令
      local cmd_args=("$input_file" -ss "$start_time" -to "$end_time" -s "$speed" -c "$crf" -p "$preset")
      [ -n "$maxrate" ] && cmd_args+=(-m "$maxrate")
      
      # 記錄測試開始時間
      local test_start
      test_start=$(date +%s)
      
      # 執行轉換（隱藏詳細輸出）
      if toH265 "${cmd_args[@]}" > /dev/null 2>&1; then
        local default_output="${base_name}.h265.mp4"
        if [ -f "$default_output" ]; then
          success_count=$((success_count + 1))
          
          # 計算測試時間
          local test_end
          test_end=$(date +%s)
          local test_duration=$((test_end - test_start))
          
          # 顯示檔案大小和時間
          if command -v stat &> /dev/null; then
            local file_size
            file_size=$(stat -f%z "$default_output" 2>/dev/null || stat -c%s "$default_output" 2>/dev/null)
            if [ -n "$file_size" ]; then
              local size_fmt
              size_fmt=$(_h265_format_size "$file_size")
              
              # 如果沒有參考檔案且這是第一個測試（CRF22 + medium），設為參考
              if [ -z "$reference_file" ] && [ "$crf" = "22" ] && [ "$preset" = "medium" ]; then
                # 先保存檔案，稍後設為參考
                local new_name="test_sw_crf${crf}_${preset}_${test_duration}s.mp4"
                output_name="${test_dir}/${new_name}"
                mv "$default_output" "$output_name"
                reference_file="$output_name"
                
                echo "✅ 完成 - 大小: $size_fmt, 時間: ${test_duration}s"
                echo "   📌 設為品質基準"
                
                # 收集測試結果（第一個沒有 SSIM/PSNR）
                test_results_name+=("CRF${crf}_${preset}")
                test_results_size+=("$file_size")
                test_results_time+=("$test_duration")
                test_results_ssim+=("-")
                test_results_psnr+=("-")
              else
                # 計算品質指標
                local ssim_val="-" psnr_val="-"
                if [ -n "$reference_file" ] && [ -f "$reference_file" ]; then
                  echo "   📊 正在計算品質指標..."
                  local quality_result
                  quality_result=$(_h265_calculate_quality "$reference_file" "$default_output")
                  ssim_val=$(echo "$quality_result" | awk '{print $1}')
                  psnr_val=$(echo "$quality_result" | awk '{print $2}')
                fi
                
                # 重命名檔案，包含 SSIM/PSNR/時間
                local new_name="test_sw_crf${crf}_${preset}"
                if [ "$ssim_val" != "-" ]; then
                  new_name="${new_name}_ssim${ssim_val}_psnr${psnr_val}dB_${test_duration}s.mp4"
                else
                  new_name="${new_name}_${test_duration}s.mp4"
                fi
                output_name="${test_dir}/${new_name}"
                mv "$default_output" "$output_name"
                
                echo "✅ 完成 - 大小: $size_fmt, 時間: ${test_duration}s"
                [ "$ssim_val" != "-" ] && echo "   📈 SSIM: $ssim_val, PSNR: ${psnr_val}dB"
                
                # 收集測試結果
                test_results_name+=("CRF${crf}_${preset}")
                test_results_size+=("$file_size")
                test_results_time+=("$test_duration")
                test_results_ssim+=("$ssim_val")
                test_results_psnr+=("$psnr_val")
              fi
            fi
          fi
        else
          fail_count=$((fail_count + 1))
        fi
      else
        echo "❌ 轉換失敗"
        fail_count=$((fail_count + 1))
      fi
      echo ""
    done
  done

  # 測試硬體加速
  total_tests=$((total_tests + 1))
  local output_name="${test_dir}/test_hw.mp4"
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔄 測試 [$total_tests/$total_combinations]"
  echo "   模式: 硬體加速 (hevc_videotoolbox)"
  echo ""
  
  local cmd_args=("$input_file" -ss "$start_time" -to "$end_time" -s "$speed" -hw)
  [ -n "$maxrate" ] && cmd_args+=(-m "$maxrate")
  
  # 記錄測試開始時間
  local test_start
  test_start=$(date +%s)
  
  # 執行轉換（隱藏詳細輸出）
  if toH265 "${cmd_args[@]}" > /dev/null 2>&1; then
    local default_output="${base_name}.h265.mp4"
    if [ -f "$default_output" ]; then
      success_count=$((success_count + 1))
      
      # 計算測試時間
      local test_end
      test_end=$(date +%s)
      local test_duration=$((test_end - test_start))
      
      if command -v stat &> /dev/null; then
        local file_size
        file_size=$(stat -f%z "$default_output" 2>/dev/null || stat -c%s "$default_output" 2>/dev/null)
        if [ -n "$file_size" ]; then
          local size_fmt
          size_fmt=$(_h265_format_size "$file_size")
          
          # 計算品質指標
          local ssim_val="-" psnr_val="-"
          if [ -n "$reference_file" ] && [ -f "$reference_file" ]; then
            echo "   📊 正在計算品質指標..."
            local quality_result
            quality_result=$(_h265_calculate_quality "$reference_file" "$default_output")
            ssim_val=$(echo "$quality_result" | awk '{print $1}')
            psnr_val=$(echo "$quality_result" | awk '{print $2}')
          fi
          
          # 重命名檔案，包含 SSIM/PSNR/時間
          local new_name="test_hw"
          if [ "$ssim_val" != "-" ]; then
            new_name="${new_name}_ssim${ssim_val}_psnr${psnr_val}dB_${test_duration}s.mp4"
          else
            new_name="${new_name}_${test_duration}s.mp4"
          fi
          output_name="${test_dir}/${new_name}"
          mv "$default_output" "$output_name"
          
          echo "✅ 完成 - 大小: $size_fmt, 時間: ${test_duration}s"
          [ "$ssim_val" != "-" ] && echo "   📈 SSIM: $ssim_val, PSNR: ${psnr_val}dB"
          
          # 收集測試結果
          test_results_name+=("HW_accel")
          test_results_size+=("$file_size")
          test_results_time+=("$test_duration")
          test_results_ssim+=("$ssim_val")
          test_results_psnr+=("$psnr_val")
        fi
      fi
    else
      fail_count=$((fail_count + 1))
    fi
  else
    echo "❌ 轉換失敗"
    fail_count=$((fail_count + 1))
  fi
  echo ""

  # 計算總執行時間
  local total_end_time
  total_end_time=$(date +%s)
  local total_duration=$((total_end_time - total_start_time))
  local hours=$((total_duration / 3600))
  local minutes=$(((total_duration % 3600) / 60))
  local seconds=$((total_duration % 60))

  # 顯示測試總結
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📊 測試完成"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "   總測試數: $total_tests"
  echo "   ✅ 成功: $success_count"
  echo "   ❌ 失敗: $fail_count"
  if [ $hours -gt 0 ]; then
    echo "   ⏱️ 總時間: ${hours}h ${minutes}m ${seconds}s"
  elif [ $minutes -gt 0 ]; then
    echo "   ⏱️ 總時間: ${minutes}m ${seconds}s"
  else
    echo "   ⏱️ 總時間: ${seconds}s"
  fi
  echo "   📁 輸出目錄: $test_dir"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # 顯示所有測試結果比較表
  if [ ${#test_results_name[@]} -gt 0 ]; then
    echo "📋 測試結果比較"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # 檢查是否有品質數據
    local has_quality=false
    for ((i=1; i<=${#test_results_ssim[@]}; i++)); do
      if [ "${test_results_ssim[$i]}" != "-" ]; then
        has_quality=true
        break
      fi
    done
    
    if [ "$has_quality" = true ]; then
      printf "%-20s %12s %10s %12s %12s\n" "參數組合" "檔案大小" "執行時間" "SSIM" "PSNR(dB)"
    else
      printf "%-20s %15s %12s\n" "參數組合" "檔案大小" "執行時間"
    fi
    echo "────────────────────────────────────────────────────────────────────────────"
    
    # zsh 陣列索引從 1 開始
    local result_count=${#test_results_name[@]}
    for ((i=1; i<=result_count; i++)); do
      local name="${test_results_name[$i]}"
      local size="${test_results_size[$i]}"
      local time="${test_results_time[$i]}"
      local ssim="${test_results_ssim[$i]}"
      local psnr="${test_results_psnr[$i]}"
      local size_fmt
      size_fmt=$(_h265_format_size "$size")
      
      # 格式化時間顯示
      local time_fmt=""
      if [ "$time" -ge 60 ]; then
        local mins=$((time / 60))
        local secs=$((time % 60))
        time_fmt="${mins}m ${secs}s"
      else
        time_fmt="${time}s"
      fi
      
      if [ "$has_quality" = true ]; then
        printf "%-20s %12s %10s %12s %12s\n" "$name" "$size_fmt" "$time_fmt" "$ssim" "$psnr"
      else
        printf "%-20s %15s %12s\n" "$name" "$size_fmt" "$time_fmt"
      fi
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
  fi
  
  echo "💡 提示：使用以下命令查看所有測試結果："
  echo "   ls -lhS $test_dir  # 按大小排序"
  echo "   open $test_dir     # 在 Finder 中打開"
  echo ""
  
  if [ $fail_count -gt 0 ]; then
    return 1
  else
    return 0
  fi
}
