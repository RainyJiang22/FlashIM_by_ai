#!/usr/bin/env bash

set -euo pipefail

CASK_NAME="${CASK_NAME:-pgadmin4}"
APP_PATH="/Applications/pgAdmin 4.app"

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd"
    exit 1
  fi
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script is for macOS only."
  exit 1
fi

require_command brew
require_command open

echo "==> Checking ${CASK_NAME}"
if brew list --cask "${CASK_NAME}" >/dev/null 2>&1; then
  echo "==> ${CASK_NAME} is already installed"
else
  echo "==> Installing ${CASK_NAME}"
  brew install --cask "${CASK_NAME}"
fi

if [[ ! -d "${APP_PATH}" ]]; then
  echo "Expected app bundle not found: ${APP_PATH}"
  exit 1
fi

echo "==> Opening pgAdmin 4"
open -a "${APP_PATH}"

echo "==> pgAdmin 4 is ready"
echo "App path: ${APP_PATH}"
