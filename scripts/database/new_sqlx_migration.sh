#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/sqlx_common.sh"

module_name="${1:-}"
change_name="${2:-}"

if [[ -z "${module_name}" || -z "${change_name}" ]]; then
  echo "Usage: bash scripts/database/new_sqlx_migration.sh <module> <change_name>"
  echo "Example: bash scripts/database/new_sqlx_migration.sh auth add_email_credential"
  exit 1
fi

if [[ ! "${module_name}" =~ ^[a-z0-9_]+$ ]]; then
  echo "module must contain only lowercase letters, digits, or underscores"
  exit 1
fi

if [[ ! "${change_name}" =~ ^[a-z0-9_]+$ ]]; then
  echo "change_name must contain only lowercase letters, digits, or underscores"
  exit 1
fi

ensure_prerequisites

description="${module_name}_${change_name}"

echo "==> Creating sqlx migration: ${description}"
(
  cd "${SERVER_DIR}"
  sqlx migrate add "${description}" --source "${MIGRATIONS_DIR}"
)
