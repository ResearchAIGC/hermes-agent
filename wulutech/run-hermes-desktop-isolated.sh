#!/usr/bin/env bash
set -euo pipefail

# Launch the source checkout with its own Hermes home and Electron userData.
# This intentionally does not modify the official Hermes Desktop installation.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESKTOP_DIR="$REPO_ROOT/apps/desktop"
ISOLATED_ROOT="${HERMES_SOURCE_DESKTOP_ROOT:-$HOME/.hermes-source-desktop}"
HERMES_HOME_DIR="${HERMES_SOURCE_HERMES_HOME:-$ISOLATED_ROOT/hermes-home}"
USER_DATA_DIR="${HERMES_SOURCE_USER_DATA:-$ISOLATED_ROOT/electron-user-data}"
APP_NAME="${HERMES_SOURCE_APP_NAME:-Hermes Source Dev}"

mkdir -p "$HERMES_HOME_DIR" "$USER_DATA_DIR"

export HERMES_HOME="$HERMES_HOME_DIR"
export HERMES_DESKTOP_USER_DATA_DIR="$USER_DATA_DIR"
export HERMES_DESKTOP_HERMES_ROOT="$REPO_ROOT"
export HERMES_DESKTOP_APP_NAME="$APP_NAME"

cd "$DESKTOP_DIR"

case "${1:-dev}" in
  dev)
    shift
    exec npm run dev -- "$@"
    ;;
  fake-boot)
    shift
    exec npm run dev:fake-boot -- "$@"
    ;;
  pack)
    shift
    npm run pack
    printf '\nPackaged application is under:\n  %s/release\n' "$DESKTOP_DIR"
    ;;
  dist-mac)
    shift
    exec npm run dist:mac -- "$@"
    ;;
  print-env)
    printf 'REPO_ROOT=%s\nHERMES_HOME=%s\nHERMES_DESKTOP_USER_DATA_DIR=%s\nHERMES_DESKTOP_HERMES_ROOT=%s\nHERMES_DESKTOP_APP_NAME=%s\n' \
      "$REPO_ROOT" "$HERMES_HOME" "$HERMES_DESKTOP_USER_DATA_DIR" \
      "$HERMES_DESKTOP_HERMES_ROOT" "$HERMES_DESKTOP_APP_NAME"
    ;;
  *)
    printf 'Usage: %s [dev|fake-boot|pack|dist-mac|print-env]\n' "$0" >&2
    exit 2
    ;;
esac
