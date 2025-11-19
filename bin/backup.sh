#!/bin/bash

# ==========================================
# 全域配置
# ==========================================
CONFIG_FILE="$HOME/Library/Mobile Documents/com~apple~CloudDocs/dotfiles_data/backup.json"
# ==========================================

# ------------------------------------------------
# 0. 環境檢查
# ------------------------------------------------
for cmd in jq rsync git; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "錯誤: 找不到指令 '$cmd'，請先安裝。"
        exit 1
    fi
done

if [ ! -f "$CONFIG_FILE" ]; then
    echo "錯誤: 找不到設定檔 $CONFIG_FILE"
    exit 1
fi

# ------------------------------------------------
# 路徑解析函數 (標準化路徑，去除 ../ 等)
# ------------------------------------------------
resolve_path() {
    local path="$1"
    
    # 如果路徑已經是絕對路徑，直接處理
    if [[ "$path" == /* ]]; then
        # 使用 Python 來標準化路徑，正確處理包含空格的路徑
        python3 -c "import os, sys; print(os.path.normpath(sys.argv[1]))" "$path" 2>/dev/null || echo "$path"
    else
        echo "$path"
    fi
}

# ------------------------------------------------
# 配置讀取與路徑計算
# ------------------------------------------------
# 1. 讀取 JSON
BACKUP_ROOT_RAW=$(jq -r '.backup_dir' "$CONFIG_FILE")

# 2. 替換 ~ 和 $HOME
BACKUP_ROOT_RAW="${BACKUP_ROOT_RAW/#\~/$HOME}"
BACKUP_ROOT_RAW="${BACKUP_ROOT_RAW//\$HOME/$HOME}"

# 3. 處理相對路徑 (相對於設定檔)
if [[ "$BACKUP_ROOT_RAW" != /* ]]; then
    # 取得設定檔所在目錄
    CONFIG_DIR="$(cd "$(dirname "$CONFIG_FILE")" && pwd)"
    BACKUP_ROOT_RAW="$CONFIG_DIR/$BACKUP_ROOT_RAW"
fi

# 4. 標準化路徑 (去除 ../ )
BACKUP_ROOT=$(resolve_path "$BACKUP_ROOT_RAW")

# 調試輸出（可選）
# echo "DEBUG: BACKUP_ROOT_RAW = $BACKUP_ROOT_RAW"
# echo "DEBUG: BACKUP_ROOT = $BACKUP_ROOT"


# ------------------------------------------------
# 1. 函數: 執行 Rsync 同步
# ------------------------------------------------
sync_files() {
    local src="$1"
    local dest="$2"
    local label="$3"

    if [ ! -e "$src" ]; then
        echo "   [跳過] 來源不存在: $src"
        return
    fi

    echo "   [$label/Sync] $src -> $dest"

    if [ -d "$src" ]; then
        # === 針對資料夾 ===
        if [ ! -d "$dest" ]; then
            mkdir -p "$dest"
        fi
        # 來源加斜線 = 複製內容
        rsync -a "$src/" "$dest/"
    else
        # === 針對檔案 ===
        local dest_dir
        dest_dir=$(dirname "$dest")
        if [ ! -d "$dest_dir" ]; then
            mkdir -p "$dest_dir"
        fi
        rsync -a "$src" "$dest"
    fi
}

# ------------------------------------------------
# 2. 函數: 處理軟連結
# ------------------------------------------------
handle_symlink() {
    local link_path="$1"      # 軟連結的位置
    local target_path="$2"    # 軟連結指向的目標
    local mode="$3"

    if [ "$mode" == "backup" ]; then
        # === 備份模式：不需要處理 ===
        echo "   [跳過] 軟連結無需備份: $link_path -> $target_path"
        
    elif [ "$mode" == "restore" ]; then
        # === 還原模式：建立軟連結 ===
        echo "   [還原/Symlink] 建立 $link_path -> $target_path"
        
        # 檢查目標是否存在
        if [ ! -e "$target_path" ]; then
            echo "   [警告] 目標不存在: $target_path"
        fi
        
        # 如果軟連結位置已存在，先刪除
        if [ -e "$link_path" ] || [ -L "$link_path" ]; then
            echo "   [提示] 刪除現有項目: $link_path"
            rm -rf "$link_path"
        fi
        
        # 確保父目錄存在
        local link_dir
        link_dir=$(dirname "$link_path")
        if [ ! -d "$link_dir" ]; then
            mkdir -p "$link_dir"
        fi
        
        # 建立軟連結
        ln -s "$target_path" "$link_path"
    fi
}

# ------------------------------------------------
# 3. 函數: 處理應用程式設定檔
# ------------------------------------------------
handle_app_config() {
    local app_name="$1"
    local plist_paths="$2"  # JSON 陣列字串
    local backup_dir="$3"
    local mode="$4"

    if [ "$mode" == "backup" ]; then
        # === 備份模式：複製 plist 檔案 ===
        echo "   [備份/App] $app_name"
        
        # 確保備份目錄存在
        if [ ! -d "$backup_dir" ]; then
            mkdir -p "$backup_dir"
        fi
        
        # 解析 plist 路徑陣列並複製
        local plist_count
        plist_count=$(echo "$plist_paths" | jq 'length')
        
        for ((j=0; j<plist_count; j++)); do
            local plist_path
            plist_path=$(echo "$plist_paths" | jq -r ".[$j]")
            
            # 處理路徑變數
            plist_path="${plist_path/#\~/$HOME}"
            plist_path="${plist_path//\$HOME/$HOME}"
            
            if [ -e "$plist_path" ]; then
                local plist_name
                plist_name=$(basename "$plist_path")
                echo "      複製: $plist_path"
                rsync -a "$plist_path" "$backup_dir/$plist_name"
            else
                echo "      [跳過] 不存在: $plist_path"
            fi
        done
        
    elif [ "$mode" == "restore" ]; then
        # === 還原模式：檢查運行狀態 -> 關閉應用 -> 複製 -> 開啟應用 ===
        echo "   [還原/App] $app_name"
        
        # 1. 檢查應用程式是否正在運行（使用 AppleScript）
        local app_was_running=false
        if osascript -e "tell application \"System Events\" to (name of processes) contains \"$app_name\"" 2>/dev/null | grep -q "true"; then
            app_was_running=true
            echo "      應用運行中，準備關閉: $app_name"
            
            # 使用 AppleScript 優雅地關閉應用程式
            osascript -e "tell application \"$app_name\" to quit" 2>/dev/null || {
                echo "      [警告] 無法正常關閉，嘗試強制關閉"
                # 如果正常關閉失敗，使用 killall 強制終止
                killall "$app_name" 2>/dev/null || true
            }
            
            # 等待應用完全關閉（最多等待 5 秒）
            local wait_count=0
            while [ $wait_count -lt 5 ]; do
                if ! osascript -e "tell application \"System Events\" to (name of processes) contains \"$app_name\"" 2>/dev/null | grep -q "true"; then
                    break
                fi
                sleep 1
                ((wait_count++))
            done
        else
            echo "      應用未運行: $app_name"
        fi
        
        # 2. 複製 plist 檔案
        local plist_count
        plist_count=$(echo "$plist_paths" | jq 'length')
        
        for ((j=0; j<plist_count; j++)); do
            local plist_path
            plist_path=$(echo "$plist_paths" | jq -r ".[$j]")
            
            # 處理路徑變數
            plist_path="${plist_path/#\~/$HOME}"
            plist_path="${plist_path//\$HOME/$HOME}"
            
            local plist_name
            plist_name=$(basename "$plist_path")
            local backup_file="$backup_dir/$plist_name"
            
            if [ -f "$backup_file" ]; then
                echo "      還原: $plist_path"
                # 確保目標目錄存在
                local plist_dir
                plist_dir=$(dirname "$plist_path")
                if [ ! -d "$plist_dir" ]; then
                    mkdir -p "$plist_dir"
                fi
                rsync -a "$backup_file" "$plist_path"
            else
                echo "      [跳過] 備份不存在: $backup_file"
            fi
        done
        
        # 3. 如果應用原本在運行，重新開啟
        if [ "$app_was_running" = true ]; then
            echo "      重新開啟應用: $app_name"
            killall cfprefsd
            sleep 1
            open -a "$app_name" 2>/dev/null || echo "      [警告] 無法開啟 $app_name"
        else
            echo "      應用原本未運行，不需開啟"
        fi
    fi
}

# ------------------------------------------------
# 4. 函數: 處理 Git 備份
# ------------------------------------------------
backup_git_repo() {
    local url="$1"
    local dest_path="$2"

    # 確保父目錄存在
    local dest_dir
    dest_dir=$(dirname "$dest_path")
    if [ ! -d "$dest_dir" ]; then
        mkdir -p "$dest_dir"
    fi

    if [ -d "$dest_path/.git" ]; then
        echo "   [Git/已存在] $dest_path"
#        git -C "$dest_path" pull --quiet
    elif [ -d "$dest_path" ] && [ -z "$(ls -A "$dest_path")" ]; then
        # 資料夾存在但是空的 -> 安全，直接 Clone
        echo "   [Git/下載] (空目錄) $url -> $dest_path"
        git clone --quiet "$url" "$dest_path"
    elif [ -d "$dest_path" ]; then
        # 資料夾存在，不是 Git 且不是空的 -> 危險
        echo "   [錯誤] 目標目錄存在但不是 Git 倉庫且不為空，略過 Clone: $dest_path"
    else
        # 資料夾不存在 -> 正常 Clone
        echo "   [Git/下載] $url -> $dest_path"
        git clone --quiet "$url" "$dest_path"
    fi
}

# ------------------------------------------------
# 4. 主邏輯
# ------------------------------------------------
main() {
    local mode="$1"
    local target_name="$2"  # 可選：只處理指定 name 的項目
    
    # 支援縮寫：b = backup, r = restore
    case "$mode" in
        b) mode="backup" ;;
        r) mode="restore" ;;
    esac
    
    local count
    count=$(jq '.files | length' "$CONFIG_FILE")

    echo "========================================"
    echo "模式: $mode"
    if [ -n "$target_name" ]; then
        echo "目標: $target_name (僅處理此項目)"
    fi
    echo "配置: $CONFIG_FILE"
    echo "倉庫: $BACKUP_ROOT"
    echo "========================================"

    for ((i=0; i<count; i++)); do
        local type name sys_path url target app_name plist_paths
        type=$(jq -r ".files[$i].type // \"file\"" "$CONFIG_FILE")
        name=$(jq -r ".files[$i].name" "$CONFIG_FILE")
        sys_path=$(jq -r ".files[$i].path" "$CONFIG_FILE")
        url=$(jq -r ".files[$i].url" "$CONFIG_FILE")
        target=$(jq -r ".files[$i].target" "$CONFIG_FILE")
        app_name=$(jq -r ".files[$i].app_name" "$CONFIG_FILE")
        plist_paths=$(jq -c ".files[$i].plist_paths" "$CONFIG_FILE")

        # 路徑計算
        local real_sys_path="${sys_path/#\~/$HOME}"
        real_sys_path="${real_sys_path//\$HOME/$HOME}"

        local base_name
        base_name=$(basename "$real_sys_path")

        # 如果指定了 target_name，只處理匹配的項目
        if [ -n "$target_name" ] && [ "$name" != "$target_name" ]; then
            continue
        fi

        local backup_container="$BACKUP_ROOT/$name"
        local real_backup_path="$backup_container/$base_name"

        echo "[$((i+1))/$count] 項目: $name (Type: $type)"

        if [ "$mode" == "backup" ]; then
            if [ "$type" == "git" ]; then
                # Git 倉庫本身就是備份，不需要額外處理
                echo "   [跳過] Git 倉庫無需備份: $real_sys_path"
            elif [ "$type" == "symlink" ]; then
                # 軟連結：備份時不需要處理
                local real_target="${target/#\~/$HOME}"
                real_target="${real_target//\$HOME/$HOME}"
                handle_symlink "$real_sys_path" "$real_target" "backup"
            elif [ "$type" == "app" ]; then
                # 應用程式設定檔
                if [ -z "$app_name" ] || [ "$app_name" == "null" ]; then
                    echo "   [錯誤] App 類型必須提供 app_name"
                elif [ -z "$plist_paths" ] || [ "$plist_paths" == "null" ]; then
                    echo "   [錯誤] App 類型必須提供 plist_paths"
                else
                    handle_app_config "$app_name" "$plist_paths" "$backup_container" "backup"
                fi
            else
                # 一般檔案
                if [ ! -d "$backup_container" ]; then
                    mkdir -p "$backup_container"
                fi
                sync_files "$real_sys_path" "$real_backup_path" "備份"
            fi

        elif [ "$mode" == "restore" ]; then
            if [ "$type" == "git" ]; then
                # Git 還原：從 URL clone 到系統路徑
                if [ -z "$url" ] || [ "$url" == "null" ]; then
                    echo "   [錯誤] Git 類型必須提供 url"
                else
                    backup_git_repo "$url" "$real_sys_path"
                fi
            elif [ "$type" == "symlink" ]; then
                # 軟連結：建立從 target 到 path 的軟連結
                if [ -z "$target" ] || [ "$target" == "null" ]; then
                    echo "   [錯誤] Symlink 類型必須提供 target"
                else
                    local real_target="${target/#\~/$HOME}"
                    real_target="${real_target//\$HOME/$HOME}"
                    handle_symlink "$real_sys_path" "$real_target" "restore"
                fi
            elif [ "$type" == "app" ]; then
                # 應用程式設定檔
                if [ -z "$app_name" ] || [ "$app_name" == "null" ]; then
                    echo "   [錯誤] App 類型必須提供 app_name"
                elif [ -z "$plist_paths" ] || [ "$plist_paths" == "null" ]; then
                    echo "   [錯誤] App 類型必須提供 plist_paths"
                else
                    handle_app_config "$app_name" "$plist_paths" "$backup_container" "restore"
                fi
            else
                # 一般檔案
                sync_files "$real_backup_path" "$real_sys_path" "還原"
            fi

        else
            echo "錯誤: 請使用 'backup' 或 'restore'"
            exit 1
        fi
        echo "----------------------------------------"
    done

    echo "作業完成！"
}

if [ -z "$1" ]; then
    echo "用法: $0 [backup|b|restore|r] [name]"
    echo "  backup|b:   備份模式"
    echo "  restore|r:  還原模式"
    echo "  name (可選): 只處理指定 name 的項目"
    echo ""
    echo "範例:"
    echo "  $0 b                # 備份所有項目"
    echo "  $0 backup           # 備份所有項目"
    echo "  $0 r rclone         # 只還原 name=rclone 的項目"
    echo "  $0 restore istat    # 只還原 name=istat 的項目"
    exit 1
fi

main "$1" "$2"