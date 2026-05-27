#!/usr/bin/env bash
# Pet Soul H5 mock · 一键本地预览 / 临时分享
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PORT="${PORT:-8765}"

case "${1:-serve}" in
  serve)
    echo "→ http://localhost:${PORT}/index.html"
    cd "$ROOT" && python3 -m http.server "$PORT"
    ;;
  share)
    echo "本地: http://localhost:${PORT}/index.html"
    echo "生成公网链接中（localtunnel）…"
    cd "$ROOT" && python3 -m http.server "$PORT" &
    PID=$!
    trap 'kill $PID 2>/dev/null || true' EXIT
    sleep 1
    npx --yes localtunnel --port "$PORT"
    ;;
  *)
    echo "用法: ./deploy.sh [serve|share]"
    echo "  serve  仅本机预览（默认）"
    echo "  share  本机 + 临时公网链接（关终端即失效）"
    exit 1
    ;;
esac
