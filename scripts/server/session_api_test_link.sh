#!/usr/bin/env bash

set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:9600}"
PHONE="${PHONE:-138$(date +%d%H%M%S)}"
INITIAL_PASSWORD="${INITIAL_PASSWORD:-new-password}"
CHANGED_PASSWORD="${CHANGED_PASSWORD:-new-password-2}"
NICKNAME="${NICKNAME:-Alice}"
SIGNATURE="${SIGNATURE:-hello}"
AVATAR="${AVATAR:-identicon:new-seed}"

HTTP_BODY=""
HTTP_STATUS=""
TOKEN=""
CODE=""

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

print_step() {
  printf '\n== %s ==\n' "$1"
}

print_json() {
  printf '%s\n' "$1" | jq .
}

show_curl() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local token="${4:-}"

  printf 'curl -sS -X %s "%s%s"' "$method" "$BASE_URL" "$path"
  if [[ -n "$body" || -n "$token" ]]; then
    printf ' \\\n'
  else
    printf '\n'
  fi

  if [[ -n "$body" ]]; then
    printf '  -H "Content-Type: application/json"'
    if [[ -n "$token" ]]; then
      printf ' \\\n'
    else
      printf ' \\\n'
    fi
  fi

  if [[ -n "$token" ]]; then
    printf '  -H "Authorization: Bearer %s"' "$token"
    if [[ -n "$body" ]]; then
      printf ' \\\n'
    else
      printf '\n'
    fi
  fi

  if [[ -n "$body" ]]; then
    printf "  -d '%s'\n" "$body"
  fi
}

perform_request() {
  local response

  response="$(curl -sS -w '\n%{http_code}' "$@")"
  HTTP_STATUS="$(printf '%s\n' "$response" | tail -n 1)"
  HTTP_BODY="$(printf '%s\n' "$response" | sed '$d')"

  if [[ "$HTTP_STATUS" -lt 200 || "$HTTP_STATUS" -ge 300 ]]; then
    echo "request failed with status $HTTP_STATUS" >&2
    print_json "$HTTP_BODY" >&2 || printf '%s\n' "$HTTP_BODY" >&2
    exit 1
  fi
}

main() {
  require_command curl
  require_command jq

  print_step "Session API test link"
  echo "BASE_URL=$BASE_URL"
  echo "PHONE=$PHONE"

  local sms_payload
  sms_payload="{\"phone\":\"$PHONE\"}"
  print_step "01 /auth/sms"
  show_curl "POST" "/auth/sms" "$sms_payload"
  perform_request \
    -X POST "$BASE_URL/auth/sms" \
    -H "Content-Type: application/json" \
    -d "$sms_payload"
  print_json "$HTTP_BODY"
  CODE="$(printf '%s' "$HTTP_BODY" | jq -r '.code')"
  echo "CODE=$CODE"

  local login_sms_payload
  login_sms_payload="{\"login_type\":\"sms_code\",\"phone\":\"$PHONE\",\"code\":\"$CODE\"}"
  print_step "02 /auth/login sms_code"
  show_curl "POST" "/auth/login" "$login_sms_payload"
  perform_request \
    -X POST "$BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d "$login_sms_payload"
  print_json "$HTTP_BODY"
  TOKEN="$(printf '%s' "$HTTP_BODY" | jq -r '.token')"
  echo "TOKEN=$TOKEN"

  print_step "03 GET /user/profile"
  show_curl "GET" "/user/profile" "" "$TOKEN"
  perform_request \
    "$BASE_URL/user/profile" \
    -H "Authorization: Bearer $TOKEN"
  print_json "$HTTP_BODY"

  local update_profile_payload
  update_profile_payload="{\"nickname\":\"$NICKNAME\",\"signature\":\"$SIGNATURE\",\"avatar\":\"$AVATAR\"}"
  print_step "04 PUT /user/profile"
  show_curl "PUT" "/user/profile" "$update_profile_payload" "$TOKEN"
  perform_request \
    -X PUT "$BASE_URL/user/profile" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "$update_profile_payload"
  print_json "$HTTP_BODY"

  local set_password_payload
  set_password_payload="{\"new_password\":\"$INITIAL_PASSWORD\"}"
  print_step "05 POST /user/password"
  show_curl "POST" "/user/password" "$set_password_payload" "$TOKEN"
  perform_request \
    -X POST "$BASE_URL/user/password" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "$set_password_payload"
  print_json "$HTTP_BODY"

  local change_password_payload
  change_password_payload="{\"old_password\":\"$INITIAL_PASSWORD\",\"new_password\":\"$CHANGED_PASSWORD\"}"
  print_step "06 PUT /user/password"
  show_curl "PUT" "/user/password" "$change_password_payload" "$TOKEN"
  perform_request \
    -X PUT "$BASE_URL/user/password" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "$change_password_payload"
  print_json "$HTTP_BODY"

  local login_password_payload
  login_password_payload="{\"login_type\":\"password\",\"identifier\":\"$PHONE\",\"password\":\"$CHANGED_PASSWORD\"}"
  print_step "07 /auth/login password"
  show_curl "POST" "/auth/login" "$login_password_payload"
  perform_request \
    -X POST "$BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d "$login_password_payload"
  print_json "$HTTP_BODY"

  print_step "Done"
  echo "Session API curl test link completed successfully."
}

main "$@"
