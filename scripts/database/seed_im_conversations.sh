#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/sqlx_common.sh"

USERS_JSON="${SCRIPT_DIR}/im_seed/users.json"
CONVERSATIONS_JSON="${SCRIPT_DIR}/im_seed/conversations.json"
DEFAULT_PASSWORD_HASH='$argon2id$v=19$m=19456,t=2,p=1$c3RhdGljLXNlZWQtMTExMTEx$ECf4DJCBwZqx4YiVLO6NaxX39AR/7q1ucfhLGJLNueA'

ensure_prerequisites

if [[ ! -f "${USERS_JSON}" ]]; then
  echo "Missing users seed file: ${USERS_JSON}"
  exit 1
fi

if [[ ! -f "${CONVERSATIONS_JSON}" ]]; then
  echo "Missing conversations seed file: ${CONVERSATIONS_JSON}"
  exit 1
fi

users_json="$(<"${USERS_JSON}")"
conversations_json="$(<"${CONVERSATIONS_JSON}")"

echo "==> Seeding IM users and conversations"
psql "${DATABASE_URL}" \
  -v ON_ERROR_STOP=1 \
  -v users_json="${users_json}" \
  -v conversations_json="${conversations_json}" \
  -v password_hash="${DEFAULT_PASSWORD_HASH}" <<'SQL'
WITH seed_users AS (
    SELECT *
    FROM jsonb_to_recordset(:'users_json'::jsonb) AS user_seed(
        id BIGINT,
        phone TEXT,
        nickname TEXT,
        password TEXT,
        signature TEXT,
        avatar TEXT
    )
), upsert_accounts AS (
    INSERT INTO accounts (id, primary_identifier, updated_at)
    SELECT id, phone, NOW()
    FROM seed_users
    ON CONFLICT (id) DO UPDATE
    SET primary_identifier = EXCLUDED.primary_identifier,
        updated_at = NOW()
    RETURNING id
), upsert_profiles AS (
    INSERT INTO user_profiles (account_id, nickname, avatar_url, signature, bio, updated_at)
    SELECT
        id,
        nickname,
        COALESCE(avatar, 'identicon:' || id::TEXT),
        COALESCE(signature, ''),
        '',
        NOW()
    FROM seed_users
    ON CONFLICT (account_id) DO UPDATE
    SET nickname = EXCLUDED.nickname,
        avatar_url = EXCLUDED.avatar_url,
        signature = EXCLUDED.signature,
        updated_at = NOW()
    RETURNING account_id
), upsert_phone_credentials AS (
    INSERT INTO auth_credentials (
        account_id,
        credential_type,
        identifier,
        metadata,
        verified_at,
        updated_at
    )
    SELECT id, 'phone', phone, '{}'::jsonb, NOW(), NOW()
    FROM seed_users
    ON CONFLICT (credential_type, identifier) DO UPDATE
    SET account_id = EXCLUDED.account_id,
        verified_at = NOW(),
        updated_at = NOW()
    RETURNING account_id
)
INSERT INTO auth_credentials (
    account_id,
    credential_type,
    identifier,
    password_hash,
    metadata,
    verified_at,
    updated_at
)
SELECT id, 'password', phone, :'password_hash', '{}'::jsonb, NOW(), NOW()
FROM seed_users
ON CONFLICT (credential_type, identifier) DO UPDATE
SET account_id = EXCLUDED.account_id,
    password_hash = EXCLUDED.password_hash,
    verified_at = NOW(),
    updated_at = NOW();

SELECT setval(
    pg_get_serial_sequence('accounts', 'id'),
    GREATEST((SELECT MAX(id) FROM accounts), 1),
    TRUE
);

WITH seed_conversations AS (
    SELECT *
    FROM jsonb_to_recordset(:'conversations_json'::jsonb) AS conversation_seed(
        owner_user_id BIGINT,
        peer_user_id BIGINT,
        type SMALLINT,
        last_message_preview TEXT,
        last_message_minutes_ago INT,
        unread_count_for_owner INT,
        unread_count_for_peer INT
    )
), conversation_ids AS (
    SELECT
        *,
        format(
            '%s-%s-%s-%s-%s',
            substr(seed_hash, 1, 8),
            substr(seed_hash, 9, 4),
            substr(seed_hash, 13, 4),
            substr(seed_hash, 17, 4),
            substr(seed_hash, 21, 12)
        )::uuid AS conversation_id
    FROM (
        SELECT
            seed_conversations.*,
            md5(
                'im-private:'
                || LEAST(seed_conversations.owner_user_id, seed_conversations.peer_user_id)::TEXT
                || ':'
                || GREATEST(seed_conversations.owner_user_id, seed_conversations.peer_user_id)::TEXT
            ) AS seed_hash
        FROM seed_conversations
    ) seeded
), upsert_conversations AS (
    INSERT INTO conversations (
        id,
        type,
        last_message_preview,
        last_message_at,
        updated_at
    )
    SELECT
        conversation_id,
        type,
        last_message_preview,
        CASE
            WHEN last_message_minutes_ago IS NULL THEN NULL
            ELSE NOW() - make_interval(mins => last_message_minutes_ago)
        END,
        NOW()
    FROM conversation_ids
    ON CONFLICT (id) DO UPDATE
    SET type = EXCLUDED.type,
        last_message_preview = EXCLUDED.last_message_preview,
        last_message_at = EXCLUDED.last_message_at,
        updated_at = NOW()
    RETURNING id
), owner_members AS (
    INSERT INTO conversation_members (
        conversation_id,
        user_id,
        unread_count,
        is_deleted
    )
    SELECT
        conversation_ids.conversation_id,
        conversation_ids.owner_user_id,
        COALESCE(conversation_ids.unread_count_for_owner, 0),
        FALSE
    FROM conversation_ids
    JOIN upsert_conversations ON upsert_conversations.id = conversation_ids.conversation_id
    ON CONFLICT (conversation_id, user_id) DO UPDATE
    SET unread_count = EXCLUDED.unread_count,
        is_deleted = FALSE
    RETURNING conversation_id
), peer_members AS (
    INSERT INTO conversation_members (
        conversation_id,
        user_id,
        unread_count,
        is_deleted
    )
    SELECT
        conversation_ids.conversation_id,
        conversation_ids.peer_user_id,
        COALESCE(conversation_ids.unread_count_for_peer, 0),
        FALSE
    FROM conversation_ids
    JOIN upsert_conversations ON upsert_conversations.id = conversation_ids.conversation_id
    ON CONFLICT (conversation_id, user_id) DO UPDATE
    SET unread_count = EXCLUDED.unread_count,
        is_deleted = FALSE
    RETURNING conversation_id
)
INSERT INTO conversation_seq (conversation_id)
SELECT conversation_id
FROM conversation_ids
ON CONFLICT (conversation_id) DO NOTHING;
SQL

psql "${DATABASE_URL}" -v ON_ERROR_STOP=1 <<'SQL'
SELECT 'accounts' AS table_name, COUNT(*) AS count FROM accounts
UNION ALL
SELECT 'conversations', COUNT(*) FROM conversations
UNION ALL
SELECT 'conversation_members', COUNT(*) FROM conversation_members
ORDER BY table_name;
SQL

echo "==> IM seed completed"
