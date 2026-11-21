#!/usr/bin/env bash
# sbom/ の SBOM（CycloneDX）を全部上げ、取り込みの完了まで待つ。
# プロジェクトは自動で作る（名前はファイル名、版は 1.0）。
# 使い方: ./scripts/upload.sh   （要 DT_API_KEY）
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh
need_key

tokens=()
for f in sbom/*.cdx.json; do
  name="$(basename "$f" .cdx.json)"
  res="$(curl -s -m 300 -H "X-Api-Key: ${DT_API_KEY}" \
    -F autoCreate=true -F projectName="$name" -F projectVersion=1.0 -F bom=@"$f" \
    "${DT_URL}/api/v1/bom")"
  tok="$(printf '%s' "$res" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')"
  [ -n "$tok" ] || { log "$name の上げに失敗: $res"; exit 1; }
  log "上げた: $name"
  tokens+=("$name:$tok")
done

for nt in "${tokens[@]}"; do
  name="${nt%%:*}"; tok="${nt#*:}"
  for _ in $(seq 1 120); do
    r="$(curl -s -m 20 -H "X-Api-Key: ${DT_API_KEY}" "${DT_URL}/api/v1/event/token/${tok}" || true)"
    case "$r" in *'"processing":false'*) break ;; esac
    sleep 5
  done
  case "$r" in
    *'"processing":false'*) log "取り込み完了: $name" ;;
    *) log "$name の取り込みが 10 分たっても終わりません: $r"; exit 1 ;;
  esac
done
