#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if [[ ! -d "$PUBLIC_DIR" ]]; then
  die "Missing public directory: $PUBLIC_DIR"
fi

require_command python3
require_command curl
require_command grep

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

assert_public_lacks() {
  local pattern="$1"

  if grep --recursive --line-number --ignore-case --extended-regexp \
    --include='*.html' --include='*.js' --include='*.json' "$pattern" "$PUBLIC_DIR"; then
    echo "Static privacy check failed: found forbidden pattern $pattern" >&2
    exit 1
  fi
}

assert_contains "$BASE_URL/" "<title>Matthias Wieland</title>"
assert_contains "$BASE_URL/" "hreflang=\"x-default\""
assert_contains "$BASE_URL/" "href=\"/de/\""
assert_contains "$BASE_URL/" "legal-notice.html"
assert_contains "$BASE_URL/de/" "<html lang=\"de\">"
assert_contains "$BASE_URL/de/" "Berater für digitale Projekte und Strategien"
assert_contains "$BASE_URL/de/" "https://mwieland.com/de/"
assert_contains "$BASE_URL/es/" "<html lang=\"es\">"
assert_contains "$BASE_URL/es/" "Consultor de proyectos y estrategias digitales"
assert_contains "$BASE_URL/es/" "https://mwieland.com/es/"
assert_contains "$BASE_URL/pt/" "<html lang=\"pt\">"
assert_contains "$BASE_URL/pt/" "Consultor de projetos e estratégias digitais"
assert_contains "$BASE_URL/pt/" "https://mwieland.com/pt/"
assert_contains "$BASE_URL/legal-notice.html" "Legal & Privacy"
assert_contains "$BASE_URL/legal-notice.html" "Beethovenstra&szlig;e 23"
assert_contains "$BASE_URL/legal-notice.html" "DE464022572"
assert_contains "$BASE_URL/legal-notice.html" "exclusively at businesses and other"
assert_contains "$BASE_URL/legal-notice.html" "neither willing nor obliged"
assert_contains "$BASE_URL/legal-notice.html" "Hetzner Online GmbH"
assert_contains "$BASE_URL/legal-notice.html" "Cloudflare, Inc."
assert_contains "$BASE_URL/legal-notice/" "Redirecting to"
assert_contains "$BASE_URL/site.webmanifest" "\"name\": \"Matthias Wieland\""
assert_contains "$BASE_URL/robots.txt" "Sitemap: https://mwieland.com/sitemap.xml"
assert_contains "$BASE_URL/robots.txt" "Allow: /"
assert_contains "$BASE_URL/sitemap.xml" "<loc>https://mwieland.com/</loc>"
assert_contains "$BASE_URL/sitemap.xml" "<loc>https://mwieland.com/de/</loc>"
assert_contains "$BASE_URL/sitemap.xml" "<loc>https://mwieland.com/es/</loc>"
assert_contains "$BASE_URL/sitemap.xml" "<loc>https://mwieland.com/pt/</loc>"
curl --silent --show-error --fail "$BASE_URL/images/avatar-2022.jpg" >/dev/null
curl --silent --show-error --fail "$BASE_URL/images/favicon-32x32.png" >/dev/null
curl --silent --show-error --fail "$BASE_URL/de/" >/dev/null
curl --silent --show-error --fail "$BASE_URL/es/" >/dev/null
curl --silent --show-error --fail "$BASE_URL/pt/" >/dev/null

assert_public_lacks 'localStorage|sessionStorage|googletagmanager|google-analytics|plausible|matomo|document\\.cookie|cookieconsent|cookie-consent|onetrust|cookiebot|consentmanager|consumers/odr|os-plattform'

echo "Local smoke tests passed."
