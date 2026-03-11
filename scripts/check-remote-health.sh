#!/usr/bin/env bash

set -euo pipefail

site_url="${1:-${SITE_URL:-}}"
if [[ -z "$site_url" ]]; then
  echo "Usage: $0 <site-url>" >&2
  exit 1
fi

site_url="${site_url%/}"

assert_contains() {
  local url="$1"
  local expected="$2"
  local body

  body="$(curl --silent --show-error --fail --location "$url")"
  if [[ "$body" != *"$expected"* ]]; then
    echo "Health check failed for $url: expected to find $expected" >&2
    exit 1
  fi
}

assert_contains "$site_url/" "<title>Matthias Wieland</title>"
assert_contains "$site_url/legal-notice.html" "Legal & Privacy"
assert_contains "$site_url/site.webmanifest" "\"name\": \"Matthias Wieland\""
assert_contains "$site_url/robots.txt" "Sitemap:"
assert_contains "$site_url/sitemap.xml" "<urlset"
curl --silent --show-error --fail --location "$site_url/images/avatar-320.jpg" >/dev/null
curl --silent --show-error --fail --location "$site_url/images/favicon-32x32.png" >/dev/null

echo "Remote health checks passed for $site_url."
