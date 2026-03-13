#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if [[ ! -d "$PUBLIC_DIR" ]]; then
  die "Missing public directory: $PUBLIC_DIR"
fi

require_command python3
require_command curl

if [[ -n "${SMOKE_TEST_PORT:-}" ]]; then
  PORT="$SMOKE_TEST_PORT"
else
  PORT="$(python3 - <<'PY'
import socket

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
)"
fi

BASE_URL="http://127.0.0.1:${PORT}"

server_log="$(mktemp)"
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$PUBLIC_DIR" >"$server_log" 2>&1 &
server_pid=$!

cleanup() {
  kill "$server_pid" >/dev/null 2>&1 || true
  wait "$server_pid" 2>/dev/null || true
  rm -f "$server_log"
}
trap cleanup EXIT

for _ in {1..20}; do
  if curl --silent --fail "$BASE_URL/" >/dev/null; then
    break
  fi
  if ! kill -0 "$server_pid" >/dev/null 2>&1; then
    echo "Preview server exited before smoke tests could run." >&2
    cat "$server_log" >&2
    exit 1
  fi
  sleep 0.25
done

if ! curl --silent --fail "$BASE_URL/" >/dev/null; then
  echo "Preview server did not become ready for smoke tests." >&2
  cat "$server_log" >&2
  exit 1
fi

assert_contains() {
  local url="$1"
  local expected="$2"
  local body

  body="$(curl --silent --show-error --fail "$url")"
  if [[ "$body" != *"$expected"* ]]; then
    echo "Smoke test failed for $url: expected to find $expected" >&2
    exit 1
  fi
}

assert_contains "$BASE_URL/" "<title>Matthias Wieland</title>"
assert_contains "$BASE_URL/" "data-lang=\"de\""
assert_contains "$BASE_URL/" "legal-notice.html"
assert_contains "$BASE_URL/legal-notice.html" "Legal & Privacy"
assert_contains "$BASE_URL/legal-notice/" "Redirecting to"
assert_contains "$BASE_URL/site.webmanifest" "\"name\": \"Matthias Wieland\""
assert_contains "$BASE_URL/robots.txt" "Sitemap: https://mwieland.com/sitemap.xml"
assert_contains "$BASE_URL/sitemap.xml" "<loc>https://mwieland.com/</loc>"
curl --silent --show-error --fail "$BASE_URL/images/avatar-320.jpg" >/dev/null
curl --silent --show-error --fail "$BASE_URL/images/favicon-32x32.png" >/dev/null

echo "Local smoke tests passed."
