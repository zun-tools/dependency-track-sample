#!/usr/bin/env bash
# 脆弱性の公開データ（NVD）の取り込みが終わるまで待つ。起動直後は自動で取り込みが始まり、
# 終わる前に SBOM を上げると、まだ入っていない脆弱性とは照合されない。
# 使い方: ./scripts/wait-ready.sh   （要 DT_API_KEY・最大 30 分）
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh
need_key

t0=$(date +%s)
for _ in $(seq 1 360); do
  r="$(curl -s -m 20 -H "X-Api-Key: ${DT_API_KEY}" \
    "${DT_URL}/api/v2/vuln-data-sources/nvd/mirror-runs/latest" || true)"
  case "$r" in
    *'"status":"COMPLETED"'*)
      log "NVD の取り込み完了（$(( $(date +%s) - t0 )) 秒待ちました）"
      exit 0 ;;
    *'"status":"FAILED"'*)
      log "NVD の取り込みが失敗しました: $r"; exit 1 ;;
  esac
  sleep 5
done
log "30 分たっても NVD の取り込みが終わりません: ${r:-}"
exit 1
