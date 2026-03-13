#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if [[ "${1:-}" == "--check" ]]; then
  shift
fi

if (( $# > 0 )); then
  die "Usage: $0 [--check]"
fi

require_command git
require_command python3
require_command curl

"$ROOT_DIR/scripts/check-clean-tree.sh"
python3 "$ROOT_DIR/scripts/check-public-security.py"
"$ROOT_DIR/scripts/check-dependency-vulns.sh"
"$ROOT_DIR/scripts/smoke-test.sh"

echo "Predeploy guard passed."
