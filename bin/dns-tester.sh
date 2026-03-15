#!/usr/bin/env bash

set -euo pipefail

TIMEOUT_MS=500
LOOP_COUNT=1
BUST_CACHE=0
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dns-tester"
CONFIG_FILE="$CONFIG_DIR/config.sh"

DNS_SERVERS=(
    "1.1.1.1|Cloudflare (主)|隱私優先、極速解析"
    "1.0.0.1|Cloudflare (備)|備用節點"
    "8.8.8.8|Google (主)|穩定度高、解析精準"
    "8.8.4.4|Google (備)|備用節點"
    "9.9.9.9|Quad9 (主)|惡意網站攔截"
    "149.112.112.112|Quad9 (備)|備用節點"
    "208.67.222.222|OpenDNS (主)|Cisco 企業級解析"
    "208.67.220.220|OpenDNS (備)|備用節點"
    "168.95.1.1|中華電信 (主)|台灣連線首選"
    "168.95.192.1|中華電信 (備)|備用節點"
    "101.101.101.101|Quad101 (主)|本地延遲極低"
    "101.102.103.104|Quad101 (備)|備用節點"
    "94.140.14.14|AdGuard (主)|阻擋廣告與追蹤"
    "94.140.15.15|AdGuard (備)|備用節點"
    "76.76.2.0|Control D (主)|安全與隱私防禦"
    "76.76.10.0|Control D (備)|備用節點"
    "95.85.95.85|Gcore (主)|全球節點、無日誌"
    "2.56.220.2|Gcore (備)|備用節點"
    "156.154.70.1|Neustar (主)|原 Verisign、高可靠性"
    "156.154.71.1|Neustar (備)|備用節點"
    "45.90.28.0|NextDNS (主)|注重隱私、可自訂規則"
    "45.90.30.0|NextDNS (備)|備用節點"
)

DOMAINS=(
    "google.com.tw|Google 台灣"
    "line.me|LINE 通訊"
    "shopee.tw|蝦皮購物"
    "gamer.com.tw|巴哈姆特"
    "github.com|GitHub 原始碼"
    "pkg.go.dev|Go 套件庫"
    "registry.npmjs.org|NPM 註冊表"
    "hub.docker.com|Docker Hub"
    "openai.com|OpenAI"
    "chatgpt.com|ChatGPT"
    "anthropic.com|Anthropic"
    "claude.ai|Claude"
    "gemini.google.com|Google Gemini"
    "perplexity.ai|Perplexity"
    "poe.com|Poe"
    "huggingface.co|Hugging Face"
    "replicate.com|Replicate"
    "cloudflare.com|Cloudflare"
    "agubear.black|個人網站"
)

RES_DIR=""
RESULTS_FILE=""
REPORT_FILE=""
ACTIVE_SERVICE=""
DEFAULT_IFACE=""
CURRENT_DNS_DISPLAY=""
TOP_1_IP=""
TOP_2_IP=""
DIG_TIMEOUT_SEC=1
TOTAL_DNS=0
TOTAL_DOMAINS=0
BG_PIDS=()
CURRENT_DNS_ARRAY=()

show_help() {
    cat <<EOF
DNS 效能深度評測工具（macOS）

用法: $0 [選項]

選項:
  -t, --timeout <毫秒>  超時限制 (預設: 500ms)
  -c, --count <次數>    測試循環次數 (預設: 1次)
  -b, --bust-cache      啟用破壞快取模式 (測試真實遞迴實力)
  -h, --help            顯示此說明
EOF
}

err() {
    printf '錯誤: %s\n' "$1" >&2
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || err "找不到 $1 指令"
}

parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -t|--timeout)
                [[ -n "${2:-}" ]] || err "--timeout 需要毫秒值"
                TIMEOUT_MS="$2"
                shift 2
                ;;
            -c|--count)
                [[ -n "${2:-}" ]] || err "--count 需要次數"
                LOOP_COUNT="$2"
                shift 2
                ;;
            -b|--bust-cache)
                BUST_CACHE=1
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                err "未知參數: $1"
                ;;
        esac
    done

    [[ "$TIMEOUT_MS" =~ ^[0-9]+$ ]] && [[ "$TIMEOUT_MS" -gt 0 ]] || err "--timeout 必須是大於 0 的整數毫秒值"
    [[ "$LOOP_COUNT" =~ ^[0-9]+$ ]] && [[ "$LOOP_COUNT" -gt 0 ]] || err "--count 必須是大於 0 的整數"
}

check_platform() {
    [[ "$(uname)" == "Darwin" ]] || err "此腳本目前僅支援 macOS"
}

check_dependencies() {
    local cmd
    for cmd in dig ping sort column networksetup dscacheutil killall route mktemp; do
        require_cmd "$cmd"
    done
}

