#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVER_DIR="${ROOT_DIR}/server"
ENV_FILE="${SERVER_DIR}/.env"
ENV_EXAMPLE_FILE="${SERVER_DIR}/.env.example"
MIGRATIONS_DIR="${SERVER_DIR}/migrations"

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd"
    exit 1
  fi
}

ensure_env_file() {
  mkdir -p "${SERVER_DIR}"

  if [[ ! -f "${ENV_FILE}" ]]; then
    cp "${ENV_EXAMPLE_FILE}" "${ENV_FILE}"
    echo "==> Created ${ENV_FILE} from template"
  fi

  # shellcheck disable=SC1090
  source "${ENV_FILE}"

  if [[ -z "${DATABASE_URL:-}" ]]; then
    echo "DATABASE_URL is missing in ${ENV_FILE}"
    exit 1
  fi
}

ensure_postgres_env() {
  if [[ -f "${HOME}/.config/postgres/postgres-env.zsh" ]]; then
    # shellcheck disable=SC1090
    source "${HOME}/.config/postgres/postgres-env.zsh"
  fi
}

ensure_sqlx_cli() {
  if command -v sqlx >/dev/null 2>&1; then
    return 0
  fi

  echo "==> Installing sqlx-cli"
  cargo install sqlx-cli --no-default-features --features postgres,rustls
}

ensure_database_exists() {
  local db_name="${APP_DATABASE_NAME:-}"
  if [[ -z "${db_name}" ]]; then
    db_name="$(printf '%s\n' "${DATABASE_URL}" | sed -E 's#^.*/([^/?]+)(\?.*)?$#\1#')"
  fi

  if [[ -z "${db_name}" ]]; then
    echo "Unable to determine database name."
    exit 1
  fi

  local admin_url="${DATABASE_URL%/${db_name}}/postgres"
  if ! psql "${admin_url}" -Atqc "SELECT 1 FROM pg_database WHERE datname='${db_name}'" | grep -qx '1'; then
    echo "==> Creating database: ${db_name}"
    psql "${admin_url}" -c "CREATE DATABASE ${db_name};" >/dev/null
  fi
}

terminate_database_connections() {
  local db_name="${APP_DATABASE_NAME:-}"
  if [[ -z "${db_name}" ]]; then
    db_name="$(printf '%s\n' "${DATABASE_URL}" | sed -E 's#^.*/([^/?]+)(\?.*)?$#\1#')"
  fi

  local admin_url="${DATABASE_URL%/${db_name}}/postgres"
  echo "==> Terminating active connections to ${db_name}"
  psql "${admin_url}" -c "
    SELECT pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE datname = '${db_name}'
      AND pid <> pg_backend_pid();
  " >/dev/null
}

ensure_prerequisites() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "These scripts currently target macOS."
    exit 1
  fi

  require_command cargo
  require_command psql
  ensure_postgres_env
  ensure_env_file
  ensure_sqlx_cli
  mkdir -p "${MIGRATIONS_DIR}"
}
