#!/usr/bin/env bash
# admin の初回パスワード変更 → Automation チームに権限を足す → API キーを1本作って標準出力へ出す。
# 使い方: export DT_ADMIN_PASSWORD='自分で決めたパスワード'
#         export DT_API_KEY="$(./scripts/setup.sh)"
# パスワードもキーもファイルには書きません。メッセージは標準エラー、標準出力はキーだけです。
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh

: "${DT_ADMIN_PASSWORD:?DT_ADMIN_PASSWORD に admin の新しいパスワード（自分で決める）を入れてください}"

log "API の起動を待っています（${DT_URL}）"
for _ in $(seq 1 120); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' -m 3 "${DT_URL}/api/version" || true)" = 200 ] && break
  sleep 3
done
[ "$(curl -s -o /dev/null -w '%{http_code}' -m 3 "${DT_URL}/api/version" || true)" = 200 ] \
  || { log "API が 6 分たっても応答しません: docker compose logs apiserver"; exit 1; }

# 成功（HTTP 200）のときだけ本文（トークン）を出す
login() {
  local out code
  out="$(mktemp)"
  code="$(curl -s -m 20 -o "$out" -w '%{http_code}' -X POST "${DT_URL}/api/v1/user/login" \
    --data-urlencode username=admin --data-urlencode password="$1" || true)"
  if [ "$code" = 200 ]; then cat "$out"; else cat "$out" >&2; fi
  rm -f "$out"
  [ "$code" = 200 ]
}

# 初回は admin / admin で入ろうとすると FORCE_PASSWORD_CHANGE（401）が返る＝パスワードの変更を求められる
if [ "$(login admin 2>&1 >/dev/null || true)" = "FORCE_PASSWORD_CHANGE" ]; then
  log "admin のパスワードを変更します"
  curl -s -m 20 -o /dev/null -w '%{http_code}\n' -X POST "${DT_URL}/api/v1/user/forceChangePassword" \
    --data-urlencode username=admin --data-urlencode password=admin \
    --data-urlencode newPassword="${DT_ADMIN_PASSWORD}" \
    --data-urlencode confirmPassword="${DT_ADMIN_PASSWORD}" >&2
fi

jwt="$(login "${DT_ADMIN_PASSWORD}")" \
  || { log "admin でログインできません（既に別のパスワードに変更済みなら DT_ADMIN_PASSWORD をそれに合わせてください）"; exit 1; }
auth="Authorization: Bearer ${jwt}"

team="$(curl -s -m 20 -H "$auth" "${DT_URL}/api/v1/team" \
  | grep -o '"uuid":"[^"]*","name":"Automation"' | sed 's/"uuid":"\([^"]*\)".*/\1/')"
[ -n "$team" ] || { log "Automation チームが見つかりません"; exit 1; }

# Automation チームの既定は BOM_UPLOAD と VIEW_PORTFOLIO。プロジェクトの自動作成・脆弱性の参照・
# 取り込み状況の参照（wait-ready.sh が使う）を足す
for p in PROJECT_CREATION_UPLOAD VIEW_VULNERABILITY SYSTEM_CONFIGURATION_READ; do
  curl -s -m 20 -o /dev/null -X POST -H "$auth" "${DT_URL}/api/v1/permission/${p}/team/${team}"
done

curl -s -m 20 -X PUT -H "$auth" "${DT_URL}/api/v1/team/${team}/key" \
  | sed -n 's/.*"key":"\([^"]*\)".*/\1/p'
