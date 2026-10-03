#!/usr/bin/env bash
# Serves the reverse-engineering viewer and opens it in the browser.
#
#   ./serve.sh          # http://localhost:8770
#   ./serve.sh 9000     # pick another port
#
# A local server is required: the viewer loads its data files and Mermaid
# as scripts/modules, which browsers block on file:// URLs.
set -euo pipefail

PORT="${1:-8770}"
DIR="$(cd "$(dirname "$0")" && pwd)"
URL="http://localhost:${PORT}/"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required (used only as a static file server)." >&2
  exit 1
fi

if curl -s -o /dev/null --max-time 1 "$URL"; then
  echo "Something is already serving on port ${PORT} — opening ${URL}"
  if command -v open >/dev/null 2>&1; then open "$URL"
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$URL"
  fi
  exit 0
fi

echo "Serving ${DIR} at ${URL}  (Ctrl+C to stop)"
( sleep 1
  if command -v open >/dev/null 2>&1; then open "$URL"
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$URL"
  fi ) &
exec python3 -m http.server "$PORT" --directory "$DIR" --bind 127.0.0.1
