use std::collections::HashMap;

use chrono::{DateTime, Utc};
use flash_core::{AppError, AppResult};
use sqlx::{PgPool, Postgres, Transaction};
use uuid::Uuid;

use crate::models::{MessageRow, MessageSearchRow, MessageWithSenderRow, NewMessage};

pub struct PersistedMessage {
    pub row: MessageRow,
    pub member_ids: Vec<i64>,
    pub unread_counts: Vec<(i64, i32)>,
}

pub struct ReadAdvance {
    pub conversation_id: Uuid,
    pub reader_id: i64,
    pub previous_read_seq: i64,
    pub read_seq: i64,
    pub unread_count: i32,
    pub member_ids: Vec<i64>,
    pub last_message_preview: String,
    pub last_message_at: Option<DateTime<Utc>>,
}

#[derive(Clone, Debug, sqlx::FromRow)]
pub struct ReadStatusMessageRow {
    pub id: Uuid,
    pub conversation_id: Uuid,
    pub sender_id: i64,
    pub seq: i64,
}

#[derive(Clone, Debug, sqlx::FromRow)]
pub struct ReadStatusMemberRow {
    pub user_id: i64,
    pub nickname: Option<String>,
    pub avatar: Option<String>,
    pub last_read_seq: i64,
}

#[derive(Clone, Debug, sqlx::FromRow)]
pub struct MentionMemberRow {
    pub user_id: i64,
    pub nickname: Option<String>,
    pub is_owner: bool,
    pub is_admin: bool,
}

