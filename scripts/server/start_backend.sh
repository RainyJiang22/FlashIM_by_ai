#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SERVER_DIR="${ROOT_DIR}/server"
DATABASE_SCRIPT_DIR="${ROOT_DIR}/scripts/database"
BACKEND_PORT="${BACKEND_PORT:-9600}"
ENV_FILE="${SERVER_DIR}/.env"
ENV_EXAMPLE_FILE="${SERVER_DIR}/.env.example"

# shellcheck disable=SC1091
source "${DATABASE_SCRIPT_DIR}/sqlx_common.sh"

ensure_required_commands() {
  require_command cargo
  require_command lsof
  require_command psql
  ensure_postgres_env
  ensure_env_file
  load_backend_runtime_env
  require_command pg_isready
  require_runtime_var DATABASE_URL
  require_runtime_var JWT_SECRET
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

load_backend_runtime_env() {
  local database_url_override="${DATABASE_URL+x}:${DATABASE_URL-}"
  local app_database_name_override="${APP_DATABASE_NAME+x}:${APP_DATABASE_NAME-}"
  local jwt_secret_override="${JWT_SECRET+x}:${JWT_SECRET-}"
  local jwt_ttl_secs_override="${JWT_TTL_SECS+x}:${JWT_TTL_SECS-}"
  local sms_code_ttl_secs_override="${SMS_CODE_TTL_SECS+x}:${SMS_CODE_TTL_SECS-}"
  local expose_debug_sms_code_override="${EXPOSE_DEBUG_SMS_CODE+x}:${EXPOSE_DEBUG_SMS_CODE-}"

  set -a
  if [[ -f "${ENV_EXAMPLE_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${ENV_EXAMPLE_FILE}"
  fi
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a

  restore_override DATABASE_URL "${database_url_override}"
  restore_override APP_DATABASE_NAME "${app_database_name_override}"
  restore_override JWT_SECRET "${jwt_secret_override}"
  restore_override JWT_TTL_SECS "${jwt_ttl_secs_override}"
  restore_override SMS_CODE_TTL_SECS "${sms_code_ttl_secs_override}"
  restore_override EXPOSE_DEBUG_SMS_CODE "${expose_debug_sms_code_override}"
}

require_runtime_var() {
  local name="$1"
  local value="${!name:-}"
  if [[ -z "${value}" ]]; then
    echo "${name} is missing. Set it in ${ENV_FILE}, export it in your shell, or add a default in ${ENV_EXAMPLE_FILE}."
    exit 1
  fi
}

restore_override() {
  local name="$1"
  local override="$2"
  local was_set="${override%%:*}"
  local value="${override#*:}"

  if [[ "${was_set}" == "x" ]]; then
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
