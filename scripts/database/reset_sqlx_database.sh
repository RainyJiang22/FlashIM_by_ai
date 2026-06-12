#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/sqlx_common.sh"

ensure_prerequisites
terminate_database_connections

echo "==> Dropping database configured by DATABASE_URL"
(
  cd "${SERVER_DIR}"
  sqlx database drop -y
  sqlx database create
  sqlx migrate run --source "${MIGRATIONS_DIR}"
)

echo "==> SQLx database reset completed"
echo "DATABASE_URL=${DATABASE_URL}"