pub async fn list_mention_members(
    pool: &PgPool,
    conversation_id: Uuid,
) -> AppResult<Vec<MentionMemberRow>> {
    sqlx::query_as::<_, MentionMemberRow>(
        r#"
        SELECT
            member.user_id,
            COALESCE(NULLIF(BTRIM(member.group_nickname), ''), profile.nickname) AS nickname,
            member.user_id = conversation.owner_id AS is_owner,
            member.is_admin
        FROM conversation_members member
        JOIN conversations conversation
          ON conversation.id = member.conversation_id
         AND conversation.type = 1
         AND conversation.is_dissolved = FALSE
        LEFT JOIN user_profiles profile ON profile.account_id = member.user_id
        WHERE member.conversation_id = $1
          AND member.is_deleted = FALSE
        ORDER BY member.joined_at ASC, member.user_id ASC
        "#,
    )
    .bind(conversation_id)
    .fetch_all(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to load mention members"))
}

pub async fn get_user_display_name(pool: &PgPool, user_id: i64) -> AppResult<Option<String>> {
    sqlx::query_scalar::<_, Option<String>>(
        r#"
        SELECT nickname
        FROM user_profiles
        WHERE account_id = $1
        "#,
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map(|nickname| nickname.flatten())
    .map_err(|_| AppError::internal_server_error("failed to load message sender"))
}

pub async fn get_user_display_names(
    pool: &PgPool,
    user_ids: &[i64],
) -> AppResult<HashMap<i64, String>> {
    let rows = sqlx::query_as::<_, (i64, Option<String>)>(
        r#"
        SELECT account_id, nickname
        FROM user_profiles
        WHERE account_id = ANY($1)
        "#,
    )
    .bind(user_ids)
    .fetch_all(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to load message senders"))?;
    Ok(rows
        .into_iter()
        .filter_map(|(user_id, nickname)| {
            nickname
                .filter(|value| !value.trim().is_empty())
                .map(|value| (user_id, value))
        })
        .collect())
}

pub fn active_conversation_lock_sql() -> &'static str {
    r#"
        SELECT c.id
        FROM conversations c
        JOIN conversation_members sender
          ON sender.conversation_id = c.id
         AND sender.user_id = $2
         AND sender.is_deleted = FALSE
        WHERE c.id = $1
          AND c.is_dissolved = FALSE
        FOR UPDATE OF c
    "#
}

pub async fn persist_message(
    pool: &PgPool,
    message: NewMessage,
    preview: &str,
) -> AppResult<PersistedMessage> {
    let mut transaction = pool
        .begin()
        .await
        .map_err(|_| AppError::internal_server_error("failed to start message transaction"))?;

    let active_conversation = sqlx::query_scalar::<_, Uuid>(active_conversation_lock_sql())
        .bind(message.conversation_id)
        .bind(message.sender_id)
        .fetch_optional(&mut *transaction)
        .await
        .map_err(|_| AppError::internal_server_error("failed to lock conversation"))?;
    if active_conversation.is_none() {
        return Err(AppError::not_found("conversation not found"));
    }

    let persisted = persist_message_in_transaction(&mut transaction, message, preview).await?;

    transaction
        .commit()
        .await
        .map_err(|_| AppError::internal_server_error("failed to commit message transaction"))?;
    Ok(persisted)
}

async fn persist_message_in_transaction(
    transaction: &mut Transaction<'_, Postgres>,
    message: NewMessage,
    preview: &str,
) -> AppResult<PersistedMessage> {
    let seq = sqlx::query_scalar::<_, i64>(
        r#"
        INSERT INTO conversation_seq (conversation_id, current_seq)
        VALUES ($1, 1)
        ON CONFLICT (conversation_id)
        DO UPDATE SET current_seq = conversation_seq.current_seq + 1
        RETURNING current_seq
        "#,
    )
    .bind(message.conversation_id)
    .fetch_one(&mut **transaction)
    .await
    .map_err(|_| AppError::internal_server_error("failed to generate message sequence"))?;

    let row = sqlx::query_as::<_, MessageRow>(insert_message_sql())
        .bind(message.conversation_id)
        .bind(message.sender_id)
        .bind(seq)
        .bind(message.r#type)
        .bind(message.content)
        .bind(message.extra)
        .fetch_one(&mut **transaction)
        .await
        .map_err(|_| AppError::internal_server_error("failed to insert message"))?;

    sqlx::query(
        r#"
        UPDATE conversations
        SET last_message_preview = $2, last_message_at = $3, updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(row.conversation_id)
    .bind(preview)
    .bind(row.created_at)
    .execute(&mut **transaction)
    .await
    .map_err(|_| AppError::internal_server_error("failed to update conversation preview"))?;

    sqlx::query(
        r#"
        UPDATE conversation_members
        SET unread_count = unread_count + 1
        WHERE conversation_id = $1
          AND user_id <> $2
          AND is_deleted = FALSE
        "#,
    )
    .bind(row.conversation_id)
    .bind(row.sender_id)
    .execute(&mut **transaction)
    .await
    .map_err(|_| AppError::internal_server_error("failed to increment unread count"))?;

    let member_ids = sqlx::query_scalar::<_, i64>(
        r#"
        SELECT user_id
        FROM conversation_members
        WHERE conversation_id = $1 AND is_deleted = FALSE
        ORDER BY joined_at ASC
        "#,
    )
    .bind(row.conversation_id)
    .fetch_all(&mut **transaction)
    .await
    .map_err(|_| AppError::internal_server_error("failed to load conversation members"))?;
    let unread_counts = sqlx::query_as::<_, (i64, i32)>(
        r#"
        SELECT user_id, unread_count
        FROM conversation_members
        WHERE conversation_id = $1
          AND user_id = ANY($2)
          AND is_deleted = FALSE
        "#,
    )
    .bind(row.conversation_id)
    .bind(&member_ids)
    .fetch_all(&mut **transaction)
    .await
    .map_err(|_| AppError::internal_server_error("failed to load unread counts"))?;

    Ok(PersistedMessage {
        row,
        member_ids,
        unread_counts,
    })
}

pub async fn persist_system_message_in_transaction(
    transaction: &mut Transaction<'_, Postgres>,
    message: NewMessage,
    preview: &str,
) -> AppResult<PersistedMessage> {
    if message.r#type != crate::service::GROUP_CREATED_MESSAGE_TYPE {
        return Err(AppError::bad_request("invalid group system message"));
    }
    persist_message_in_transaction(transaction, message, preview).await
}

pub fn find_before_sql() -> &'static str {
    r#"
    SELECT
        m.id,
        m.conversation_id,
        m.sender_id,
        COALESCE(NULLIF(BTRIM(member.group_nickname), ''), p.nickname) AS sender_name,
        p.avatar_url AS sender_avatar,
        m.seq,
        m.type,
        m.content,
        m.extra,
        m.status,
        m.created_at,
        (
            SELECT COUNT(*)::INT
            FROM conversation_members reader
            WHERE reader.conversation_id = m.conversation_id
              AND reader.user_id <> m.sender_id
              AND reader.is_deleted = FALSE
              AND reader.last_read_seq >= m.seq
        ) AS read_count
    FROM messages m
    LEFT JOIN conversation_members member
      ON member.conversation_id = m.conversation_id
     AND member.user_id = m.sender_id
    LEFT JOIN user_profiles p ON p.account_id = m.sender_id
    WHERE m.conversation_id = $1
      AND m.seq < $2
    ORDER BY m.seq DESC
    LIMIT $3
    "#
}

pub async fn advance_read_seq(
    pool: &PgPool,
    conversation_id: Uuid,
    reader_id: i64,
    requested_read_seq: i64,
) -> AppResult<ReadAdvance> {
    let mut transaction = pool
        .begin()
        .await
        .map_err(|_| AppError::internal_server_error("failed to start read transaction"))?;

    let state = sqlx::query_as::<_, (i64, i64)>(
        r#"
        SELECT member.last_read_seq, COALESCE(seq.current_seq, 0)
        FROM conversation_members member
        JOIN conversations conversation
          ON conversation.id = member.conversation_id
         AND conversation.is_dissolved = FALSE
        LEFT JOIN conversation_seq seq ON seq.conversation_id = conversation.id
        WHERE member.conversation_id = $1
          AND member.user_id = $2
          AND member.is_deleted = FALSE
        FOR UPDATE OF member
        "#,
    )
    .bind(conversation_id)
    .bind(reader_id)
    .fetch_optional(&mut *transaction)
    .await
    .map_err(|_| AppError::internal_server_error("failed to lock read position"))?
    .ok_or(AppError::not_found("conversation not found"))?;

    let (previous_read_seq, current_seq) = state;
    if requested_read_seq > current_seq {
        return Err(AppError::bad_request("read seq exceeds conversation seq"));
    }
    let read_seq = previous_read_seq.max(requested_read_seq);
    let unread_count = sqlx::query_scalar::<_, i32>(
        r#"
        UPDATE conversation_members
        SET
            last_read_seq = $3,
            unread_count = (
                SELECT COUNT(*)::INT
                FROM messages message
                WHERE message.conversation_id = $1
                  AND message.seq > $3
                  AND message.sender_id <> $2
            )
        WHERE conversation_id = $1
          AND user_id = $2
          AND is_deleted = FALSE
        RETURNING unread_count
        "#,
    )
    .bind(conversation_id)
    .bind(reader_id)
    .bind(read_seq)
    .fetch_one(&mut *transaction)
    .await
    .map_err(|_| AppError::internal_server_error("failed to advance read position"))?;

    let member_ids = sqlx::query_scalar::<_, i64>(
        r#"
        SELECT user_id
        FROM conversation_members
        WHERE conversation_id = $1
          AND is_deleted = FALSE
        ORDER BY joined_at ASC, user_id ASC
        "#,
    )
    .bind(conversation_id)
    .fetch_all(&mut *transaction)
    .await
    .map_err(|_| AppError::internal_server_error("failed to load receipt recipients"))?;
    let (last_message_preview, last_message_at) =
        sqlx::query_as::<_, (Option<String>, Option<DateTime<Utc>>)>(
            r#"
            SELECT last_message_preview, last_message_at
            FROM conversations
            WHERE id = $1
            "#,
        )
        .bind(conversation_id)
        .fetch_one(&mut *transaction)
        .await
        .map_err(|_| AppError::internal_server_error("failed to load conversation preview"))?;

    transaction
        .commit()
        .await
        .map_err(|_| AppError::internal_server_error("failed to commit read transaction"))?;

    Ok(ReadAdvance {
        conversation_id,
        reader_id,
        previous_read_seq,
        read_seq,
        unread_count,
        member_ids,
        last_message_preview: last_message_preview.unwrap_or_default(),
        last_message_at,
    })
}

pub async fn find_message_for_read_status(
    pool: &PgPool,
    conversation_id: Uuid,
    message_id: Uuid,
    requester_id: i64,
) -> AppResult<Option<ReadStatusMessageRow>> {
    sqlx::query_as::<_, ReadStatusMessageRow>(
        r#"
        SELECT message.id, message.conversation_id, message.sender_id, message.seq
        FROM messages message
        JOIN conversations conversation
          ON conversation.id = message.conversation_id
        JOIN conversation_members requester
          ON requester.conversation_id = conversation.id
         AND requester.user_id = $3
         AND requester.is_deleted = FALSE
        WHERE message.conversation_id = $1
          AND message.id = $2
        "#,
    )
    .bind(conversation_id)
    .bind(message_id)
    .bind(requester_id)
    .fetch_optional(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to load message read status"))
}

pub async fn list_read_status_members(
    pool: &PgPool,
    conversation_id: Uuid,
    sender_id: i64,
) -> AppResult<Vec<ReadStatusMemberRow>> {
    sqlx::query_as::<_, ReadStatusMemberRow>(
        r#"
        SELECT
            member.user_id,
            COALESCE(NULLIF(BTRIM(member.group_nickname), ''), profile.nickname) AS nickname,
            profile.avatar_url AS avatar,
            member.last_read_seq
        FROM conversation_members member
        LEFT JOIN user_profiles profile ON profile.account_id = member.user_id
        WHERE member.conversation_id = $1
          AND member.user_id <> $2
          AND member.is_deleted = FALSE
        ORDER BY member.joined_at ASC, member.user_id ASC
        "#,
    )
    .bind(conversation_id)
    .bind(sender_id)
    .fetch_all(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to load read status members"))
}

pub fn insert_message_sql() -> &'static str {
    r#"
        INSERT INTO messages (conversation_id, sender_id, seq, type, content, extra)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING id, conversation_id, sender_id, seq, type, content, extra, status, created_at
        "#
}

pub async fn insert_message(pool: &PgPool, message: NewMessage) -> AppResult<MessageRow> {
    sqlx::query_as::<_, MessageRow>(insert_message_sql())
        .bind(message.conversation_id)
        .bind(message.sender_id)
        .bind(message.seq)
        .bind(message.r#type)
        .bind(message.content)
        .bind(message.extra)
        .fetch_one(pool)
        .await
        .map_err(|_| AppError::internal_server_error("failed to insert message"))
}

pub async fn find_before(
    pool: &PgPool,
    conversation_id: Uuid,
    before_seq: i64,
    limit: i64,
) -> AppResult<Vec<MessageWithSenderRow>> {
    sqlx::query_as::<_, MessageWithSenderRow>(find_before_sql())
        .bind(conversation_id)
        .bind(before_seq)
        .bind(limit)
        .fetch_all(pool)
        .await
        .map_err(|_| AppError::internal_server_error("failed to list messages"))
}

pub fn search_messages_sql() -> &'static str {
    r#"
    WITH matching AS (
        SELECT
            m.id,
            m.conversation_id,
            m.sender_id,
            COALESCE(NULLIF(BTRIM(sender_member.group_nickname), ''), profile.nickname)
                AS sender_name,
            profile.avatar_url AS sender_avatar,
            m.seq,
            m.type,
            m.content,
            m.extra,
            m.status,
            m.created_at,
            0::INT AS read_count,
            COUNT(*) OVER (PARTITION BY m.conversation_id)::BIGINT AS match_count,
            ROW_NUMBER() OVER (
                PARTITION BY m.conversation_id
                ORDER BY m.seq DESC, m.id DESC
            ) AS message_rank,
            MAX(m.created_at) OVER (PARTITION BY m.conversation_id) AS latest_match_at
        FROM messages m
        JOIN conversation_members viewer
          ON viewer.conversation_id = m.conversation_id
         AND viewer.user_id = $1
         AND viewer.is_deleted = FALSE
        LEFT JOIN conversation_members sender_member
          ON sender_member.conversation_id = m.conversation_id
         AND sender_member.user_id = m.sender_id
        LEFT JOIN user_profiles profile ON profile.account_id = m.sender_id
        WHERE m.type <> 5
          AND m.content ILIKE $2 ESCAPE '\'
    ), selected_conversations AS (
        SELECT conversation_id, MAX(latest_match_at) AS latest_match_at
        FROM matching
        GROUP BY conversation_id
        ORDER BY latest_match_at DESC, conversation_id ASC
        LIMIT $3
    )
    SELECT
        matching.id,
        matching.conversation_id,
        matching.sender_id,
        matching.sender_name,
        matching.sender_avatar,
        matching.seq,
        matching.type,
        matching.content,
        matching.extra,
        matching.status,
        matching.created_at,
        matching.read_count,
        matching.match_count
    FROM matching
    JOIN selected_conversations selected
      ON selected.conversation_id = matching.conversation_id
    WHERE matching.message_rank <= $4
    ORDER BY selected.latest_match_at DESC, matching.conversation_id ASC, matching.seq DESC
    "#
}

pub async fn search_messages(
    pool: &PgPool,
    user_id: i64,
    like_pattern: &str,
    group_limit: i64,
    message_limit: i64,
) -> AppResult<Vec<MessageSearchRow>> {
    sqlx::query_as::<_, MessageSearchRow>(search_messages_sql())
        .bind(user_id)
        .bind(like_pattern)
        .bind(group_limit)
        .bind(message_limit)
        .fetch_all(pool)
        .await
        .map_err(|_| AppError::internal_server_error("failed to search messages"))
}

pub fn search_conversation_messages_sql() -> &'static str {
    r#"
    SELECT
        m.id,
        m.conversation_id,
        m.sender_id,
        COALESCE(NULLIF(BTRIM(sender_member.group_nickname), ''), profile.nickname)
            AS sender_name,
        profile.avatar_url AS sender_avatar,
        m.seq,
        m.type,
        m.content,
        m.extra,
        m.status,
        m.created_at,
        0::INT AS read_count
    FROM messages m
    JOIN conversation_members viewer
      ON viewer.conversation_id = m.conversation_id
     AND viewer.user_id = $2
     AND viewer.is_deleted = FALSE
    LEFT JOIN conversation_members sender_member
      ON sender_member.conversation_id = m.conversation_id
     AND sender_member.user_id = m.sender_id
    LEFT JOIN user_profiles profile ON profile.account_id = m.sender_id
    WHERE m.conversation_id = $1
      AND m.type <> 5
      AND m.content ILIKE $3 ESCAPE '\'
    ORDER BY m.seq DESC
    LIMIT $4
    "#
}

pub async fn search_conversation_messages(
    pool: &PgPool,
    conversation_id: Uuid,
    user_id: i64,
    like_pattern: &str,
    limit: i64,
) -> AppResult<Vec<MessageWithSenderRow>> {
    sqlx::query_as::<_, MessageWithSenderRow>(search_conversation_messages_sql())
        .bind(conversation_id)
        .bind(user_id)
        .bind(like_pattern)
        .bind(limit)
        .fetch_all(pool)
        .await
        .map_err(|_| AppError::internal_server_error("failed to search conversation messages"))
}

#[cfg(test)]
mod tests {
    use super::{
        active_conversation_lock_sql, find_before_sql, insert_message_sql,
        search_conversation_messages_sql, search_messages_sql,
    };

    #[test]
    fn history_sql_uses_seq_pagination() {
        let sql = find_before_sql();

        assert!(sql.contains("m.seq < $2"));
        assert!(sql.contains("ORDER BY m.seq DESC"));
        assert!(sql.contains("LIMIT $3"));
        assert!(sql.contains("member.group_nickname"));
        assert!(sql.contains("COALESCE"));
        assert!(sql.contains("reader.last_read_seq >= m.seq"));
        assert!(sql.contains("reader.user_id <> m.sender_id"));
    }

    #[test]
    fn insert_sql_writes_type_and_extra() {
        let sql = insert_message_sql();

        assert!(sql.contains("INSERT INTO messages"));
        assert!(sql.contains("(conversation_id, sender_id, seq, type, content, extra)"));
        assert!(sql.contains("VALUES ($1, $2, $3, $4, $5, $6)"));
    }

    #[test]
    fn message_write_locks_only_active_conversation() {
        let sql = active_conversation_lock_sql();
        assert!(sql.contains("sender.is_deleted = FALSE"));
        assert!(sql.contains("c.is_dissolved = FALSE"));
        assert!(sql.contains("FOR UPDATE OF c"));
    }

    #[test]
    fn global_search_is_member_scoped_grouped_and_excludes_system_events() {
        let sql = search_messages_sql();

        assert!(sql.contains("viewer.user_id = $1"));
        assert!(sql.contains("viewer.is_deleted = FALSE"));
        assert!(sql.contains("m.type <> 5"));
        assert!(sql.contains("ILIKE $2 ESCAPE '\\'"));
        assert!(sql.contains("COUNT(*) OVER (PARTITION BY m.conversation_id)"));
        assert!(sql.contains("matching.message_rank <= $4"));
    }

    #[test]
    fn conversation_search_is_member_scoped_and_bounded() {
        let sql = search_conversation_messages_sql();

        assert!(sql.contains("m.conversation_id = $1"));
        assert!(sql.contains("viewer.user_id = $2"));
        assert!(sql.contains("viewer.is_deleted = FALSE"));
        assert!(sql.contains("m.type <> 5"));
        assert!(sql.contains("LIMIT $4"));
    }
}
