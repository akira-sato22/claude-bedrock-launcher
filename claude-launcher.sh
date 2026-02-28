#!/bin/bash
#
# Claude (Bedrock) Launcher
# ~/.aws/config から全プロファイルを一覧表示し、選択したプロファイルで
# SSO ログイン（SSO の場合のみ）→ Claude を起動する。
#

set -euo pipefail

AWS_CONFIG="${HOME}/.aws/config"

# ──────────────────────────────────────────────
# 1. ~/.aws/config から全プロファイルを抽出
#    出力フォーマット: name|info|role|type
#      SSO プロファイル : name|account_id|role_name|sso
#      その他プロファイル: name|region||static
# ──────────────────────────────────────────────
parse_all_profiles() {
  local profile="" region="" account_id="" role_name="" sso_session=""

  flush_profile() {
    [[ -z "${profile}" ]] && return
    if [[ -n "${sso_session}" && -n "${account_id}" ]]; then
      echo "${profile}|${account_id}|${role_name}|sso"
    else
      echo "${profile}|${region}||static"
    fi
  }

  while IFS= read -r line; do
    # 空行・コメント行をスキップ
    [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue

    # セクションヘッダ
    if [[ "${line}" =~ ^\[profile\ (.+)\]$ ]]; then
      flush_profile
      profile="${BASH_REMATCH[1]}"
      region=""; account_id=""; role_name=""; sso_session=""
    elif [[ "${line}" =~ ^\[.+\]$ ]]; then
      flush_profile
      profile=""; region=""; account_id=""; role_name=""; sso_session=""
    fi

    # キー=値を読み取り
    if [[ -n "${profile}" ]]; then
      case "${line}" in
        sso_session*)    sso_session="$(echo "${line}" | cut -d= -f2 | xargs)" ;;
        sso_account_id*) account_id="$(echo "${line}" | cut -d= -f2 | xargs)" ;;
        sso_role_name*)  role_name="$(echo "${line}" | cut -d= -f2 | xargs)" ;;
        region*)         region="$(echo "${line}" | cut -d= -f2 | xargs)" ;;
      esac
    fi
  done < "${AWS_CONFIG}"

  flush_profile
}

# ──────────────────────────────────────────────
# 2. プロファイル一覧を取得
# ──────────────────────────────────────────────
if [[ ! -f "${AWS_CONFIG}" ]]; then
  echo "エラー: ${AWS_CONFIG} が見つかりません。" >&2
  exit 1
fi

profile_count=0
while IFS= read -r line; do
  [[ -z "${line}" ]] && continue
  profiles[profile_count]="${line}"
  profile_count=$((profile_count + 1))
done <<EOF
$(parse_all_profiles)
EOF

if [[ ${profile_count} -eq 0 ]]; then
  echo "エラー: プロファイルが見つかりませんでした。" >&2
  exit 1
fi

# ──────────────────────────────────────────────
# 3. メニュー表示
# ──────────────────────────────────────────────
echo ""
echo "=== Claude (Bedrock) Launcher ==="
echo ""

i=0
while [[ $i -lt ${profile_count} ]]; do
  IFS='|' read -r name info role type <<< "${profiles[$i]}"
  if [[ "${type}" == "sso" ]]; then
    printf "  %2d) %-40s (%s / %s) [SSO]\n" $((i + 1)) "${name}" "${info}" "${role}"
  else
    local_region="${info:-未設定}"
    printf "  %2d) %-40s (region: %s)\n" $((i + 1)) "${name}" "${local_region}"
  fi
  i=$((i + 1))
done

echo ""

# ──────────────────────────────────────────────
# 4. ユーザー選択
# ──────────────────────────────────────────────
while true; do
  read -rp "プロファイルを選択してください [1-${profile_count}]: " choice
  if [[ "${choice}" =~ ^[0-9]+$ ]] && [[ ${choice} -ge 1 ]] && [[ ${choice} -le ${profile_count} ]]; then
    break
  fi
  echo "無効な入力です。1〜${profile_count} の番号を入力してください。"
done

selected="${profiles[$((choice - 1))]}"
IFS='|' read -r PROFILE INFO ROLE_NAME TYPE <<< "${selected}"

echo ""
if [[ "${TYPE}" == "sso" ]]; then
  echo "選択: ${PROFILE} (${INFO} / ${ROLE_NAME}) [SSO]"
else
  echo "選択: ${PROFILE} (region: ${INFO:-未設定})"
fi

# ──────────────────────────────────────────────
# 5. SSO プロファイルの場合のみ aws sso login を実行
# ──────────────────────────────────────────────
if [[ "${TYPE}" == "sso" ]]; then
  echo "AWS SSO ログインを開始します..."
  if ! aws sso login --profile "${PROFILE}"; then
    echo "エラー: SSO ログインに失敗しました。" >&2
    exit 1
  fi
  echo "SSO ログイン成功。"
else
  echo "SSO 不要のプロファイルです。ログインをスキップします。"
fi

# ──────────────────────────────────────────────
# 6. AWS リージョンを選択
# ──────────────────────────────────────────────
regions=(
  "us-east-1      (米国東部 - バージニア北部)"
  "us-east-2      (米国東部 - オハイオ)"
  "us-west-2      (米国西部 - オレゴン)"
  "ap-northeast-1 (アジアパシフィック - 東京)"
)
region_codes=("us-east-1" "us-east-2" "us-west-2" "ap-northeast-1")
region_count=${#regions[@]}

echo "=== AWS リージョンを選択 ==="
echo ""
i=0
while [[ $i -lt ${region_count} ]]; do
  printf "  %2d) %s\n" $((i + 1)) "${regions[$i]}"
  i=$((i + 1))
done
echo ""

while true; do
  read -rp "リージョンを選択してください [1-${region_count}]: " rchoice
  if [[ "${rchoice}" =~ ^[0-9]+$ ]] && [[ ${rchoice} -ge 1 ]] && [[ ${rchoice} -le ${region_count} ]]; then
    break
  fi
  echo "無効な入力です。1〜${region_count} の番号を入力してください。"
done

SELECTED_REGION="${region_codes[$((rchoice - 1))]}"
echo "リージョン: ${SELECTED_REGION}"

# ──────────────────────────────────────────────
# 7. 環境変数を設定して Claude を起動
# ──────────────────────────────────────────────
export AWS_PROFILE="${PROFILE}"
export AWS_REGION="${SELECTED_REGION}"
export CLAUDE_CODE_USE_BEDROCK=1
export ANTHROPIC_DEFAULT_OPUS_MODEL='us.anthropic.claude-opus-4-6-v1'
export ANTHROPIC_DEFAULT_SONNET_MODEL='us.anthropic.claude-sonnet-4-6'
export ANTHROPIC_DEFAULT_HAIKU_MODEL='us.anthropic.claude-haiku-4-5-20251001-v1:0'

echo ""
echo "Claude を起動します (プロファイル: ${PROFILE}) ..."
echo ""

exec claude
