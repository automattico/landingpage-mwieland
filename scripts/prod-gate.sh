#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if [[ ! -d "$PUBLIC_DIR" ]]; then
  die "Missing public directory: $PUBLIC_DIR"
fi

require_command git
require_command python3
require_command curl

"$ROOT_DIR/scripts/predeploy-guard.sh" --check

echo "Production gate passed."
