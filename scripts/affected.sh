#!/usr/bin/env bash
# 脆弱性の番号（CVE）から、それが入っているプロジェクトを引く。
# 使い方: ./scripts/affected.sh [CVE-番号]   （既定 CVE-2020-17541・要 DT_API_KEY）
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh
need_key

cve="${1:-CVE-2020-17541}"
curl -s -m 30 -H "X-Api-Key: ${DT_API_KEY}" \
  "${DT_URL}/api/v1/vulnerability/source/NVD/vuln/${cve}/projects" \
  | grep -o '"name":"[^"]*","version":"[^"]*"' \
  | sed 's/"name":"\([^"]*\)","version":"\([^"]*\)"/\1 \2/'
