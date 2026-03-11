#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUBLIC_DIR="$ROOT_DIR/public"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env.local}"
GATE_SCRIPT="$ROOT_DIR/scripts/prod-gate.sh"
HEALTHCHECK_SCRIPT="$ROOT_DIR/scripts/check-remote-health.sh"
SITE_URL="${SITE_URL:-https://mwieland.com}"
PREVIEW_SITE_URL="${PREVIEW_SITE_URL:-}"
RUN_PROD_GATE="${RUN_PROD_GATE:-1}"
RUN_POST_DEPLOY_HEALTHCHECK="${RUN_POST_DEPLOY_HEALTHCHECK:-1}"

if [[ ! -d "$PUBLIC_DIR" ]]; then
  echo "Missing public/ directory at $PUBLIC_DIR" >&2
  exit 1
fi

if [[ "$RUN_PROD_GATE" == "1" ]]; then
  if [[ ! -x "$GATE_SCRIPT" ]]; then
    echo "Missing executable production gate script at $GATE_SCRIPT" >&2
    exit 1
  fi
  "$GATE_SCRIPT"
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
SFTP_KEY="${SFTP_KEY:-}"
temp_key_file=""

cleanup() {
  if [[ -n "$temp_key_file" && -f "$temp_key_file" ]]; then
    rm -f "$temp_key_file"
  fi
}
trap cleanup EXIT

if [[ -n "$SFTP_KEY" && -z "$SFTP_KEY_PATH" ]]; then
  temp_key_file="$(mktemp)"
  chmod 600 "$temp_key_file"
  printf '%s\n' "$SFTP_KEY" > "$temp_key_file"
  SFTP_KEY_PATH="$temp_key_file"
fi

if [[ -z "$SFTP_PASSWORD" && -z "$SFTP_KEY_PATH" ]]; then
  echo "Set either SFTP_PASSWORD, SFTP_KEY, or SFTP_KEY_PATH in $ENV_FILE." >&2
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

if [[ -n "$PREVIEW_SITE_URL" ]]; then
  "$HEALTHCHECK_SCRIPT" "$PREVIEW_SITE_URL"
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

if [[ "$RUN_POST_DEPLOY_HEALTHCHECK" == "1" ]]; then
  "$HEALTHCHECK_SCRIPT" "$SITE_URL"
fi
