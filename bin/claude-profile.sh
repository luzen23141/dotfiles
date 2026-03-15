#!/usr/bin/env bash

set -euo pipefail

ENV_FILE="$HOME/.config/ai_config/.env"
if [ -f "$ENV_FILE" ]; then
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    value="${value#\"}" ; value="${value%\"}"
    value="${value#\'}"  ; value="${value%\'}"
    export "$key=$value"
  done < "$ENV_FILE"
fi

TOOL_NAME_RAW="$(basename "$0")"
TOOL_NAME="${TOOL_NAME_RAW%.*}"
CONFIG_PATH="$HOME/.config/ai_config/claude_profile.json"

usage() {
  cat <<EOF
用法:
  $TOOL_NAME [--dry-run|-n] <name_or_alias> [model] [claude_args...]

選項:
  --dry-run, -n  只顯示解析結果與最終會執行的 claude 指令，不實際執行

設定檔:
  $CONFIG_PATH

特殊名稱:
  claude          使用原生 claude，不套用任何 provider 設定，直接轉發後續參數

JSON 格式:
{
  "claude_alias": ["cc", "native"],   // 原生模式的別名（選填）
  "providers": {
    "banana": {
      "aliases": ["ba", "星狐雲"],
      "auth_token": "...",
      "base_url": "...",
      "prompt_file": "/path/to/prompt.md",
      "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4-6",
      "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-4-6",
      "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-haiku-4-5-20251001",
      "CLAUDE_CODE_SUBAGENT_MODEL": "haiku",
      "enabled_models": ["gpt-3.5-turbo", "gpt-4"]
    }
  }
}
EOF
}

err() {
  printf '錯誤: %s\n' "$1" >&2
  exit 1
}

quote_args() {
  local out=""
  local arg

  for arg in "$@"; do
    if [ -n "$out" ]; then
      out+=" "
    fi
    out+="$(printf '%q' "$arg")"
  done

  printf '%s\n' "$out"
}

command -v claude >/dev/null 2>&1 || err "找不到 claude 指令"

