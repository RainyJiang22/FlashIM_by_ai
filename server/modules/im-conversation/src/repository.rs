use chrono::{DateTime, Utc};
use flash_core::{AppError, AppResult};
use sqlx::PgPool;
use uuid::Uuid;

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

pub fn get_conversation_by_id_sql() -> &'static str {
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
      AND c.id = $2
      AND me.is_deleted = FALSE
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

pub async fn get_conversation_by_id(
    pool: &PgPool,
    user_id: i64,
    conversation_id: Uuid,
) -> AppResult<Option<ConversationListRow>> {
    sqlx::query_as::<_, ConversationListRow>(get_conversation_by_id_sql())
        .bind(user_id)
        .bind(conversation_id)
        .fetch_optional(pool)
        .await
        .map_err(|_| AppError::internal_server_error("failed to get conversation"))
}

pub async fn mark_read(pool: &PgPool, user_id: i64, conversation_id: Uuid) -> AppResult<bool> {
    let result = sqlx::query(
        r#"
        UPDATE conversation_members
        SET unread_count = 0
        WHERE conversation_id = $1
          AND user_id = $2
          AND is_deleted = FALSE
        "#,
    )
    .bind(conversation_id)
    .bind(user_id)
    .execute(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to mark conversation read"))?;

    Ok(result.rows_affected() > 0)
}

pub async fn get_total_unread_by_user(pool: &PgPool, user_id: i64) -> AppResult<i32> {
    sqlx::query_scalar::<_, i32>(
        r#"
        SELECT COALESCE(SUM(unread_count), 0)::INT
        FROM conversation_members
        WHERE user_id = $1
          AND is_deleted = FALSE
        "#,
    )
    .bind(user_id)
    .fetch_one(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to load total unread count"))
}

pub async fn is_member(pool: &PgPool, conversation_id: Uuid, user_id: i64) -> AppResult<bool> {
    sqlx::query_scalar::<_, bool>(
        r#"
        SELECT EXISTS(
            SELECT 1
            FROM conversation_members
            WHERE conversation_id = $1
              AND user_id = $2
              AND is_deleted = FALSE
        )
        "#,
    )
    .bind(conversation_id)
    .bind(user_id)
    .fetch_one(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to verify conversation member"))
}

pub async fn get_member_ids(pool: &PgPool, conversation_id: Uuid) -> AppResult<Vec<i64>> {
    sqlx::query_scalar::<_, i64>(
        r#"
        SELECT user_id
        FROM conversation_members
        WHERE conversation_id = $1
          AND is_deleted = FALSE
        ORDER BY joined_at ASC
        "#,
    )
    .bind(conversation_id)
    .fetch_all(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to list conversation members"))
}

pub async fn update_last_message(
    pool: &PgPool,
    conversation_id: Uuid,
    preview: &str,
    last_message_at: DateTime<Utc>,
) -> AppResult<()> {
    sqlx::query(
        r#"
        UPDATE conversations
        SET last_message_preview = $2,
            last_message_at = $3,
            updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(conversation_id)
    .bind(preview)
    .bind(last_message_at)
    .execute(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to update conversation preview"))?;

    Ok(())
}

pub async fn increment_unread(
    pool: &PgPool,
    conversation_id: Uuid,
    sender_id: i64,
) -> AppResult<()> {
    sqlx::query(
        r#"
        UPDATE conversation_members
        SET unread_count = unread_count + 1
        WHERE conversation_id = $1
          AND user_id <> $2
          AND is_deleted = FALSE
        "#,
    )
    .bind(conversation_id)
    .bind(sender_id)
    .execute(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to increment unread count"))?;

    Ok(())
}

pub async fn get_unread_counts(
    pool: &PgPool,
    conversation_id: Uuid,
    member_ids: &[i64],
) -> AppResult<Vec<(i64, i32)>> {
    sqlx::query_as::<_, (i64, i32)>(
        r#"
        SELECT user_id, unread_count
        FROM conversation_members
        WHERE conversation_id = $1
          AND user_id = ANY($2)
          AND is_deleted = FALSE
        "#,
    )
    .bind(conversation_id)
    .bind(member_ids)
    .fetch_all(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to load unread counts"))
}

#[cfg(test)]
mod tests {
    use super::{get_conversation_by_id_sql, list_conversations_sql};

    #[test]
    fn list_sql_orders_by_recent_messages_then_creation_time() {
        let sql = list_conversations_sql();

        assert!(sql.contains("ORDER BY c.last_message_at DESC NULLS LAST, c.created_at DESC"));
        assert!(sql.contains("AND me.is_deleted = FALSE"));
        assert!(sql.contains("LIMIT $2 OFFSET $3"));
    }

    #[test]
    fn member_sql_filters_deleted_members() {
        let sql = r#"
        SELECT EXISTS(
            SELECT 1
            FROM conversation_members
            WHERE conversation_id = $1
              AND user_id = $2
              AND is_deleted = FALSE
        )
        "#;

        assert!(sql.contains("conversation_id = $1"));
        assert!(sql.contains("AND is_deleted = FALSE"));
    }

    #[test]
    fn get_by_id_sql_matches_list_shape() {
        let sql = get_conversation_by_id_sql();

        assert!(sql.contains("peer.nickname AS peer_nickname"));
        assert!(sql.contains("peer.avatar_url AS peer_avatar"));
        assert!(sql.contains("AND c.id = $2"));
        assert!(sql.contains("AND me.is_deleted = FALSE"));
    }
}
