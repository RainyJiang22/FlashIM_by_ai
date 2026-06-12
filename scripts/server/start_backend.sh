#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SERVER_DIR="${ROOT_DIR}/server"
DATABASE_SCRIPT_DIR="${ROOT_DIR}/scripts/database"
BACKEND_PORT="${BACKEND_PORT:-9600}"

# shellcheck disable=SC1091
source "${DATABASE_SCRIPT_DIR}/sqlx_common.sh"

ensure_required_commands() {
  require_command cargo
  require_command lsof
  require_command psql
  ensure_postgres_env
  ensure_env_file
  require_command pg_isready
  export DATABASE_URL
  export_if_present APP_DATABASE_NAME
  export_if_present JWT_SECRET
  export_if_present JWT_TTL_SECS
  export_if_present SMS_CODE_TTL_SECS
  export_if_present EXPOSE_DEBUG_SMS_CODE
}

ensure_postgres_running() {
  if pg_isready -d "${DATABASE_URL}" >/dev/null 2>&1; then
    echo "==> PostgreSQL is already running"
    return 0
  fi

  echo "==> PostgreSQL is not running, starting service"
  "${DATABASE_SCRIPT_DIR}/start_postgres_service.sh"

  if ! pg_isready -d "${DATABASE_URL}" >/dev/null 2>&1; then
    echo "PostgreSQL did not become ready."
    exit 1
  fi
}

stop_backend_if_running() {
  local pids=()
  local remaining=()
  local pid

  while IFS= read -r pid; do
    [[ -n "${pid}" ]] && pids+=("${pid}")
  done < <(lsof -tiTCP:"${BACKEND_PORT}" -sTCP:LISTEN || true)

  if [[ "${#pids[@]}" -eq 0 ]]; then
    echo "==> Backend is not running on port ${BACKEND_PORT}"
    return 0
  fi

  echo "==> Stopping backend on port ${BACKEND_PORT}: ${pids[*]}"
  kill "${pids[@]}"

  for _ in {1..20}; do
    remaining=()
    while IFS= read -r pid; do
      [[ -n "${pid}" ]] && remaining+=("${pid}")
    done < <(lsof -tiTCP:"${BACKEND_PORT}" -sTCP:LISTEN || true)
    if [[ "${#remaining[@]}" -eq 0 ]]; then
      echo "==> Backend stopped"
      return 0
    fi
    sleep 1
  done

  echo "==> Backend did not exit gracefully, forcing stop"
  kill -9 "${remaining[@]}"
}

rebuild_and_run_backend() {
  echo "==> Ensuring database exists"
  ensure_database_exists

  echo "==> Building backend"
  (
    cd "${SERVER_DIR}"
    cargo build
  )

  echo "==> Starting backend"
  cd "${SERVER_DIR}"
  exec cargo run
}

export_if_present() {
  local name="$1"
  local value="${!name:-}"
  if [[ -n "${value}" ]]; then
    export "${name}=${value}"
  fi
}

main() {
  ensure_required_commands
  ensure_postgres_running
  stop_backend_if_running
  rebuild_and_run_backend
}

main "$@"
