use flash_core::{AppError, AppResult};
use sqlx::PgPool;

use crate::models::ConversationListRow;

pub fn list_conversations_sql() -> &'static str {
    r#"
    SELECT
        c.id,
        c.type,
        c.name,
        peer.account_id AS peer_user_id,
        peer.nickname AS peer_nickname,
        peer.avatar_url AS peer_avatar,
        c.last_message_at,
        c.last_message_preview,
        me.unread_count,
        c.created_at
    FROM conversation_members me
    JOIN conversations c ON c.id = me.conversation_id
    LEFT JOIN conversation_members peer_member
        ON peer_member.conversation_id = c.id
       AND peer_member.user_id <> me.user_id
       AND c.type = 0
    LEFT JOIN user_profiles peer
        ON peer.account_id = peer_member.user_id
    WHERE me.user_id = $1
      AND me.is_deleted = FALSE
    ORDER BY c.last_message_at DESC NULLS LAST, c.created_at DESC
    LIMIT $2 OFFSET $3
    "#
}

pub async fn list_conversations_by_user(
    pool: &PgPool,
    user_id: i64,
    limit: i64,
    offset: i64,
) -> AppResult<Vec<ConversationListRow>> {
    sqlx::query_as::<_, ConversationListRow>(list_conversations_sql())
        .bind(user_id)
        .bind(limit)
        .bind(offset)
        .fetch_all(pool)
        .await
        .map_err(|_| AppError::internal_server_error("failed to list conversations"))
}

#[cfg(test)]
mod tests {
    use super::list_conversations_sql;

    #[test]
    fn list_sql_orders_by_recent_messages_then_creation_time() {
        let sql = list_conversations_sql();

        assert!(sql.contains("ORDER BY c.last_message_at DESC NULLS LAST, c.created_at DESC"));
        assert!(sql.contains("AND me.is_deleted = FALSE"));
        assert!(sql.contains("LIMIT $2 OFFSET $3"));
    }
}
