#!/usr/bin/env bash

set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:9600}"
PHONE="${PHONE:-13800010001}"
FIRST_LIMIT="${FIRST_LIMIT:-20}"
FIRST_OFFSET="${FIRST_OFFSET:-0}"
PAGE_LIMIT="${PAGE_LIMIT:-5}"
PAGE_OFFSET="${PAGE_OFFSET:-5}"
ZERO_CONVERSATION_ID="00000000-0000-0000-0000-000000000001"

HTTP_BODY=""
HTTP_STATUS=""
TOKEN=""
CODE=""
CONVERSATION_ID=""

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
    printf ' \\\n'
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
  local expected_status="$1"
  shift

  local response
  response="$(curl -sS -w '\n%{http_code}' "$@")"
  HTTP_STATUS="$(printf '%s\n' "$response" | tail -n 1)"
  HTTP_BODY="$(printf '%s\n' "$response" | sed '$d')"

  if [[ "$HTTP_STATUS" != "$expected_status" ]]; then
    echo "request expected status $expected_status, got $HTTP_STATUS" >&2
    print_json "$HTTP_BODY" >&2 || printf '%s\n' "$HTTP_BODY" >&2
    exit 1
  fi
}

perform_success_request() {
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

  print_step "Conversation API test link"
  echo "BASE_URL=$BASE_URL"
  echo "PHONE=$PHONE"

  local first_list_path
  first_list_path="/conversations?limit=${FIRST_LIMIT}&offset=${FIRST_OFFSET}"
  print_step "01 GET ${first_list_path} without token"
  show_curl "GET" "$first_list_path"
  perform_request "401" "$BASE_URL$first_list_path"
  print_json "$HTTP_BODY"

  local sms_payload
  sms_payload="{\"phone\":\"$PHONE\"}"
  print_step "02 POST /auth/sms"
  show_curl "POST" "/auth/sms" "$sms_payload"
  perform_success_request \
    -X POST "$BASE_URL/auth/sms" \
    -H "Content-Type: application/json" \
    -d "$sms_payload"
  print_json "$HTTP_BODY"
  CODE="$(printf '%s' "$HTTP_BODY" | jq -r '.code')"
  if [[ -z "$CODE" || "$CODE" == "null" ]]; then
    echo "missing sms code; ensure EXPOSE_DEBUG_SMS_CODE=true for local API tests" >&2
    exit 1
  fi
  echo "CODE=$CODE"

  local login_payload
  login_payload="{\"login_type\":\"sms_code\",\"phone\":\"$PHONE\",\"code\":\"$CODE\"}"
  print_step "03 POST /auth/login sms_code"
  show_curl "POST" "/auth/login" "$login_payload"
  perform_success_request \
    -X POST "$BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d "$login_payload"
  print_json "$HTTP_BODY"
  TOKEN="$(printf '%s' "$HTTP_BODY" | jq -r '.token')"
  if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
    echo "missing token from login response" >&2
    exit 1
  fi
  echo "TOKEN=$TOKEN"

  print_step "04 GET ${first_list_path}"
  show_curl "GET" "$first_list_path" "" "$TOKEN"
  perform_success_request \
    "$BASE_URL$first_list_path" \
    -H "Authorization: Bearer $TOKEN"
  print_json "$HTTP_BODY"
  jq -e 'type == "array"' >/dev/null <<<"$HTTP_BODY"
  CONVERSATION_ID="$(printf '%s' "$HTTP_BODY" | jq -r '.[0].id // empty')"
  if [[ -z "$CONVERSATION_ID" ]]; then
    echo "seeded conversation list is empty; run scripts/database/seed_im_conversations.sh first" >&2
    exit 1
  fi
  echo "CONVERSATION_ID=$CONVERSATION_ID"

  local page_path
  page_path="/conversations?limit=${PAGE_LIMIT}&offset=${PAGE_OFFSET}"
  print_step "05 GET ${page_path}"
  show_curl "GET" "$page_path" "" "$TOKEN"
  perform_success_request \
    "$BASE_URL$page_path" \
    -H "Authorization: Bearer $TOKEN"
  print_json "$HTTP_BODY"
  jq -e 'type == "array"' >/dev/null <<<"$HTTP_BODY"

  local invalid_path
  invalid_path="/conversations?limit=0&offset=0"
  print_step "06 GET ${invalid_path}"
  show_curl "GET" "$invalid_path" "" "$TOKEN"
  perform_request "400" \
    "$BASE_URL$invalid_path" \
    -H "Authorization: Bearer $TOKEN"
  print_json "$HTTP_BODY"
  jq -e '.message == "invalid limit"' >/dev/null <<<"$HTTP_BODY"

  local detail_unauthorized_path
  detail_unauthorized_path="/conversations/${ZERO_CONVERSATION_ID}"
  print_step "07 GET ${detail_unauthorized_path} without token"
  show_curl "GET" "$detail_unauthorized_path"
  perform_request "401" "$BASE_URL$detail_unauthorized_path"
  print_json "$HTTP_BODY"

  local read_unauthorized_path
  read_unauthorized_path="/conversations/${ZERO_CONVERSATION_ID}/read"
  print_step "08 POST ${read_unauthorized_path} without token"
  show_curl "POST" "$read_unauthorized_path"
  perform_request "401" -X POST "$BASE_URL$read_unauthorized_path"
  print_json "$HTTP_BODY"

  local messages_unauthorized_path
  messages_unauthorized_path="/conversations/${ZERO_CONVERSATION_ID}/messages?limit=10"
  print_step "09 GET ${messages_unauthorized_path} without token"
  show_curl "GET" "$messages_unauthorized_path"
  perform_request "401" "$BASE_URL$messages_unauthorized_path"
  print_json "$HTTP_BODY"

  local detail_path
  detail_path="/conversations/${CONVERSATION_ID}"
  print_step "10 GET ${detail_path}"
  show_curl "GET" "$detail_path" "" "$TOKEN"
  perform_success_request \
    "$BASE_URL$detail_path" \
    -H "Authorization: Bearer $TOKEN"
  print_json "$HTTP_BODY"
  jq -e --arg id "$CONVERSATION_ID" '.id == $id and has("peer_nickname") and has("unread_count")' >/dev/null <<<"$HTTP_BODY"

  local read_path
  read_path="/conversations/${CONVERSATION_ID}/read"
  print_step "11 POST ${read_path}"
  show_curl "POST" "$read_path" "" "$TOKEN"
  perform_success_request \
    -X POST "$BASE_URL$read_path" \
    -H "Authorization: Bearer $TOKEN"
  print_json "$HTTP_BODY"
  jq -e '.message == "conversation marked as read"' >/dev/null <<<"$HTTP_BODY"

  print_step "12 GET ${detail_path} after read"
  show_curl "GET" "$detail_path" "" "$TOKEN"
  perform_success_request \
    "$BASE_URL$detail_path" \
    -H "Authorization: Bearer $TOKEN"
  print_json "$HTTP_BODY"
  jq -e --arg id "$CONVERSATION_ID" '.id == $id and .unread_count == 0' >/dev/null <<<"$HTTP_BODY"

  local messages_path
  messages_path="/conversations/${CONVERSATION_ID}/messages?limit=10"
  print_step "13 GET ${messages_path}"
  show_curl "GET" "$messages_path" "" "$TOKEN"
  perform_success_request \
    "$BASE_URL$messages_path" \
    -H "Authorization: Bearer $TOKEN"
  print_json "$HTTP_BODY"
  jq -e 'type == "array"' >/dev/null <<<"$HTTP_BODY"

  local messages_page_path
  messages_page_path="/conversations/${CONVERSATION_ID}/messages?before_seq=999999&limit=5"
  print_step "14 GET ${messages_page_path}"
  show_curl "GET" "$messages_page_path" "" "$TOKEN"
  perform_success_request \
    "$BASE_URL$messages_page_path" \
    -H "Authorization: Bearer $TOKEN"
  print_json "$HTTP_BODY"
  jq -e 'type == "array"' >/dev/null <<<"$HTTP_BODY"

  local invalid_messages_path
  invalid_messages_path="/conversations/${CONVERSATION_ID}/messages?before_seq=0&limit=5"
  print_step "15 GET ${invalid_messages_path}"
  show_curl "GET" "$invalid_messages_path" "" "$TOKEN"
  perform_request "400" \
    "$BASE_URL$invalid_messages_path" \
    -H "Authorization: Bearer $TOKEN"
  print_json "$HTTP_BODY"
  jq -e '.message == "invalid before_seq"' >/dev/null <<<"$HTTP_BODY"

  print_step "Done"
  echo "Conversation API curl test link completed successfully."
}

main "$@"
