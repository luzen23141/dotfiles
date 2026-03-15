# ffmpeg相關
alias ffprobe="ffprobe -hide_banner"
alias ffp="ffprobe -hide_banner"
alias ffmpeg="ffmpeg -hide_banner"
alias ffm="ffmpeg -hide_banner"

#=======================================================================
# 函數名稱： ffmpeg_ssim_psnr
# 功    能： 比較兩個影片的品質差異 (SSIM 和 PSNR)
#           並分析結果提供品質評估
#
# 用法：
#   ffmpeg_ssim_psnr <參考影片> <比較影片>
#
# 範例：
#   ffmpeg_ssim_psnr "original.mp4" "compressed.mp4"
#
# 品質指標說明：
#   SSIM (結構相似性):
#     1.0        = 完全相同
#     ≥ 0.990    = 十分接近 (幾乎無法分辨)
#     ≥ 0.980    = 大多數人接受的範圍
#     0.950-0.980 = 良好品質 (有輕微差異)
#     < 0.950    = 品質不佳 (明顯損失)
#
#   PSNR (峰值信噪比):
#     ≥ 45 dB    = 十分接近 (視覺無損)
#     ≥ 42 dB    = 大多數人接受的範圍
#     38-42 dB   = 良好品質 (輕微壓縮痕跡)
#     < 38 dB    = 品質不佳 (損失明顯)
#=======================================================================
alias ffmssim="ffmpeg_ssim_psnr"
function ffmpeg_ssim_psnr() {
  # 檢查參數
  if [ "$#" -lt 2 ]; then
    echo ""
    echo "❌ 錯誤：參數不足"
    echo "📖 用法: ffmpeg_ssim_psnr <參考影片> <比較影片>"
    echo ""
    echo "範例:"
    echo "  ffmpeg_ssim_psnr original.mp4 compressed.mp4"
    echo ""
    return 1
  fi

  local reference="$1"
  local comparison="$2"

  # 檢查參考影片
  if [ ! -f "$reference" ]; then
    echo ""
    echo "❌ 錯誤：參考影片不存在: $reference"
    echo ""
    return 1
  fi

  # 檢查比較影片
  if [ ! -f "$comparison" ]; then
    echo ""
    echo "❌ 錯誤：比較影片不存在: $comparison"
    echo ""
    return 1
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📊 影片品質比較分析"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📹 參考影片: $reference"
  echo "📹 比較影片: $comparison"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "⏳ 正在分析影片品質..."
  echo ""

  # 建立臨時檔案儲存 ffmpeg 輸出
  local temp_output
  temp_output=$(mktemp)
  trap 'rm -f "$temp_output"' EXIT INT TERM

  # 執行 ffmpeg 並捕獲輸出
  ffmpeg -i "$reference" -i "$comparison" -lavfi "[0:v]setpts=PTS-STARTPTS[v0];[1:v]setpts=PTS-STARTPTS[v1];[v0][v1]ssim;[0:v]setpts=PTS-STARTPTS[v0];[1:v]setpts=PTS-STARTPTS[v1];[v0][v1]psnr" -f null - 2>&1 | tee "$temp_output"
  local ffmpeg_exit=$?

  if [ $ffmpeg_exit -ne 0 ]; then
    echo ""
    echo "❌ 錯誤：FFmpeg 執行失敗"
    echo ""
    return 1
  fi

  # 解析 SSIM 和 PSNR 結果
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📈 品質分析結果"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # 提取 SSIM 平均值
  local ssim_avg
  ssim_avg=$(grep "SSIM" "$temp_output" | grep "All:" | tail -1 | sed -n 's/.*All:\([0-9.]*\).*/\1/p')
  
  if [ -n "$ssim_avg" ]; then
    echo "🎯 SSIM (結構相似性):"
    echo "   平均值: $ssim_avg"
    
    # SSIM 品質評估 (專業標準)
    local ssim_quality
    if (( $(echo "$ssim_avg >= 0.990" | bc -l) )); then
      ssim_quality="✅ 十分接近 - 畫質幾乎無法分辨"
    elif (( $(echo "$ssim_avg >= 0.980" | bc -l) )); then
      ssim_quality="✅ 優秀 - 大多數人接受的範圍"
    elif (( $(echo "$ssim_avg >= 0.950" | bc -l) )); then
      ssim_quality="⚠️  良好 - 有輕微可見差異"
    else
      ssim_quality="❌ 不佳 - 明顯的品質損失"
    fi
    echo "   評估: $ssim_quality"
  else
    echo "⚠️  無法提取 SSIM 數據"
  fi

  echo ""

  # 提取 PSNR 平均值
  local psnr_avg
  psnr_avg=$(grep "PSNR" "$temp_output" | grep "average:" | tail -1 | sed -n 's/.*average:\([0-9.]*\).*/\1/p')
  
  if [ -n "$psnr_avg" ]; then
    echo "🎯 PSNR (峰值信噪比):"
    echo "   平均值: ${psnr_avg} dB"
    
    # PSNR 品質評估 (專業標準)
    local psnr_quality
    if (( $(echo "$psnr_avg >= 45" | bc -l) )); then
      psnr_quality="✅ 十分接近 - 畫質幾乎無法分辨"
    elif (( $(echo "$psnr_avg >= 42" | bc -l) )); then
      psnr_quality="✅ 優秀 - 大多數人接受的範圍"
    elif (( $(echo "$psnr_avg >= 38" | bc -l) )); then
      psnr_quality="⚠️  良好 - 有輕微壓縮痕跡"
    else
      psnr_quality="❌ 不佳 - 品質損失明顯"
    fi
    echo "   評估: $psnr_quality"
  else
    echo "⚠️  無法提取 PSNR 數據"
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "💡 建議:"
  
  if [ -n "$ssim_avg" ] && [ -n "$psnr_avg" ]; then
    if (( $(echo "$ssim_avg >= 0.990" | bc -l) )) && (( $(echo "$psnr_avg >= 45" | bc -l) )); then
      echo "   ✅ 壓縮效果極佳 - 兩個影片畫質十分接近，幾乎無法分辨"
    elif (( $(echo "$ssim_avg >= 0.980" | bc -l) )) && (( $(echo "$psnr_avg >= 42" | bc -l) )); then
      echo "   ✅ 壓縮效果優秀 - 達到大多數人接受的品質標準"
    elif (( $(echo "$ssim_avg >= 0.950" | bc -l) )) && (( $(echo "$psnr_avg >= 38" | bc -l) )); then
      echo "   ⚠️  品質良好，但未達最佳標準"
      echo "   建議：如需達到『大多數人接受』的範圍："
      echo "      • 降低 CRF 值 (建議 20-22)"
      echo "      • 或提高位元率至 4-6 Mbps"
    else
      echo "   ❌ 品質不符合專業標準"
      echo "   建議：大幅提高壓縮品質以達到可接受範圍："
      echo "      • 降低 CRF 值至 18-20 (目標 SSIM ≥ 0.980, PSNR ≥ 42dB)"
      echo "      • 或使用更高的位元率 (5-10 Mbps)"
      echo "      • 或考慮使用 slower/veryslow preset 提升編碼效率"
    fi
  fi
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

#=======================================================================
# 函數名稱： ffmpeg_vmaf
# 功    能： 使用 VMAF 模型比較兩個影片的品質差異
#           支援全片分析或指定時間區間分析
#
# 用法：
#   ffmpeg_vmaf <比較影片> <參考影片> [-ss start] [-to end] [-d|--dry-run]
#
# 範例：
#   ffmpeg_vmaf "aaa_av1_crf45_preset5.mp4" "aaa_raw.mp4"
#   ffmpeg_vmaf "aaa_av1_crf45_preset5.mp4" "aaa_raw.mp4" -ss 90 -to 120
#   ffmpeg_vmaf "aaa_av1_crf45_preset5.mp4" "aaa_raw.mp4" -d
#
# VMAF 品質指標說明：
#   VMAF 分數範圍: 0-100
#     ≥ 99       = 優秀品質 (視覺無損)
#     90-99      = 良好品質 (大多數人接受)
#     80-90      = 可接受品質 (輕微可見差異)
#     60-80      = 一般品質 (明顯但可容忍的差異)
#     < 60       = 品質不佳 (明顯的品質損失)
#
# 注意：需要 VMAF 模型檔案位於 /Users/alex/dotfiles/vmaf_v0.6.1.json
#=======================================================================
alias ffmvmaf="ffmpeg_vmaf"
function ffmpeg_vmaf() {
  # 檢查參數
  if [ "$#" -lt 2 ]; then
    echo ""
    echo "❌ 錯誤：參數不足"
    echo "📖 用法: ffmpeg_vmaf <比較影片> <參考影片> [-ss start] [-to end] [-d|--dry-run]"
    echo ""
    echo "📝 參數說明"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  比較影片      - 要測試的壓縮影片檔案（必填）"
    echo "  參考影片      - 原始參考影片檔案（必填）"
    echo "  -ss start     - 開始時間（可選）"
    echo "                  範例: -ss 00:01:30, -ss 90"
    echo "  -to end       - 結束時間（可選）"
    echo "                  範例: -to 00:05:00, -to 300"
    echo "  -d, --dry-run - 顯示完整命令但不執行（可選）"
    echo ""
    echo "💡 使用範例"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ffmvmaf aaa_av1_crf45_preset5.mp4 aaa_raw.mp4"
    echo "  ffmvmaf aaa_av1_crf45_preset5.mp4 aaa_raw.mp4 -ss 90 -to 120"
    echo "  ffmvmaf aaa_av1_crf45_preset5.mp4 aaa_raw.mp4 -d"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    return 1
  fi

  local comparison="$1"
  local reference="$2"
  shift 2
  
  # 參數變數
  local start_time=""
  local end_time=""
  local dry_run=false
  
  # 解析參數
  while [[ $# -gt 0 ]]; do
    case "$1" in
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

  # 檢查參考影片
  if [ ! -f "$reference" ]; then
    echo ""
    echo "❌ 錯誤：參考影片不存在: $reference"
    echo ""
    return 1
  fi

  # 檢查比較影片
  if [ ! -f "$comparison" ]; then
    echo ""
    echo "❌ 錯誤：比較影片不存在: $comparison"
    echo ""
    return 1
  fi

  # 檢查 VMAF 模型檔案
  local vmaf_model="/Users/alex/dotfiles/vmaf_v0.6.1.json"
  if [ ! -f "$vmaf_model" ]; then
    echo ""
    echo "❌ 錯誤：VMAF 模型檔案不存在: $vmaf_model"
    echo ""
    return 1
  fi

  # 取得 CPU 核心數量
  local cpu_cores
  if command -v nproc &> /dev/null; then
    cpu_cores=$(nproc)
  elif command -v sysctl &> /dev/null; then
    cpu_cores=$(sysctl -n hw.ncpu 2>/dev/null || echo "4")
  else
    cpu_cores="4"  # 預設值
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📊 VMAF 影片品質分析"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📹 比較影片: $comparison"
  echo "📹 參考影片: $reference"
  
  if [ -n "$start_time" ] && [ -n "$end_time" ]; then
    echo "⏱️  分析區間: ${start_time}s - ${end_time}s"
  else
    echo "⏱️  分析範圍: 全片"
  fi
  
  echo "🎯 VMAF 模型: $vmaf_model"
  echo "🧵 使用執行緒: ${cpu_cores} 個 CPU 核心"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "⏳ 正在執行 VMAF 分析..."
  echo ""

  # 建立 filter_complex 字串
  local filter_complex
  if [ -n "$start_time" ] && [ -n "$end_time" ]; then
    # 有指定時間區間
    filter_complex="[0:v]trim=start=${start_time}:end=${end_time},setpts=PTS-STARTPTS[dist];[1:v]trim=start=${start_time}:end=${end_time},setpts=PTS-STARTPTS[ref];[dist][ref]libvmaf=model=path=${vmaf_model}:log_path=vmaf_results.json:log_fmt=json:n_threads=${cpu_cores}"
  else
    # 全片分析
    filter_complex="[0:v]setpts=PTS-STARTPTS[dist];[1:v]setpts=PTS-STARTPTS[ref];[dist][ref]libvmaf=model=path=${vmaf_model}:log_path=vmaf_results.json:log_fmt=json:n_threads=${cpu_cores}"
  fi

  # 建立完整的 ffmpeg 命令
  local ffmpeg_cmd=(ffmpeg -i "$reference" -i "$comparison" -filter_complex "$filter_complex" -f null -)
  
  # 如果是 dry-run 模式，只顯示命令不執行
  if [ "$dry_run" = true ]; then
    echo "🔍 Dry-run 模式 - 將執行以下命令："
    echo ""
    printf '%q ' "${ffmpeg_cmd[@]}"
    echo ""
    echo ""
    echo "📄 VMAF 結果將儲存至: vmaf_results.json"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    return 0
  fi
  
  # 執行 ffmpeg VMAF 分析
  "${ffmpeg_cmd[@]}"
  local ffmpeg_exit=$?

  if [ $ffmpeg_exit -ne 0 ]; then
    echo ""
    echo "❌ 錯誤：FFmpeg VMAF 分析失敗"
    echo ""
    return 1
  fi

  # 檢查結果檔案是否存在
  if [ ! -f "vmaf_results.json" ]; then
    echo ""
    echo "❌ 錯誤：VMAF 結果檔案未產生"
    echo ""
    return 1
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📈 VMAF 分析結果"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # 解析 VMAF 結果 (從 JSON 檔案提取平均分數)
  local vmaf_score
  if command -v jq &> /dev/null; then
    # 使用 jq 解析 JSON
    vmaf_score=$(jq -r '.pooled_metrics.vmaf.mean' vmaf_results.json 2>/dev/null)
  else
    # 使用 grep 和 sed 解析 (備用方案)
    vmaf_score=$(grep -o '"mean":[0-9.]*' vmaf_results.json | head -1 | sed 's/"mean"://')
  fi

  if [ -n "$vmaf_score" ] && [ "$vmaf_score" != "null" ]; then
    echo "🎯 VMAF 分數:"
    printf "   平均值: %.2f\n" "$vmaf_score"
    
    # VMAF 品質評估
    local vmaf_quality
    if (( $(echo "$vmaf_score >= 99" | bc -l) )); then
      vmaf_quality="✅ 優秀品質 - 視覺無損，幾乎無法分辨差異"
    elif (( $(echo "$vmaf_score >= 90" | bc -l) )); then
      vmaf_quality="✅ 良好品質 - 大多數人接受的範圍"
    elif (( $(echo "$vmaf_score >= 80" | bc -l) )); then
      vmaf_quality="⚠️  可接受品質 - 輕微可見差異"
    elif (( $(echo "$vmaf_score >= 60" | bc -l) )); then
      vmaf_quality="⚠️  一般品質 - 明顯但可容忍的差異"
    else
      vmaf_quality="❌ 品質不佳 - 明顯的品質損失"
    fi
    echo "   評估: $vmaf_quality"
  else
    echo "⚠️  無法提取 VMAF 分數"
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "💡 建議:"
  
  if [ -n "$vmaf_score" ] && [ "$vmaf_score" != "null" ]; then
    if (( $(echo "$vmaf_score >= 99" | bc -l) )); then
      echo "   ✅ 壓縮效果極佳 - VMAF 分數達到視覺無損標準"
    elif (( $(echo "$vmaf_score >= 90" | bc -l) )); then
      echo "   ✅ 壓縮效果優秀 - 達到大多數人接受的品質標準"
    elif (( $(echo "$vmaf_score >= 80" | bc -l) )); then
      echo "   ⚠️  品質可接受，但可進一步優化"
      echo "   建議：提升壓縮品質以達到更好的 VMAF 分數："
      echo "      • 降低 CRF 值 (建議 15-20)"
      echo "      • 或提高位元率"
    else
      echo "   ❌ 品質不符合建議標準"
      echo "   建議：大幅提高壓縮品質："
      echo "      • 降低 CRF 值至 12-18 (目標 VMAF ≥ 90)"
      echo "      • 或使用更高的位元率"
      echo "      • 或考慮使用 slower/veryslow preset"
    fi
  fi
  
  echo ""
  echo "📄 詳細結果已儲存至: vmaf_results.json"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

alias ffmss="ffmpeg_ss"
function ffmpeg_ss() {
  # 過濾 -y 參數，建立不含 -y 的參數陣列
  local has_overwrite=0
  local args=()
  for arg in "$@"; do
    if [ "$arg" = "-y" ]; then
      has_overwrite=1
    else
      args+=("$arg")
    fi
  done

  # 檢查入參是否包含檔名
  if [ -z "${args[1]}" ]; then
    echo "❌ 錯誤：請輸入檔名"
    return 1
  fi

  # 檢查檔案是否存在
  if [ ! -f "${args[1]}" ]; then
    echo "❌ 錯誤：檔案 ${args[1]} 不存在"
    return 1
  fi

  # 檢查是否有兩個入參
  if [ "${#args[@]}" -lt 2 ]; then
    echo "❌ 錯誤：請輸入開始時間 (格式參考: ffmpeg -ss)"
    return 1
  fi

  # 根據過濾後的參數數量決定時間和輸出檔案
  local start_time="${args[2]}"
  local output
  local input_file="${args[1]}"
  
  if [ "${#args[@]}" -eq 2 ]; then
    # 2個參數：第2個是時間
    # 移除副檔名並加上 .ss.mp4
    local base_name="${input_file%.*}"
    local extension="${input_file##*.}"
    output="${base_name}.ss.${extension}"
  elif [ "${#args[@]}" -ge 3 ]; then
    # 3個或以上參數：第2個是輸出檔案，第3個是時間
    output="${args[2]}"
    start_time="${args[3]}"
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "✂️  影片裁剪 (從指定時間開始)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📹 輸入檔案: $input_file"
  echo "⏱️  開始時間: $start_time"
  echo "💾 輸出檔案: $output"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # 執行ffmpeg命令
  local ffmpeg_cmd=(ffmpeg -hide_banner)
  [ "$has_overwrite" -eq 1 ] && ffmpeg_cmd+=(-y)
  ffmpeg_cmd+=(-ss "$start_time" -i "$input_file" -c copy "$output")
  
  "${ffmpeg_cmd[@]}"
  local exit_code=$?
  
  echo ""
  if [ $exit_code -eq 0 ]; then
    echo "✅ 裁剪成功: $output"
  else
    echo "❌ 錯誤：裁剪失敗 (錯誤碼: $exit_code)"
  fi
  echo ""
  
  return $exit_code
}

alias ffmto="ffmpeg_to"
function ffmpeg_to() {
  # 過濾 -y 參數，建立不含 -y 的參數陣列
  local has_overwrite=0
  local args=()
  for arg in "$@"; do
    if [ "$arg" = "-y" ]; then
      has_overwrite=1
    else
      args+=("$arg")
    fi
  done

  # 檢查入參是否包含檔名
  if [ -z "${args[1]}" ]; then
    echo "❌ 錯誤：請輸入檔名"
    return 1
  fi

  # 檢查檔案是否存在
  if [ ! -f "${args[1]}" ]; then
    echo "❌ 錯誤：檔案 ${args[1]} 不存在"
    return 1
  fi

  # 檢查是否有兩個入參
  if [ "${#args[@]}" -lt 2 ]; then
    echo "❌ 錯誤：請輸入結束時間 (格式參考: ffmpeg -to)"
    return 1
  fi

  # 根據過濾後的參數數量決定時間和輸出檔案
  local end_time="${args[2]}"
  local output
  local input_file="${args[1]}"
  
  if [ "${#args[@]}" -eq 2 ]; then
    # 2個參數：第2個是時間
    # 移除副檔名並加上 .to.mp4
    local base_name="${input_file%.*}"
    local extension="${input_file##*.}"
    output="${base_name}.to.${extension}"
  elif [ "${#args[@]}" -ge 3 ]; then
    # 3個或以上參數：第2個是輸出檔案，第3個是時間
    output="${args[2]}"
    end_time="${args[3]}"
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "✂️  影片裁剪 (從開始到指定時間)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📹 輸入檔案: $input_file"
  echo "⏱️  結束時間: $end_time"
  echo "💾 輸出檔案: $output"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # 執行ffmpeg命令
  local ffmpeg_cmd=(ffmpeg -hide_banner)
  [ "$has_overwrite" -eq 1 ] && ffmpeg_cmd+=(-y)
  ffmpeg_cmd+=(-to "$end_time" -i "$input_file" -c copy "$output")
  
  "${ffmpeg_cmd[@]}"
  local exit_code=$?
  
  echo ""
  if [ $exit_code -eq 0 ]; then
    echo "✅ 裁剪成功: $output"
  else
    echo "❌ 錯誤：裁剪失敗 (錯誤碼: $exit_code)"
  fi
  echo ""
  
  return $exit_code
}

#=======================================================================
# 函數名稱： ffmpeg_merge
# 功    能： 無損合併多個影片檔案 (使用 ffmpeg -c copy)
#           此函數會動態產生檔案清單，無需手動建立 mylist.txt
#
# 用法：
#   ffmpeg_merge <輸出檔案> <輸入檔案1> <輸入檔案2> [輸入檔案3...]
#
# 範例：
#   ffmpeg_merge "final.mp4" "part1.mp4" "part2.mp4" "part3.mp4"
#
#=======================================================================
alias ffmm="ffmpeg_merge"
function ffmpeg_merge() {
  # 檢查參數數量
  if [ "$#" -lt 3 ]; then
    echo ""
    echo "❌ 錯誤：參數不足"
    echo "📖 用法: ffmpeg_merge <輸出檔案> <輸入檔案1> <輸入檔案2> [輸入檔案3...]"
    echo ""
    echo "範例:"
    echo "  ffmpeg_merge final.mp4 part1.mp4 part2.mp4 part3.mp4"
    echo ""
    return 1
  fi

  # 第一個參數是輸出檔案名稱
  local output_file="$1"
  shift

  # 檢查所有輸入檔案是否存在
  local missing_files=()
  for file in "$@"; do
    if [ ! -f "$file" ]; then
      missing_files+=("$file")
    fi
  done

  if [ "${#missing_files[@]}" -gt 0 ]; then
    echo ""
    echo "❌ 錯誤：以下檔案不存在："
    for file in "${missing_files[@]}"; do
      echo "   • $file"
    done
    echo ""
    return 1
  fi

  # 建立安全的暫存檔案
  local temp_list_file
  temp_list_file=$(mktemp)
  
  if [ ! -f "$temp_list_file" ]; then
    echo ""
    echo "❌ 錯誤：無法建立暫存檔案"
    echo ""
    return 1
  fi

  # 設定 trap 確保清理暫存檔案
  trap 'rm -f "$temp_list_file"' EXIT INT TERM

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔗 影片合併"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📁 輸出檔案: $output_file"
  echo "📝 輸入檔案: ${#@} 個"
  
  local i=1
  for file in "$@"; do
    echo "   $i. $file"
    i=$((i + 1))
  done
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "⏳ 正在合併影片..."
  echo ""

  # 將檔案清單寫入暫存檔案
  printf "file '%s'\n" "$@" > "$temp_list_file"

  # 執行 FFmpeg
  ffmpeg -f concat -safe 0 -i "$temp_list_file" -c copy "$output_file"
  local ffmpeg_exit_code=$?

  echo ""
  if [ $ffmpeg_exit_code -eq 0 ]; then
    # 顯示輸出檔案大小
    if command -v stat &> /dev/null; then
      local output_size
      output_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null)
      if [ -n "$output_size" ]; then
        local size_mb
        size_mb="$(echo "scale=2; $output_size / 1048576" | bc)"
        echo "✅ 合併成功: $output_file (${size_mb} MB)"
      else
        echo "✅ 合併成功: $output_file"
      fi
    else
      echo "✅ 合併成功: $output_file"
    fi
  else
    echo "❌ 錯誤：FFmpeg 合併失敗 (錯誤碼: $ffmpeg_exit_code)"
    # 刪除可能已產生的不完整輸出檔案
    if [ -f "$output_file" ]; then
      rm -f "$output_file"
      echo "   已清理不完整的輸出檔案"
    fi
  fi
  echo ""

  return $ffmpeg_exit_code
}
