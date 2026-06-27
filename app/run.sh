#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/config.local.sh" ]]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/config.local.sh"
fi

SUPABASE_URL="${SUPABASE_URL:-https://aktmdyxeqcmaldbylzfi.supabase.co}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFrdG1keXhlcWNtYWxkYnlsemZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk4MzYwNzksImV4cCI6MjA5NTQxMjA3OX0.hiSkMayvK7tF4A-bDSjiTsIPGxtbzML16jX0amilPUk}"
API_BASE_URL="${API_BASE_URL:-https://pet.superstar.tots.asia/api/v1}"

flutter run \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  "$@"
