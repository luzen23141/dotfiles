#!/bin/bash

# 必要參數：
# @raycast.schemaVersion 1
# @raycast.title Focus Gemini
# @raycast.mode silent

# 選填參數：
# @raycast.packageName Vivaldi Utils
# @raycast.icon 🤖

# 使用 AppleScript 控制 Vivaldi
osascript -e '
tell application "Vivaldi"
    activate
    set found to false
    
    -- 遍歷所有視窗和分頁
    repeat with w in windows
        set i to 1
        repeat with t in tabs of w
            if URL of t contains "gemini.google.com" then
                -- 找到目標分頁
                set active tab index of w to i
                set index of w to 1 -- 將視窗移到最上層
                set found to true
                return
            end if
            set i to i + 1
        end repeat
    end repeat
    
    -- 如果沒找到，就開啟新分頁
    if not found then
        open location "https://gemini.google.com/"
    end if
end tell
'
