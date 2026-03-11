#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT_DIR/scripts/check-clean-tree.sh"
python3 "$ROOT_DIR/scripts/check-public-security.py"
"$ROOT_DIR/scripts/check-dependency-vulns.sh"
"$ROOT_DIR/scripts/run-smoke-tests.sh"

echo "Production gate passed."