if [ $# -eq 0 ]; then
  exec claude
fi

dry_run=0
if [ "${1:-}" = "--dry-run" ] || [ "${1:-}" = "-n" ]; then
  dry_run=1
  shift
fi

[ $# -ge 1 ] || {
  usage
  exit 1
}

[ -f "$CONFIG_PATH" ] || err "設定檔不存在: $CONFIG_PATH"
jq -e '.providers | type == "object"' "$CONFIG_PATH" >/dev/null 2>&1 || err "設定檔必須是包含 providers 的 JSON object"

query="$1"
shift

command -v jq >/dev/null 2>&1 || err "找不到 jq，請先安裝 jq"

# 原生 claude 模式：query 為 "claude" 或 claude_alias 中的別名
is_native=0
query_lc="$(printf '%s' "$query" | tr '[:upper:]' '[:lower:]')"
if [ "$query_lc" = "claude" ]; then
  is_native=1
else
  native_match="$(jq -r --arg q "$query_lc" '
    def lc: ascii_downcase;
    (.claude_alias // []) | map(tostring | lc) | index($q)
  ' "$CONFIG_PATH")"
  [ "$native_match" != "null" ] && is_native=1
fi

if [ "$is_native" -eq 1 ]; then
  if [ "$dry_run" -eq 1 ]; then
    printf '試執行：原生 claude 模式\n'
    printf '試執行：指令\n'
    printf '  claude %s\n' "$(quote_args "$@")"
    exit 0
  fi
  exec claude "$@"
fi

match_names="$(
  jq -r --arg q "$query" '
    def lc: ascii_downcase;
    [
      .providers | to_entries[]
      | .key as $name
      | (.value // {}) as $cfg
      | ($cfg.aliases // []) as $aliases
      | select(
          ($name | lc) == ($q | lc)
          or (
            (($aliases | type) == "array")
            and (($aliases | map(tostring | lc) | index($q | lc)) != null)
          )
        )
      | $name
    ]
    | unique
    | .[]
  ' "$CONFIG_PATH"
)"

match_count="$(printf '%s\n' "$match_names" | awk 'NF{count++} END{print count+0}')"

if [ "$match_count" -eq 0 ]; then
  err "找不到對應設定: $query"
fi

if [ "$match_count" -gt 1 ]; then
  err "命中多個設定（alias 衝突）: $(printf '%s' "$match_names" | paste -sd ', ' -)"
fi

profile_name="$(printf '%s\n' "$match_names" | awk 'NF{print; exit}')"

if [ $# -ge 1 ] && [[ "$1" != -* ]]; then
  selected_model="$1"
  shift
else
  enabled_models="$(jq -r --arg n "$profile_name" '
    .providers[$n] | (.enabled_models // .enabled_model // .availableModels // null) | if type == "array" then .[] else empty end
  ' "$CONFIG_PATH")"
  
  if [ -n "$enabled_models" ]; then
    echo "請選擇要使用的模型:" >&2
    old_ifs="$IFS"
    IFS=$'\n'
    model_arr=($enabled_models)
    IFS="$old_ifs"
    
    i=1
    for m in "${model_arr[@]}"; do
      echo "  [$i] $m" >&2
      i=$((i+1))
    done
    echo "" >&2

    while true; do
      read -r -p "請輸入數字選擇模型 (或 Ctrl+C 離開): " num
      if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#model_arr[@]}" ]; then
        selected_model="${model_arr[$((num-1))]}"
        break
      else
        echo "無效的選擇，請輸入 1 到 ${#model_arr[@]} 之間的數字。" >&2
      fi
    done
  else
    err "未指定模型，且設定檔中無 enabled_models 可供選擇"
  fi
fi

missing_fields="$(jq -r --arg n "$profile_name" '
  .providers[$n] as $p
  | ["auth_token", "base_url"]
  | map(select((($p[.] // "") | tostring | length) == 0))
  | join(",")
' "$CONFIG_PATH")"

if [ -n "$missing_fields" ]; then
  err "設定 [$profile_name] 缺少欄位: $missing_fields"
fi

auth_token="$(jq -r --arg n "$profile_name" '.providers[$n].auth_token // ""' "$CONFIG_PATH")"
base_url="$(jq -r --arg n "$profile_name" '.providers[$n].base_url // ""' "$CONFIG_PATH")"
prompt_file="$(jq -r --arg n "$profile_name" '.providers[$n].prompt_file // ""' "$CONFIG_PATH")"
default_opus_model="$(jq -r --arg n "$profile_name" '.providers[$n].ANTHROPIC_DEFAULT_OPUS_MODEL // ""' "$CONFIG_PATH")"
default_sonnet_model="$(jq -r --arg n "$profile_name" '.providers[$n].ANTHROPIC_DEFAULT_SONNET_MODEL // ""' "$CONFIG_PATH")"
default_haiku_model="$(jq -r --arg n "$profile_name" '.providers[$n].ANTHROPIC_DEFAULT_HAIKU_MODEL // ""' "$CONFIG_PATH")"
subagent_model="$(jq -r --arg n "$profile_name" '.providers[$n].CLAUDE_CODE_SUBAGENT_MODEL // ""' "$CONFIG_PATH")"

[ -n "$auth_token" ] || err "設定 [$profile_name] 的 auth_token 不可為空"
[ -n "$base_url" ] || err "設定 [$profile_name] 的 base_url 不可為空"
[ -n "$selected_model" ] || err "未指定 selected_model"

env_vars=(
  "ANTHROPIC_AUTH_TOKEN=$auth_token"
  "ANTHROPIC_BASE_URL=$base_url"
)

if [ -n "$default_opus_model" ]; then
  env_vars+=("ANTHROPIC_DEFAULT_OPUS_MODEL=$default_opus_model")
fi

if [ -n "$default_sonnet_model" ]; then
  env_vars+=("ANTHROPIC_DEFAULT_SONNET_MODEL=$default_sonnet_model")
fi

if [ -n "$default_haiku_model" ]; then
  env_vars+=("ANTHROPIC_DEFAULT_HAIKU_MODEL=$default_haiku_model")
fi

if [ -n "$subagent_model" ]; then
  env_vars+=("CLAUDE_CODE_SUBAGENT_MODEL=$subagent_model")
fi

claude_args=(
  --model "$selected_model"
)

if [ -n "$prompt_file" ]; then
  claude_args+=(--append-system-prompt-file "$prompt_file")
fi

claude_args+=("$@")

if [ "$dry_run" -eq 1 ]; then
  printf '試執行：profile=%s\n' "$profile_name"
  printf '試執行：model=%s\n' "$selected_model"
  printf '試執行：prompt_file=%s\n' "${prompt_file:-<none>}"
  printf '試執行：環境變數\n'
  printf '  ANTHROPIC_AUTH_TOKEN=%s\n' '<redacted>'
  printf '  ANTHROPIC_BASE_URL=%s\n' "$base_url"
  if [ -n "$default_opus_model" ]; then
    printf '  ANTHROPIC_DEFAULT_OPUS_MODEL=%s\n' "$default_opus_model"
  fi
  if [ -n "$default_sonnet_model" ]; then
    printf '  ANTHROPIC_DEFAULT_SONNET_MODEL=%s\n' "$default_sonnet_model"
  fi
  if [ -n "$default_haiku_model" ]; then
    printf '  ANTHROPIC_DEFAULT_HAIKU_MODEL=%s\n' "$default_haiku_model"
  fi
  if [ -n "$subagent_model" ]; then
    printf '  CLAUDE_CODE_SUBAGENT_MODEL=%s\n' "$subagent_model"
  fi
  printf '試執行：指令\n'
  printf '  env ANTHROPIC_AUTH_TOKEN=%s ANTHROPIC_BASE_URL=%s' "$(printf '%q' '<redacted>')" "$(printf '%q' "$base_url")"
  if [ -n "$default_opus_model" ]; then
    printf ' ANTHROPIC_DEFAULT_OPUS_MODEL=%s' "$(printf '%q' "$default_opus_model")"
  fi
  if [ -n "$default_sonnet_model" ]; then
    printf ' ANTHROPIC_DEFAULT_SONNET_MODEL=%s' "$(printf '%q' "$default_sonnet_model")"
  fi
  if [ -n "$default_haiku_model" ]; then
    printf ' ANTHROPIC_DEFAULT_HAIKU_MODEL=%s' "$(printf '%q' "$default_haiku_model")"
  fi
  if [ -n "$subagent_model" ]; then
    printf ' CLAUDE_CODE_SUBAGENT_MODEL=%s' "$(printf '%q' "$subagent_model")"
  fi
  printf ' claude %s\n' "$(quote_args "${claude_args[@]}")"
  exit 0
fi

exec env "${env_vars[@]}" claude "${claude_args[@]}"
