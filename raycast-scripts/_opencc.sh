# 共用：尋找 opencc（Raycast PATH 常不含 Homebrew）
# 用法：source 後呼叫 resolve_opencc，成功時設定 OPENCC

resolve_opencc() {
  OPENCC="$(command -v opencc 2>/dev/null || true)"
  if [[ -z "$OPENCC" || ! -x "$OPENCC" ]]; then
    local candidate
    # 僅 Apple Silicon Homebrew；不偵測 /usr/local（Intel）
    for candidate in /opt/homebrew/bin/opencc; do
      if [[ -x "$candidate" ]]; then
        OPENCC="$candidate"
        break
      fi
    done
  fi
  if [[ -z "$OPENCC" || ! -x "$OPENCC" ]]; then
    echo "錯誤：找不到 opencc，請先安裝（brew install opencc）" >&2
    return 1
  fi
  return 0
}
