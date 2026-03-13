#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/scripts" && pwd)/common.sh"

ENV_FILE="${ENV_FILE:-$ENV_FILE_DEFAULT}"
GATE_SCRIPT="$ROOT_DIR/scripts/prod-gate.sh"
PREDEPLOY_GUARD_SCRIPT="$ROOT_DIR/scripts/predeploy-guard.sh"
HEALTHCHECK_SCRIPT="$ROOT_DIR/scripts/check-remote-health.sh"
SITE_URL="${SITE_URL:-https://mwieland.com}"
PREVIEW_SITE_URL="${PREVIEW_SITE_URL:-}"
RUN_PROD_GATE="${RUN_PROD_GATE:-1}"
RUN_POST_DEPLOY_HEALTHCHECK="${RUN_POST_DEPLOY_HEALTHCHECK:-1}"

if [[ ! -d "$PUBLIC_DIR" ]]; then
  die "Missing public/ directory at $PUBLIC_DIR"
fi

if [[ "$RUN_PROD_GATE" == "1" ]]; then
  if [[ ! -x "$GATE_SCRIPT" ]]; then
    die "Missing executable production gate script at $GATE_SCRIPT"
  fi
  "$GATE_SCRIPT"
fi

if [[ ! -x "$PREDEPLOY_GUARD_SCRIPT" ]]; then
  die "Missing executable predeploy guard script at $PREDEPLOY_GUARD_SCRIPT"
fi

"$PREDEPLOY_GUARD_SCRIPT"
load_env_file "$ENV_FILE"

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

require_command lftp "Install it first, for example on macOS: brew install lftp"

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
set mirror:exclude-regex "(^|/)\\.DS_Store$"
$LFTP_OPEN_COMMAND
mirror --reverse --delete --verbose "$LFTP_SOURCE_DIR" "$LFTP_TARGET_DIR"
bye
EOF

if [[ "$RUN_POST_DEPLOY_HEALTHCHECK" == "1" ]]; then
  "$HEALTHCHECK_SCRIPT" "$SITE_URL"
fi
