#!/usr/bin/env bash

set -euo pipefail

ENV_FILE="${HOME}/.config/postgres/postgres-env.zsh"
POSTGRES_FORMULA="${POSTGRES_FORMULA:-postgresql@18}"

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd"
    exit 1
  fi
}

wait_for_postgres() {
  local attempts=20

  for ((i = 1; i <= attempts; i++)); do
    if pg_isready -h "${PGHOST}" -p "${PGPORT}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  return 1
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script is for macOS only."
  exit 1
fi

require_command brew

if [[ -f "${ENV_FILE}" ]]; then
  # Load PostgreSQL PATH and connection defaults created by the install script.
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
else
  brew_prefix="$(brew --prefix)"
  export PGROOT="${brew_prefix}/opt/${POSTGRES_FORMULA}"
  export PGHOST="${PGHOST:-127.0.0.1}"
  export PGPORT="${PGPORT:-5432}"
  export PATH="${PGROOT}/bin:${PATH}"
fi

require_command pg_isready
require_command psql

echo "==> Starting PostgreSQL service: ${POSTGRES_FORMULA}"
brew services start "${POSTGRES_FORMULA}"

if ! wait_for_postgres; then
  echo "PostgreSQL did not become ready in time."
  exit 1
fi

echo "==> PostgreSQL is ready"
psql --version
brew services list | grep "^${POSTGRES_FORMULA}[[:space:]]"
