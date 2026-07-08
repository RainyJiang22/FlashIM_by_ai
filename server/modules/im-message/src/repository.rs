use flash_core::{AppError, AppResult};
use sqlx::PgPool;
use uuid::Uuid;

use crate::models::{MessageRow, MessageWithSenderRow, NewMessage};

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

pub async fn insert_message(pool: &PgPool, message: NewMessage) -> AppResult<MessageRow> {
    sqlx::query_as::<_, MessageRow>(
        r#"
        INSERT INTO messages (conversation_id, sender_id, seq, type, content, extra)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING id, conversation_id, sender_id, seq, type, content, extra, status, created_at
        "#,
    )
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
    use super::find_before_sql;

    #[test]
    fn history_sql_uses_seq_pagination() {
        let sql = find_before_sql();

        assert!(sql.contains("m.seq < $2"));
        assert!(sql.contains("ORDER BY m.seq DESC"));
        assert!(sql.contains("LIMIT $3"));
    }
}
