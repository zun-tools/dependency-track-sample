# 共通設定（他のスクリプトが source する）
DT_API_PORT="${DT_API_PORT:-8080}"
DT_URL="${DT_URL:-http://127.0.0.1:${DT_API_PORT}}"

log() { printf '%s\n' "$*" >&2; }

need_key() {
  if [ -z "${DT_API_KEY:-}" ]; then
    log "DT_API_KEY が空です。scripts/setup.sh で作るか、画面の Administration > Access Management > Teams > Automation > API Keys で作って export してください。"
    exit 1
  fi
}