load_config() {
    [[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"
}

cleanup_bg_jobs() {
    local pid

    for pid in "${BG_PIDS[@]:-}"; do
        [[ -n "$pid" ]] || continue
        kill "$pid" 2>/dev/null || true
    done

    for pid in "${BG_PIDS[@]:-}"; do
        [[ -n "$pid" ]] || continue
        wait "$pid" 2>/dev/null || true
    done
}

cleanup() {
    cleanup_bg_jobs
    [[ -n "$RES_DIR" && -d "$RES_DIR" ]] && command rm -rf "$RES_DIR"
}

handle_interrupt() {
    printf '\n收到中斷，正在清理背景工作...\n' >&2
    cleanup_bg_jobs
    exit 130
}

detect_active_service() {
    local line
    local previous_line=""

    while IFS= read -r line; do
        case "$line" in
            *"interface: "*)
                DEFAULT_IFACE="${line##*interface: }"
                ;;
        esac
    done < <(route -n get default 2>/dev/null)

    [[ -n "$DEFAULT_IFACE" ]] || err "無法偵測預設網路介面"

    while IFS= read -r line; do
        if [[ "$line" == *"Device: $DEFAULT_IFACE"* ]]; then
            ACTIVE_SERVICE="${previous_line#*) }"
            break
        fi

        case "$line" in
            \([0-9]*\)* )
                previous_line="$line"
                ;;
        esac
    done < <(networksetup -listnetworkserviceorder 2>/dev/null)

    [[ -n "$ACTIVE_SERVICE" ]] || err "無法找到介面 $DEFAULT_IFACE 對應的 macOS 網路服務"
}

