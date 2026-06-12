#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/sqlx_common.sh"

ensure_prerequisites
ensure_database_exists

echo "==> Running sqlx migrations"
(
  cd "${SERVER_DIR}"
  sqlx database create
  sqlx migrate run --source "${MIGRATIONS_DIR}"
)

echo "==> SQLx database setup completed"
echo "DATABASE_URL=${DATABASE_URL}"
