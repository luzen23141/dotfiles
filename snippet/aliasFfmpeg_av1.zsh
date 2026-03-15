# ============================================
# AV1 轉換相關輔助函數
# ============================================

source "$DOTFILES/snippet/ffmpegHelper.zsh"

function toAv1() {
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
    echo "  toAv1 <input_file> [-s speed] [-c crf] [-p preset] [-g grain] [-t tune] [-ss start] [-to end] [-d|--dry-run]"
    echo ""
    echo "📝 參數說明"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  input_file    - 輸入影片檔案（必填）"
    echo "  -s speed      - 播放速度倍率，範圍 0.5-100.0（可選，預設 1.0）"
    echo "                  範例: -s 1.0, -s 1.5, -s 2.5"
    echo "  -c crf        - 品質參數 0-63，越低品質越好（可選，預設 40）"
    echo "                  範例: -c 30, -c 40, -c 50"
    echo "  -p preset     - 編碼預設 0-13（可選，預設 5）"
    echo "                  0=最慢/最佳品質, 13=最快/最低品質"
    echo "                  範例: -p 4, -p 5, -p 6"
    echo "  -g grain      - Film grain 參數 0-15（可選，預設 0，無 grain）"
    echo "                  範例: -g 0, -g 4, -g 8"
    echo "  -t tune       - Tune 參數 0=默認, 1=電影, 2=動漫等（可選，預設 0）"
    echo "                  範例: -t 0, -t 1"
    echo "  -ss start     - 開始時間（可選）"
    echo "                  範例: -ss 00:01:30, -ss 90"
    echo "  -to end       - 結束時間（可選）"
    echo "                  範例: -to 00:05:00, -to 300"
    echo "  -d, --dry-run - 顯示完整命令但不執行（可選）"
    echo ""
    echo "💡 使用範例"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  toAv1 input.mp4"
    echo "  toAv1 input.mp4 -s 1.0"
    echo "  toAv1 input.mp4 -c 35 -p 5"
    echo "  toAv1 input.mp4 -c 40 -g 4"
    echo "  toAv1 input.mp4 -ss 00:01:30 -to 00:05:00"
    echo "  toAv1 input.mp4 -c 40 -p 5 -g 8 -t 1"
    echo "  toAv1 input.mp4 -d"
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
  _ffmpeg_check_dependencies || return 1
  
  # 全局變數
  local crf preset grain tune dry_run start_time end_time speed
  
  # 預設值
  speed="1.0"
  crf="40"
  preset="5"
  grain="0"
  tune="0"
  start_time=""
  end_time=""
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
        _ffmpeg_validate_speed "$2" || return 1
        speed="$2"
        shift 2
        ;;
      -c)
        if [ -z "$2" ]; then
          echo ""
          echo "❌ 錯誤：-c 需要指定 CRF 值"
          echo ""
          return 1
        fi
        if ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -lt 0 ] || [ "$2" -gt 63 ]; then
          echo ""
          echo "❌ 錯誤：crf 必須在 0-63 之間，收到: $2"
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
        if ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -lt 0 ] || [ "$2" -gt 13 ]; then
          echo ""
          echo "❌ 錯誤：preset 必須在 0-13 之間，收到: $2"
          echo ""
          return 1
        fi
        preset="$2"
        shift 2
        ;;
      -g)
        if [ -z "$2" ]; then
          echo ""
          echo "❌ 錯誤：-g 需要指定 grain 值"
          echo ""
          return 1
        fi
        if ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -lt 0 ] || [ "$2" -gt 15 ]; then
          echo ""
          echo "❌ 錯誤：grain 必須在 0-15 之間，收到: $2"
          echo ""
          return 1
        fi
        grain="$2"
        shift 2
        ;;
      -t)
        if [ -z "$2" ]; then
          echo ""
          echo "❌ 錯誤：-t 需要指定 tune 值"
          echo ""
          return 1
        fi
        if ! [[ "$2" =~ ^[0-9]+$ ]]; then
          echo ""
          echo "❌ 錯誤：tune 必須是非負整數，收到: $2"
          echo ""
          return 1
        fi
        tune="$2"
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

  # 使用更通用的副檔名移除方式
  local filename="${input_file%.*}"
  local output_file="${filename}.av1.mp4"

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

  # 計算目標位元率（AV1 通常比 H.265 更高效）
  local maxrate
  maxrate=$((orig_bitrate / 3 * 2))

  # 計算bufsize為maxrate的2倍
  local bufsize=$((maxrate * 2))

  # 構建 svtav1-params
  local svtav1_params=""
  if [ "$tune" != "0" ] || [ "$grain" != "0" ]; then
    svtav1_params="tune=${tune}:film-grain=${grain}"
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📹 AV1 轉換設定"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📂 輸入檔案: $input_file"
  echo "📤 輸出檔案: $output_file"
  echo "⚡ 播放速度: ${speed}x"
  echo "🎬 CRF 品質: $crf (0-63，越低越好)"
  echo "⚙️  編碼預設: $preset (0-13，越低越慢)"
  echo "🎥 Film Grain: $grain"
  echo "🎬 Tune 參數: $tune"
  echo "📊 原始位元率: $orig_bitrate bps"
  echo "🎯 目標位元率: $maxrate bps"
  echo "📦 緩衝區大小: $bufsize bps"
  echo "🖼️  像素格式: yuv420p10le (10-bit)"
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

  # 建立ffmpeg命令
  local ffmpeg_cmd=(
    ffmpeg -hide_banner
    -hwaccel videotoolbox
  )
  [ -n "$start_time" ] && ffmpeg_cmd+=(-ss "$start_time")
  [ -n "$end_time" ] && ffmpeg_cmd+=(-to "$end_time")
  
  local video_filter_arg=""
  local audio_filter_arg=""
  if (( $(echo "$speed != 1.0" | bc -l) )); then
    video_filter_arg="setpts=PTS/${speed}"
    local remain="$speed"
    local atempo_chain=""
    while (( $(echo "$remain > 2.0" | bc -l) )); do
      if [ -n "$atempo_chain" ]; then atempo_chain="$atempo_chain,atempo=2.0"; else atempo_chain="atempo=2.0"; fi
      remain=$(echo "scale=6; $remain / 2.0" | bc -l)
    done
    while (( $(echo "$remain < 0.5" | bc -l) )); do
      if [ -n "$atempo_chain" ]; then atempo_chain="$atempo_chain,atempo=0.5"; else atempo_chain="atempo=0.5"; fi
      remain=$(echo "scale=6; $remain / 0.5" | bc -l)
    done
    if (( $(echo "$remain != 1.0" | bc -l) )); then
      if [ -n "$atempo_chain" ]; then atempo_chain="$atempo_chain,atempo=$remain"; else atempo_chain="atempo=$remain"; fi
    fi
    audio_filter_arg="$atempo_chain"
  fi
  ffmpeg_cmd+=(
    -i "$input_file"
  )
  [ -n "$video_filter_arg" ] && ffmpeg_cmd+=(-filter:v "$video_filter_arg")
  [ -n "$audio_filter_arg" ] && ffmpeg_cmd+=(-filter:a "$audio_filter_arg")
  ffmpeg_cmd+=(
    -map_metadata -1
    -map_chapters -1
    -c:v libsvtav1
    -crf "$crf"
    -preset "$preset"
    -pix_fmt yuv420p10le
    -g 60
    -keyint_min 30
  )
  [ -n "$svtav1_params" ] && ffmpeg_cmd+=(-svtav1-params "$svtav1_params")
  ffmpeg_cmd+=(
    -maxrate "$maxrate"
    -bufsize "$bufsize"
    -c:a aac
    -b:a 128k
    "$output_file"
  )

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
    local input_size
    local output_size
    input_size=$(stat -f%z "$input_file" 2>/dev/null)
    output_size=$(stat -f%z "$output_file" 2>/dev/null)
    
    if [ -n "$input_size" ] && [ -n "$output_size" ] && [ "$input_size" -gt 0 ]; then
      local size_ratio
      local input_size_fmt
      local output_size_fmt
      size_ratio="$(echo "scale=2; $output_size * 100 / $input_size" | bc)"
      input_size_fmt=$(_ffmpeg_format_size "$input_size")
      output_size_fmt=$(_ffmpeg_format_size "$output_size")
      
      echo "📊 檔案大小: $input_size_fmt → $output_size_fmt (${size_ratio}%)"
    else
      echo "⚠️  無法取得檔案大小資訊"
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
function toAv1Test() {
  # 強制禁用調試輸出（同時支持 bash 和 zsh）
  set +x
  {
    setopt localoptions 2>/dev/null
    unsetopt xtrace verbose 2>/dev/null
  } 2>/dev/null
  
  # 設定 Ctrl+C 中斷處理
  trap 'echo ""; echo ""; echo "⚠️  測試已中斷"; kill -INT $$' INT TERM
  
  # 檢查依賴
  _ffmpeg_check_dependencies || return 1
  
  if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo ""
    echo "❌ 錯誤：缺少必要參數"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📖 使用說明"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  toAv1Test <input_file> <start_time> <end_time> [-s speed] [-g grain]"
    echo ""
    echo "📝 參數說明"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  input_file  - 輸入影片檔案（必填）"
    echo "  start_time  - 開始時間（必填）"
    echo "              範例: 00:01:30, 90"
    echo "  end_time    - 結束時間（必填）"
    echo "              範例: 00:05:00, 300"
    echo "  -s speed    - 播放速度倍率（可選，預設 1.0）"
    echo "              範例: -s 1.0, -s 1.5, -s 2.0"
    echo "  -g grain    - Film grain 參數（可選，預設 0）"
    echo "              可指定為 0, 4, 8 進行多次測試"
    echo ""
    echo "📊 測試組合"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  原始裁切: 1 個 (作為品質基準)"
    echo "  CRF: 30, 35, 40, 45"
    echo "  Preset: 4, 5, 6"
    echo "  Grain: 指定值（預設 0）"
    echo "  總組合: 1 + 4×3 = 13 個測試"
    echo ""
    echo "💡 使用範例"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  toAv1Test input.mp4 00:01:00 00:02:00"
    echo "  toAv1Test input.mp4 60 120"
    echo "  toAv1Test input.mp4 00:01:00 00:02:00 -s 1.5"
    echo "  toAv1Test input.mp4 00:01:00 00:02:00 -g 15"
    echo "  toAv1Test input.mp4 00:01:00 00:02:00 -s 1.5 -g 8"
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
  local grain="0"
  local speed="1.0"
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s)
        if [ -z "$2" ]; then
          echo "❌ 錯誤：-s 需要指定速度倍率"
          return 1
        fi
        if ! [[ "$2" =~ ^[0-9]+\.?[0-9]*$ ]]; then
          echo "❌ 錯誤：速度倍率必須是正數，收到: $2"
          return 1
        fi
        if (( $(echo "$2 < 0.5 || $2 > 100.0" | bc -l) )); then
          echo "❌ 錯誤：速度倍率必須在 0.5-100.0 之間，收到: $2"
          return 1
        fi
        speed="$2"
        shift 2
        ;;
      -g)
        if [ -z "$2" ]; then
          echo "❌ 錯誤：-g 需要指定 grain 值"
          return 1
        fi
        if ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -lt 0 ] || [ "$2" -gt 15 ]; then
          echo "❌ 錯誤：grain 必須在 0-15 之間，收到: $2"
          return 1
        fi
        grain="$2"
        shift 2
        ;;
      *)
        echo "❌ 錯誤：未知參數: $1"
        return 1
        ;;
    esac
  done

  # 測試組合
  local crf_values=(30 35 40 45)
  local preset_values=(4 5 6)
  
  # 統計變數
  local total_tests=0
  local success_count=0
  local fail_count=0
  
  # 計算總測試數（加 1 用於原始裁切）
  local total_combinations=$((1 + ${#crf_values[@]} * ${#preset_values[@]}))
  local reference_file=""
  
  # 用於收集測試結果的陣列
  local -a test_results_name
  local -a test_results_size
  local -a test_results_time
  local -a test_results_ssim
  local -a test_results_psnr
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🧪 AV1 參數測試"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📂 輸入檔案: $input_file"
  echo "⏱️ 時間範圍: $start_time → $end_time"
  echo "⚡ 播放速度: ${speed}x"
  echo "🎥 Film Grain: $grain"
  echo "📊 測試組合: $total_combinations 個"
  echo "   • 原始裁切: 1 個 (作為品質基準)"
  echo "   • CRF: (30, 35, 40, 45)"
  echo "   • Preset: (4, 5, 6)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # 建立測試結果目錄
  local base_name="${input_file%.*}"
  local test_dir="${base_name}_av1_test"
  mkdir -p "$test_dir"
  
  echo "📁 測試輸出目錄: $test_dir"
  echo ""

  # 記錄總開始時間
  local total_start_time
  total_start_time=$(date +%s)

  # 先建立原始裁切版本作為基準
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
    
    local file_size
    file_size=$(stat -f%z "$orig_output" 2>/dev/null)
    if [ -n "$file_size" ]; then
      local size_fmt
      size_fmt=$(_ffmpeg_format_size "$file_size")
      echo "✅ 完成 - 大小: $size_fmt, 時間: ${test_duration}s"
      
      # 收集測試結果（原始裁切沒有 SSIM/PSNR）
      test_results_name+=("Original_Copy")
      test_results_size+=("$file_size")
      test_results_time+=("$test_duration")
      test_results_ssim+=("1.000")
      test_results_psnr+=("∞")
    fi
  else
    echo "❌ 裁切失敗"
    fail_count=$((fail_count + 1))
  fi
  echo ""

  # 測試組合
  for crf in "${crf_values[@]}"; do
    for preset in "${preset_values[@]}"; do
      total_tests=$((total_tests + 1))
      
      local output_name="${test_dir}/test_av1_crf${crf}_p${preset}.mp4"
      
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "🔄 測試 [$total_tests/$total_combinations]"
      echo "   CRF: $crf"
      echo "   Preset: $preset"
      echo ""
      
      # 構建命令
      local cmd_args=("$input_file" -ss "$start_time" -to "$end_time" -s "$speed" -c "$crf" -p "$preset" -g "$grain")
      
      # 記錄測試開始時間
      local test_start
      test_start=$(date +%s)
      
      # 執行轉換（隱藏詳細輸出）
      if toAv1 "${cmd_args[@]}" > /dev/null 2>&1; then
        local default_output="${base_name}.av1.mp4"
        if [ -f "$default_output" ]; then
          success_count=$((success_count + 1))
          
          # 計算測試時間
          local test_end
          test_end=$(date +%s)
          local test_duration=$((test_end - test_start))
          
          # 顯示檔案大小和時間
          local file_size
          file_size=$(stat -f%z "$default_output" 2>/dev/null)
          if [ -n "$file_size" ]; then
            local size_fmt
            size_fmt=$(_ffmpeg_format_size "$file_size")
            
            # 如果沒有參考檔案且這是第一個測試（CRF30 + preset4），設為參考
            if [ -z "$reference_file" ] && [ "$crf" = "30" ] && [ "$preset" = "4" ]; then
              # 先保存檔案，稍後設為參考
              local new_name="test_av1_crf${crf}_p${preset}_${test_duration}s.mp4"
              output_name="${test_dir}/${new_name}"
              mv "$default_output" "$output_name"
              reference_file="$output_name"
              
              echo "✅ 完成 - 大小: $size_fmt, 時間: ${test_duration}s"
              echo "   📌 設為品質基準"
              
              # 收集測試結果（第一個沒有 SSIM/PSNR）
              test_results_name+=("CRF${crf}_P${preset}")
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
                quality_result=$(_ffmpeg_calculate_quality "$reference_file" "$default_output")
                ssim_val=$(echo "$quality_result" | awk '{print $1}')
                psnr_val=$(echo "$quality_result" | awk '{print $2}')
              fi
              
              # 重命名檔案，包含 SSIM/PSNR/時間
              local new_name="test_av1_crf${crf}_p${preset}"
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
              test_results_name+=("CRF${crf}_P${preset}")
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
    done
  done

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
      size_fmt=$(_ffmpeg_format_size "$size")
      
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