detect_current_dns() {
    local line

    CURRENT_DNS_ARRAY=()
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        case "$line" in
            "There aren't any DNS Servers set on"*)
                break
                ;;
        esac
        CURRENT_DNS_ARRAY+=("$line")
    done < <(networksetup -getdnsservers "$ACTIVE_SERVICE" 2>/dev/null || true)

    if [[ "${#CURRENT_DNS_ARRAY[@]}" -eq 0 ]]; then
        CURRENT_DNS_DISPLAY="系統自動"
        return
    fi

    CURRENT_DNS_DISPLAY="${CURRENT_DNS_ARRAY[0]}"
    local i
    for ((i = 1; i < ${#CURRENT_DNS_ARRAY[@]}; i++)); do
        CURRENT_DNS_DISPLAY+=", ${CURRENT_DNS_ARRAY[$i]}"
    done
}

init_environment() {
    RES_DIR=$(mktemp -d "${TMPDIR:-/tmp}/dns-tester.XXXXXX") || err "無法建立暫存目錄"
    RESULTS_FILE="$RES_DIR/results.txt"
    REPORT_FILE="$RES_DIR/report.txt"
    TOTAL_DNS=${#DNS_SERVERS[@]}
    TOTAL_DOMAINS=${#DOMAINS[@]}
    DIG_TIMEOUT_SEC=$(((TIMEOUT_MS + 999) / 1000))

    detect_active_service
    detect_current_dns
}

is_current_dns() {
    local dns_ip="$1"
    local current_dns

    for current_dns in "${CURRENT_DNS_ARRAY[@]:-}"; do
        [[ "$current_dns" == "$dns_ip" ]] && return 0
    done

    return 1
}

measure_ping_ms() {
    local dns_ip="$1"
    local output
    local line
    local stats
    local avg

    if ! output=$(ping -c 2 -W "$TIMEOUT_MS" -q "$dns_ip" 2>/dev/null); then
        printf '999\n'
        return
    fi

    while IFS= read -r line; do
        case "$line" in
            *"round-trip"*|*"rtt "*)
                stats="${line#*= }"
                stats="${stats% ms*}"
                avg="${stats#*/}"
                avg="${avg%%/*}"
                printf '%s\n' "${avg%%.*}"
                return
                ;;
        esac
    done <<< "$output"

    printf '999\n'
}

measure_query_time_ms() {
    local dns_ip="$1"
    local target="$2"
    local line
    local query_time=""

    while IFS= read -r line; do
        case "$line" in
            *"Query time:"*)
                query_time="${line#*Query time: }"
                query_time="${query_time%% ms*}"
                break
                ;;
        esac
    done < <(dig @"$dns_ip" "$target" +noall +stats +time="$DIG_TIMEOUT_SEC" +tries=1 2>/dev/null)

    printf '%s\n' "$query_time"
}

run_dns_worker() {
    set +e

    local index="$1"
    local dns_ip provider note
    local ping_ms ping_str
    local success=0
    local fail=0
    local total_time=0
    local total_queries=0
    local avg_ms=999999
    local avg_str="超時"
    local sort_value=999999
    local color_tag="R"
    local success_rate="0%"
    local is_current=0
    local c entry domain_url target query_time
    local result_tmp="$RES_DIR/result_${index}.tmp"
    local result_file="$RES_DIR/result_${index}"

    IFS='|' read -r dns_ip provider note <<< "${DNS_SERVERS[$index]}"
    ping_ms=$(measure_ping_ms "$dns_ip")
    ping_str=$([[ "$ping_ms" == "999" ]] && printf '超時' || printf '%s ms' "$ping_ms")

    for ((c = 1; c <= LOOP_COUNT; c++)); do
        for entry in "${DOMAINS[@]}"; do
            IFS='|' read -r domain_url _ <<< "$entry"
            if [[ "$BUST_CACHE" -eq 1 ]]; then
                target="${RANDOM}.${c}.${domain_url}"
            else
                target="$domain_url"
            fi

            query_time=$(measure_query_time_ms "$dns_ip" "$target")
            if [[ "$query_time" =~ ^[0-9]+$ ]] && [[ "$query_time" -le "$TIMEOUT_MS" ]]; then
                success=$((success + 1))
                total_time=$((total_time + query_time))
            else
                fail=$((fail + 1))
            fi
        done
    done

    total_queries=$((success + fail))
    if [[ "$success" -gt 0 ]]; then
        avg_ms=$((total_time / success))
        avg_str="$avg_ms ms"
        sort_value=$((avg_ms + (ping_ms / 2) + (fail * 1000)))

        if [[ "$avg_ms" -lt 30 ]]; then
            color_tag="G"
        elif [[ "$avg_ms" -lt 80 ]]; then
            color_tag="Y"
        else
            color_tag="R"
        fi
    fi

    if [[ "$total_queries" -gt 0 ]]; then
        success_rate="$((success * 100 / total_queries))%"
    fi

    if is_current_dns "$dns_ip"; then
        is_current=1
    fi

    {
        printf 'dns_ip=%s\n' "$dns_ip"
        printf 'provider=%s\n' "$provider"
        printf 'note=%s\n' "$note"
        printf 'ping_ms=%s\n' "$ping_ms"
        printf 'ping_str=%s\n' "$ping_str"
        printf 'success=%s\n' "$success"
        printf 'fail=%s\n' "$fail"
        printf 'total_time=%s\n' "$total_time"
        printf 'avg_ms=%s\n' "$avg_ms"
        printf 'avg_str=%s\n' "$avg_str"
        printf 'sort_value=%s\n' "$sort_value"
        printf 'color_tag=%s\n' "$color_tag"
        printf 'success_rate=%s\n' "$success_rate"
        printf 'is_current=%s\n' "$is_current"
    } > "$result_tmp"

    mv "$result_tmp" "$result_file"
}

start_dns_workers() {
    local i

    for ((i = 0; i < TOTAL_DNS; i++)); do
        run_dns_worker "$i" &
        BG_PIDS+=("$!")
    done
}

count_completed_workers() {
    local count=0
    local path

    for path in "$RES_DIR"/result_*; do
        [[ -e "$path" ]] || continue
        count=$((count + 1))
    done

    printf '%s\n' "$count"
}

show_progress() {
    local completed=0
    local percent=0
    local filled=0
    local bar=""
    local i

    while [[ "$completed" -lt "$TOTAL_DNS" ]]; do
        completed=$(count_completed_workers)
        percent=$((completed * 100 / TOTAL_DNS))
        filled=$((percent / 5))
        bar=""

        for ((i = 0; i < filled; i++)); do
            bar+="#"
        done

        printf "\r執行進度: [%-20s] %d%% (%d/%d)" "$bar" "$percent" "$completed" "$TOTAL_DNS"
        [[ "$completed" -ge "$TOTAL_DNS" ]] && break
        sleep 0.2
    done

    printf "\r\033[K分析完成，正在彙整排名數據...\n"
}

wait_for_workers() {
    local pid

    for pid in "${BG_PIDS[@]}"; do
        wait "$pid"
    done
}

collect_results() {
    local path
    local dns_ip provider note ping_str avg_str success_rate color_tag is_current sort_value
    local provider_display
    local line key value

    : > "$RESULTS_FILE"

    for path in "$RES_DIR"/result_*; do
        [[ -e "$path" ]] || continue

        dns_ip=""
        provider=""
        note=""
        ping_str=""
        avg_str=""
        success_rate=""
        color_tag="R"
        is_current=0
        sort_value=999999

        while IFS='=' read -r key value; do
            case "$key" in
                dns_ip) dns_ip="$value" ;;
                provider) provider="$value" ;;
                note) note="$value" ;;
                ping_str) ping_str="$value" ;;
                avg_str) avg_str="$value" ;;
                success_rate) success_rate="$value" ;;
                color_tag) color_tag="$value" ;;
                is_current) is_current="$value" ;;
                sort_value) sort_value="$value" ;;
            esac
        done < "$path"

        provider_display="$provider"
        if [[ "$is_current" == "1" ]]; then
            provider_display+=" 📌"
        fi

        printf '%s|%s|%s|%s|%s|%s|%s|%s\n' \
            "$sort_value" \
            "$color_tag" \
            "$provider_display" \
            "$dns_ip" \
            "$note" \
            "$ping_str" \
            "$avg_str" \
            "$success_rate" >> "$RESULTS_FILE"
    done
}

