#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title 貼上時轉換 繁→簡
# @raycast.mode silent
# @raycast.icon 🀄
# @raycast.packageName Chinese Converter
# @raycast.description 流程：先 Cmd+C 複製繁體 → 觸發本 command → 自動 opencc t2s 轉換並 Cmd+V 貼上

set -e

OPENCC=/opt/homebrew/bin/opencc

# 從剪貼簿讀取（使用者已自行 Cmd+C）→ 轉換 → 寫回剪貼簿
pbpaste | "$OPENCC" -c t2s.json | pbcopy
sleep 0.1
# 模擬 Cmd+V 貼上（key code 9 = v；若 Zed 仍不接收，改裝 cliclick）
osascript -e 'tell application "System Events" to key code 9 using command down'
