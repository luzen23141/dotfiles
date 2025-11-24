is_color() {
    # 設定閾值 (0.01 是經過測試區分泛黃/彩色最穩定的值)
    local THRESHOLD=0.01

    # 檢查是否有傳入參數
    if [ $# -eq 0 ]; then
        echo "用法: check_image_bw <圖片路徑...>"
        echo "範例: check_image_bw *.png"
        return 1
    fi

    local file stats std_a std_b deviation is_bw

    # "$@" 會自動處理 shell 展開後的檔案列表 (例如 *.png)
    for file in "$@"; do
        # 1. 檢查檔案是否存在且為普通檔案 (避開資料夾)
        if [ ! -f "$file" ]; then
            continue
        fi

        # 2. 核心邏輯：轉 Lab 色彩空間 -> 取 a, b 通道標準差
        # 使用 2>/dev/null 隱藏可能的非圖片檔案錯誤
        stats=$(magick "$file" -colorspace Lab -format "%[fx:standard_deviation.g] %[fx:standard_deviation.b]" info: 2>/dev/null)

        # 如果讀取失敗 (例如不是圖片)，則跳過
        if [ -z "$stats" ]; then
            echo "[略過] $file (非圖片或無法讀取)"
            continue
        fi

        # 3. 解析數值 (將空白分隔的字串拆給變數)
        read std_a std_b <<< "$stats"

        # 4. 計算與判斷 (交給 awk 處理浮點數運算)
        # 邏輯：計算顏色向量長度 sqrt(a^2 + b^2)，小於閾值即為黑白
        is_bw=$(awk -v a="$std_a" -v b="$std_b" -v th="$THRESHOLD" 'BEGIN {
            deviation = sqrt(a*a + b*b);
            print (deviation < th) ? 1 : 0
        }')

        # 5. 輸出結果
        if [ "$is_bw" -eq 1 ]; then
            echo "[黑白] $file"
        else
            echo "[彩色] $file"
        fi
    done
}