print_report() {
    local rank=1
    local sort_value color_tag provider_display dns_ip note ping_str avg_str success_rate
    local line

    printf '排名|伺服器 (IP)|備註|Ping 延遲|平均解析|解析成功率\n' > "$REPORT_FILE"

    while IFS='|' read -r sort_value color_tag provider_display dns_ip note ping_str avg_str success_rate; do
        [[ -n "$dns_ip" ]] || continue

        if [[ "$rank" -eq 1 ]]; then
            TOP_1_IP="$dns_ip"
        elif [[ "$rank" -eq 2 ]]; then
            TOP_2_IP="$dns_ip"
        fi

        printf '[%s]%s|%s (%s)|%s|%s|%s|%s\n' \
            "$color_tag" \
            "$rank" \
            "$provider_display" \
            "$dns_ip" \
            "$note" \
            "$ping_str" \
            "$avg_str" \
            "$success_rate" >> "$REPORT_FILE"

        rank=$((rank + 1))
    done < <(sort -n -t '|' -k1,1 "$RESULTS_FILE")

    while IFS= read -r line; do
        case "$line" in
            *"排名"*)
                printf '\033[1m%s\033[0m\n' "$line"
                ;;
            *"[G]"*)
                printf '\033[32m%s\033[0m\n' "${line//\[G\]/ }"
                ;;
            *"[Y]"*)
                printf '\033[33m%s\033[0m\n' "${line//\[Y\]/ }"
                ;;
            *"[R]"*)
                printf '\033[31m%s\033[0m\n' "${line//\[R\]/ }"
                ;;
            *)
                printf '%s\n' "$line"
                ;;
        esac
    done < <(column -t -s '|' "$REPORT_FILE")
}

print_header() {
    printf '\n\033[1m[ DNS 效能評測報告 ]\033[0m\n'
    printf '當前 DNS 設定: \033[33m%s\033[0m\n' "$CURRENT_DNS_DISPLAY"
    printf '目標服務: %s (%s)\n' "$ACTIVE_SERVICE" "$DEFAULT_IFACE"
    printf '測試模式: %s\n' "$([[ "$BUST_CACHE" -eq 1 ]] && printf '破壞快取 (Bust Cache)' || printf '標準 (Standard)')"
    printf '測試樣本: %s 伺服器 / %s 網域 / %s 循環\n' "$TOTAL_DNS" "$TOTAL_DOMAINS" "$LOOP_COUNT"
    printf -- '----------------------------------------------------------------------------------------------------------------\n'
}

apply_dns() {
    local apply
    local dns_to_apply=()

    [[ -n "$TOP_1_IP" ]] || err "找不到可套用的 DNS 排名結果"

    printf '\n\033[1m[ 專業配置建議 ]\033[0m\n'
    if [[ -n "$TOP_2_IP" ]]; then
        printf '首選 DNS: \033[32m%s\033[0m  次選 DNS: \033[32m%s\033[0m\n' "$TOP_1_IP" "$TOP_2_IP"
    else
        printf '首選 DNS: \033[32m%s\033[0m\n' "$TOP_1_IP"
    fi

    printf '\n如需自動套用並刷新快取，請輸入 \033[1my\033[0m 確認，其餘按鍵取消。\n'
    read -r -p "> " apply

    if [[ "$apply" != "y" ]]; then
        printf '已取消變更。\n'
        return
    fi

    dns_to_apply=("$TOP_1_IP")
    [[ -n "$TOP_2_IP" ]] && dns_to_apply+=("$TOP_2_IP")

    printf '執行中...\n'
    sudo networksetup -setdnsservers "$ACTIVE_SERVICE" "${dns_to_apply[@]}"
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder
    printf '\033[32m配置已更新成功。\033[0m\n'
}

main() {
    trap 'handle_interrupt' INT TERM
    trap 'cleanup' EXIT

    parse_args "$@"
    check_platform
    check_dependencies
    load_config
    init_environment
    print_header
    start_dns_workers
    show_progress
    wait_for_workers
    printf -- '----------------------------------------------------------------------------------------------------------------\n'
    collect_results
    print_report
    apply_dns
}

main "$@"
