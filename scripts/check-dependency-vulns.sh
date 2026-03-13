#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

cd "$ROOT_DIR"

if [[ -f package-lock.json || -f npm-shrinkwrap.json ]]; then
  if ! command -v npm >/dev/null 2>&1; then
    echo "npm is required to audit Node dependencies." >&2
    exit 1
  fi
  npm audit --audit-level=high
  exit 0
fi

if [[ -f pnpm-lock.yaml ]]; then
  if ! command -v pnpm >/dev/null 2>&1; then
    echo "pnpm is required to audit pnpm dependencies." >&2
    exit 1
  fi
  pnpm audit --audit-level high
  exit 0
fi

if [[ -f yarn.lock ]]; then
  if ! command -v yarn >/dev/null 2>&1; then
    echo "yarn is required to audit Yarn dependencies." >&2
    exit 1
  fi
  yarn npm audit --severity high
  exit 0
fi

if [[ -f package.json ]]; then
  echo "package.json exists without a supported lockfile. Commit a lockfile so dependency auditing can be enforced." >&2
  exit 1
fi

for unsupported_manifest in composer.json Gemfile pyproject.toml requirements.txt Cargo.toml go.mod; do
  if [[ -f "$unsupported_manifest" ]]; then
    echo "Found $unsupported_manifest but no repository-specific vulnerability audit is configured for it yet." >&2
    exit 1
  fi
done

echo "No supported application dependency lockfile found. Skipping vulnerability audit because this static site has no tracked app dependencies."
