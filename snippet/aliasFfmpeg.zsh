# ffmpeg相關
alias ffprobe="ffprobe -hide_banner"
alias ffp="ffprobe -hide_banner"
alias ffmpeg="ffmpeg -hide_banner"
alias ffm="ffmpeg -hide_banner"

alias ffmssim="ffmpeg_ssim_psnr"
function ffmpeg_ssim_psnr() {
  # 檢查入參是否包含檔名
  if [ -z "$1" ]; then
    echo "❌ 錯誤：請輸入第一個檔名"
    return 1
  fi
  if [ ! -f "$1" ]; then
    echo "❌ 錯誤：檔案 $1 不存在"
    return 1
  fi

  # 檢查入參是否包含檔名
  if [ -z "$2" ]; then
    echo "❌ 錯誤：請輸入第二個檔名"
    return 1
  fi
  if [ ! -f "$2" ]; then
    echo "❌ 錯誤：檔案 $2 不存在"
    return 1
  fi

  ffmpeg -i "$1" -i "$2" -lavfi "[0:v]setpts=PTS-STARTPTS[v0];[1:v] setpts=PTS-STARTPTS[v1];[v0][v1]ssim;[0:v]setpts=PTS-STARTPTS[v0];[1:v] setpts=PTS-STARTPTS[v1];[v0][v1]psnr" -f null -
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
  
  if [ "${#args[@]}" -eq 2 ]; then
    # 2個參數：第2個是時間
    output="${args[1]%.mp4}.ss.mp4"
  elif [ "${#args[@]}" -ge 3 ]; then
    # 3個或以上參數：第2個是輸出檔案，第3個是時間
    output="${args[2]}"
    start_time="${args[3]}"
  fi

  echo "📹 輸入檔案: ${args[1]}"
  echo "⏱️  開始時間: $start_time"
  echo "💾 輸出檔案: $output"

  # 執行ffmpeg命令
  if [ $has_overwrite -eq 1 ]; then
    ffmpeg -hide_banner -y -ss "$start_time" -i "${args[1]}" -c copy "$output"
  else
    ffmpeg -hide_banner -ss "$start_time" -i "${args[1]}" -c copy "$output"
  fi
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
  
  if [ "${#args[@]}" -eq 2 ]; then
    # 2個參數：第2個是時間
    output="${args[1]%.mp4}.to.mp4"
  elif [ "${#args[@]}" -ge 3 ]; then
    # 3個或以上參數：第2個是輸出檔案，第3個是時間
    output="${args[2]}"
    end_time="${args[3]}"
  fi

  echo "📹 輸入檔案: ${args[1]}"
  echo "⏱️  結束時間: $end_time"
  echo "💾 輸出檔案: $output"

  # 執行ffmpeg命令
  if [ $has_overwrite -eq 1 ]; then
    ffmpeg -hide_banner -y -to "$end_time" -i "${args[1]}" -c copy "$output"
  else
    ffmpeg -hide_banner -to "$end_time" -i "${args[1]}" -c copy "$output"
  fi
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
       echo "❌ 錯誤：參數不足"
       echo "📖 用法: ffmpeg_merge <輸出檔案> <輸入檔案1> <輸入檔案2> [輸入檔案3...]"
       return 1
   fi

   # 第一個參數是「輸出檔案名稱」
   local output_file="$1"

   # "shift" 移除 $1，讓 "$@" 只剩下「所有輸入檔案」
   shift

   # 1. 建立一個「安全」的暫存檔案
   # mktemp 會建立一個唯一的檔名 (例如: mylist.AbCDeF)
   # 並且只有目前使用者有權限讀寫
   local temp_list_file
   temp_list_file=$(mktemp mylist.XXXXXX)

   # 檢查 mktemp 是否成功
   if [ ! -f "$temp_list_file" ]; then
       echo "❌ 錯誤：無法建立暫存檔案"
       return 1
   fi

   # 2. 設定一個「陷阱」(trap)
   #    確保此函數 "RETURN" (結束) 時，無論成功或失敗，
   #    都會自動執行 "rm -f -- '$temp_list_file'" 來刪除暫存檔
   trap "rm -f -- '$temp_list_file'" EXIT

   echo "🔄 正在合併 ${#@} 個檔案..."
   echo "📁 輸出檔案: $output_file" # 讓您知道它建立了什麼
   echo "📁 使用暫存清單： $temp_list_file" # 讓您知道它建立了什麼

   # 3. 將檔案清單 (file '...') 寫入到暫存檔案中
   printf "file '%s'\n" "$@" > "$temp_list_file"

   # 4. 執行 FFmpeg
   #    -f concat -i "$temp_list_file" : 讀取我們的暫存清單
   #    (因為我們用的是實體檔案，不再需要 -safe 0 或 -protocol_whitelist)
   ffmpeg -f concat -i "$temp_list_file" -c copy "$output_file"

   # 5. 檢查 ffmpeg 是否成功執行
   local ffmpeg_exit_code=$?
   if [ $ffmpeg_exit_code -eq 0 ]; then
       echo "✅ 合併成功: $output_file"
   else
       echo "❌ 錯誤：FFmpeg 合併失敗 (錯誤碼: $ffmpeg_exit_code)"
       # 刪除可能已產生的不完整輸出檔案
       rm -f "$output_file"
   fi

   # 6. 函數即將結束，步驟 2 設定的 'trap' 會自動觸發，
   #    $temp_list_file 會被自動刪除。

   return $ffmpeg_exit_code
}

function toH265() {
  # 檢查入參是否包含檔名
  if [ -z "$1" ]; then
    echo "❌ 錯誤：請輸入檔名"
    return 1
  fi

  # 檢查檔案是否存在
  if [ ! -f "$1" ]; then
    echo "❌ 錯誤：檔案 $1 不存在"
    return 1
  fi

  # 如果只有一個入參，用ffprobe取得最大位元率
  if [ "$#" -eq 1 ]; then
    echo "📊 正在取得最大位元率..."
    maxrate=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 "$1")
  else
    maxrate="$2"
  fi

  echo "📊 最大位元率: $maxrate bps"

  # 執行ffmpeg命令
  echo "🎬 開始轉換為 H.265..."
  ffmpeg -hide_banner -hwaccel videotoolbox -i "$1" -c:v libx265 -vtag hvc1 -vcodec hevc_videotoolbox -maxrate "$maxrate" -q:v 95 -preset slow -c:a copy "${1%.mp4}.h265.mp4"
  echo "✅ 轉換完成: ${1%.mp4}.h265.mp4"
}
