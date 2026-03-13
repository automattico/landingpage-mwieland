#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBLIC_DIR="$ROOT_DIR/public"
ENV_FILE_DEFAULT="$ROOT_DIR/.env.local"

die() {
  echo "$*" >&2
  exit 1
}

require_command() {
  local command_name="$1"
  local install_hint="${2:-}"

  if command -v "$command_name" >/dev/null 2>&1; then
    return 0
  fi

  if [[ -n "$install_hint" ]]; then
    die "$command_name is not installed. $install_hint"
  fi

  die "$command_name is not installed."
}

load_env_file() {
  local env_file="${1:-$ENV_FILE_DEFAULT}"

  if [[ -f "$env_file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
  fi
}
