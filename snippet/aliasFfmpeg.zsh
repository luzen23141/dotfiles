# ffmpeg相關
alias ffprobe="ffprobe -hide_banner"
alias ffp="ffprobe -hide_banner"
alias ffmpeg="ffmpeg -hide_banner"
alias ffm="ffmpeg -hide_banner"

alias ffmssim="ffmpeg_ssim_psnr"
function ffmpeg_ssim_psnr() {
  # 檢查入參是否包含檔名
  if [ -z "$1" ]; then
    echo "請輸入檔名"
    return 1
  fi
  if [ ! -f "$1" ]; then
    echo "檔案 $1 不存在"
    return 1
  fi

  # 檢查入參是否包含檔名
  if [ -z "$2" ]; then
    echo "請輸入檔名"
    return 1
  fi
  if [ ! -f "$2" ]; then
    echo "檔案 $2 不存在"
    return 1
  fi

  ffmpeg -i "$1" -i "$2" -lavfi "[0:v]setpts=PTS-STARTPTS[v0];[1:v] setpts=PTS-STARTPTS[v1];[v0][v1]ssim;[0:v]setpts=PTS-STARTPTS[v0];[1:v] setpts=PTS-STARTPTS[v1];[v0][v1]psnr" -f null -
}

alias ffmss="ffmpeg_ss"
function ffmpeg_ss() {
  # 檢查入參是否包含檔名
  if [ -z "$1" ]; then
    echo "請輸入檔名"
    return 1
  fi

  # 檢查檔案是否存在
  if [ ! -f "$1" ]; then
    echo "檔案 $1 不存在"
    return 1
  fi

  # 檢查是否有兩個入參
  if [ "$#" -lt 2 ]; then
    echo "請輸入開始時間，格式參考ffmpeg -ss"
    return 1
  fi

  # 如果有第三個入參，output=第三個入參，沒有的話output=aaa.mp4
  if [ "$#" -eq 3 ]; then
    output="$3"
  else
    output="${1%.mp4}.ss.mp4"
  fi

  echo "檔案 $1 ，開始時間為 $2，輸出檔案為 $output"

  # 執行ffmpeg命令
  ffmpeg -hide_banner -ss "$2" -i "$1" -c copy "$output"
}

alias ffmto="ffmpeg_to"
function ffmpeg_to() {
  # 檢查入參是否包含檔名
  if [ -z "$1" ]; then
    echo "請輸入檔名"
    return 1
  fi

  # 檢查檔案是否存在
  if [ ! -f "$1" ]; then
    echo "檔案 $1 不存在"
    return 1
  fi

  # 檢查是否有兩個入參
  if [ "$#" -lt 2 ]; then
    echo "請輸入結束時間，格式參考ffmpeg -to"
    return 1
  fi

  # 如果有第三個入參，output=第三個入參，沒有的話output=aaa.mp4
  if [ "$#" -eq 3 ]; then
    output="$3"
  else
    output="${1%.mp4}.to.mp4"
  fi

  echo "檔案 $1 ，結束時間為 $2，輸出檔案為 $output"

  # 執行ffmpeg命令
  ffmpeg -hide_banner -to "$2" -i "$1" -c copy "$output"
}