#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

cd "$ROOT_DIR"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Skipping clean-tree check outside a git worktree."
  exit 0
fi

paths=(
  public
  private
  deploy.sh
  scripts
  docs
  .github/workflows
  AGENTS.md
  DEPLOY.md
  .env.example
)

status_output="$(git status --porcelain --untracked-files=normal -- "${paths[@]}")"
if [[ -n "$status_output" ]]; then
  echo "Deploy-relevant files are not clean. Commit or stash these changes before a production deploy:" >&2
  printf '%s\n' "$status_output" >&2
  exit 1
fi

echo "Clean-tree check passed for deploy-relevant files."
