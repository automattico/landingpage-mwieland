#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUBLIC_DIR="$ROOT_DIR/public"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env.local}"

if [[ ! -d "$PUBLIC_DIR" ]]; then
  echo "Missing public/ directory at $PUBLIC_DIR" >&2
  exit 1
fi

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

required_vars=(SFTP_HOST SFTP_USER SFTP_REMOTE_DIR)
missing_vars=()
for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    missing_vars+=("$var_name")
  fi
done

if (( ${#missing_vars[@]} > 0 )); then
  printf 'Missing required environment variables: %s\n' "${missing_vars[*]}" >&2
  echo "Create $ENV_FILE with your SFTP settings or export the variables in your shell." >&2
  exit 1
fi

SFTP_PORT="${SFTP_PORT:-22}"
SFTP_PASSWORD="${SFTP_PASSWORD:-}"
SFTP_KEY_PATH="${SFTP_KEY_PATH:-}"

if [[ -z "$SFTP_PASSWORD" && -z "$SFTP_KEY_PATH" ]]; then
  echo "Set either SFTP_PASSWORD or SFTP_KEY_PATH in $ENV_FILE." >&2
  exit 1
fi

if [[ -n "$SFTP_KEY_PATH" && ! -f "$SFTP_KEY_PATH" ]]; then
  echo "SFTP_KEY_PATH does not exist: $SFTP_KEY_PATH" >&2
  exit 1
fi

if ! command -v lftp >/dev/null 2>&1; then
  echo "lftp is not installed. Install it first, for example on macOS: brew install lftp" >&2
  exit 1
fi

echo "Deploying $PUBLIC_DIR to sftp://$SFTP_HOST:$SFTP_PORT$SFTP_REMOTE_DIR"

LFTP_SOURCE_DIR="${PUBLIC_DIR%/}/"
LFTP_TARGET_DIR="${SFTP_REMOTE_DIR%/}/"
LFTP_OPEN_COMMAND="open -u \"$SFTP_USER\",\"$SFTP_PASSWORD\" \"sftp://$SFTP_HOST:$SFTP_PORT\""

if [[ -n "$SFTP_KEY_PATH" ]]; then
  escaped_key_path=${SFTP_KEY_PATH//\"/\\\"}
  LFTP_OPEN_COMMAND="set sftp:connect-program \"ssh -a -x -i \\\"$escaped_key_path\\\"\""$'\n'"open -u \"$SFTP_USER\" \"sftp://$SFTP_HOST:$SFTP_PORT\""
fi

lftp <<EOF
set cmd:fail-exit true
set xfer:clobber true
set sftp:auto-confirm yes
$LFTP_OPEN_COMMAND
mirror --reverse --delete --verbose "$LFTP_SOURCE_DIR" "$LFTP_TARGET_DIR"
bye
EOF
