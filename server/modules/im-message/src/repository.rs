use std::collections::HashMap;

use flash_core::{AppError, AppResult};
use sqlx::{PgPool, Postgres, Transaction};
use uuid::Uuid;

use crate::models::{MessageRow, MessageWithSenderRow, NewMessage};

pub struct PersistedMessage {
    pub row: MessageRow,
    pub member_ids: Vec<i64>,
    pub unread_counts: Vec<(i64, i32)>,
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
        p.nickname AS sender_name,
        p.avatar_url AS sender_avatar,
        m.seq,
        m.type,
        m.content,
        m.extra,
        m.status,
        m.created_at
    FROM messages m
    LEFT JOIN user_profiles p ON p.account_id = m.sender_id
    WHERE m.conversation_id = $1
      AND m.seq < $2
    ORDER BY m.seq DESC
    LIMIT $3
    "#
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

#[cfg(test)]
mod tests {
    use super::{active_conversation_lock_sql, find_before_sql, insert_message_sql};

    #[test]
    fn history_sql_uses_seq_pagination() {
        let sql = find_before_sql();

        assert!(sql.contains("m.seq < $2"));
        assert!(sql.contains("ORDER BY m.seq DESC"));
        assert!(sql.contains("LIMIT $3"));
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
}
