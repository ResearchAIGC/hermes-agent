#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISOLATED_ROOT="${HERMES_SOURCE_CLI_ROOT:-$HOME/.hermes-source-cli}"
HERMES_HOME_DIR="${HERMES_SOURCE_HERMES_HOME:-$ISOLATED_ROOT/hermes-home}"
VENV_DIR="${HERMES_SOURCE_VENV:-$ISOLATED_ROOT/venv}"

if [ ! -x "$VENV_DIR/bin/hermes" ]; then
  printf 'Hermes Source CLI is not installed at %s\n' "$VENV_DIR" >&2
  printf 'Run the installation command from the project instructions first.\n' >&2
  exit 1
fi

mkdir -p "$HERMES_HOME_DIR"
export HERMES_HOME="$HERMES_HOME_DIR"
export PYTHONUTF8=1

exec "$VENV_DIR/bin/hermes" "$@"
