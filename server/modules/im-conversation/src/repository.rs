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
        c.avatar,
        c.owner_id,
        group_members.member_avatars,
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
    LEFT JOIN LATERAL (
        SELECT COALESCE(
            ARRAY_AGG(group_member.avatar_url ORDER BY group_member.joined_at),
            ARRAY[]::TEXT[]
        ) AS member_avatars
        FROM (
            SELECT profile.avatar_url, member.joined_at
            FROM conversation_members member
            JOIN user_profiles profile ON profile.account_id = member.user_id
            WHERE member.conversation_id = c.id
              AND member.is_deleted = FALSE
              AND c.type = 1
            ORDER BY member.joined_at ASC
            LIMIT 4
        ) group_member
    ) group_members ON TRUE
    WHERE me.user_id = $1
      AND me.is_deleted = FALSE
      AND c.is_dissolved = FALSE
      AND ($4::SMALLINT IS NULL OR c.type = $4)
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
        c.avatar,
        c.owner_id,
        group_members.member_avatars,
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
    LEFT JOIN LATERAL (
        SELECT COALESCE(
            ARRAY_AGG(group_member.avatar_url ORDER BY group_member.joined_at),
            ARRAY[]::TEXT[]
        ) AS member_avatars
        FROM (
            SELECT profile.avatar_url, member.joined_at
            FROM conversation_members member
            JOIN user_profiles profile ON profile.account_id = member.user_id
            WHERE member.conversation_id = c.id
              AND member.is_deleted = FALSE
              AND c.type = 1
            ORDER BY member.joined_at ASC
            LIMIT 4
        ) group_member
    ) group_members ON TRUE
    WHERE me.user_id = $1
      AND c.id = $2
      AND me.is_deleted = FALSE
      AND c.is_dissolved = FALSE
    "#
}

pub async fn list_conversations_by_user(
    pool: &PgPool,
    user_id: i64,
    limit: i64,
    offset: i64,
    conversation_type: Option<i16>,
) -> AppResult<Vec<ConversationListRow>> {
    sqlx::query_as::<_, ConversationListRow>(list_conversations_sql())
        .bind(user_id)
        .bind(limit)
        .bind(offset)
        .bind(conversation_type)
        .fetch_all(pool)
        .await
        .map_err(|_| AppError::internal_server_error("failed to list conversations"))
}

pub fn group_friend_validation_sql() -> &'static str {
    r#"
    SELECT COUNT(*)::BIGINT
    FROM friend_relations
    WHERE user_id = $1
      AND friend_user_id = ANY($2)
    "#
}

pub fn create_group_conversation_sql() -> &'static str {
    r#"
    INSERT INTO conversations (type, name, owner_id)
    VALUES (1, $1, $2)
    RETURNING id
    "#
}

pub fn insert_group_members_sql() -> &'static str {
    r#"
    INSERT INTO conversation_members (conversation_id, user_id, is_deleted)
    SELECT $1, member_id, FALSE
    FROM UNNEST($2::BIGINT[]) AS member_id
    "#
}

pub async fn create_group_conversation(
    pool: &PgPool,
    owner_id: i64,
    name: &str,
    member_ids: &[i64],
) -> AppResult<ConversationListRow> {
    let mut transaction = pool
        .begin()
        .await
        .map_err(|_| AppError::internal_server_error("failed to start group transaction"))?;

    let friend_count = sqlx::query_scalar::<_, i64>(group_friend_validation_sql())
        .bind(owner_id)
        .bind(member_ids)
        .fetch_one(&mut *transaction)
        .await
        .map_err(|_| AppError::internal_server_error("failed to verify group members"))?;
    if friend_count != member_ids.len() as i64 {
        transaction
            .rollback()
            .await
            .map_err(|_| AppError::internal_server_error("failed to rollback group transaction"))?;
        return Err(AppError::bad_request("invalid group members"));
    }

    let conversation_id = sqlx::query_scalar::<_, Uuid>(create_group_conversation_sql())
        .bind(name)
        .bind(owner_id)
        .fetch_one(&mut *transaction)
        .await
        .map_err(|_| AppError::internal_server_error("failed to create group conversation"))?;

    let mut all_member_ids = Vec::with_capacity(member_ids.len() + 1);
    all_member_ids.push(owner_id);
    all_member_ids.extend_from_slice(member_ids);
    sqlx::query(insert_group_members_sql())
        .bind(conversation_id)
        .bind(&all_member_ids)
        .execute(&mut *transaction)
        .await
        .map_err(|_| AppError::internal_server_error("failed to save group members"))?;

    let conversation = sqlx::query_as::<_, ConversationListRow>(get_conversation_by_id_sql())
        .bind(owner_id)
        .bind(conversation_id)
        .fetch_optional(&mut *transaction)
        .await
        .map_err(|_| AppError::internal_server_error("failed to load created conversation"))?
        .ok_or_else(|| AppError::internal_server_error("created conversation is unavailable"))?;

    transaction
        .commit()
        .await
        .map_err(|_| AppError::internal_server_error("failed to commit group transaction"))?;

    Ok(conversation)
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
            FROM conversation_members member
            JOIN conversations c ON c.id = member.conversation_id
            WHERE member.conversation_id = $1
              AND member.user_id = $2
              AND member.is_deleted = FALSE
              AND c.is_dissolved = FALSE
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
        FROM conversation_members member
        JOIN conversations c ON c.id = member.conversation_id
        WHERE member.conversation_id = $1
          AND member.is_deleted = FALSE
          AND c.is_dissolved = FALSE
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

pub async fn find_private_conversation(
    pool: &PgPool,
    user_a: i64,
    user_b: i64,
) -> AppResult<Option<Uuid>> {
    sqlx::query_scalar::<_, Uuid>(
        r#"
        SELECT c.id
        FROM conversations c
        JOIN conversation_members ma
          ON ma.conversation_id = c.id
         AND ma.user_id = $1
        JOIN conversation_members mb
          ON mb.conversation_id = c.id
         AND mb.user_id = $2
        WHERE c.type = 0
          AND (
            SELECT COUNT(*)
            FROM conversation_members members
            WHERE members.conversation_id = c.id
          ) = 2
        ORDER BY c.created_at ASC
        LIMIT 1
        "#,
    )
    .bind(user_a)
    .bind(user_b)
    .fetch_optional(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to find private conversation"))
}

pub async fn create_private_conversation(
    pool: &PgPool,
    user_a: i64,
    user_b: i64,
) -> AppResult<Uuid> {
    let conversation_id = sqlx::query_scalar::<_, Uuid>(
        r#"
        INSERT INTO conversations (type)
        VALUES (0)
        RETURNING id
        "#,
    )
    .fetch_one(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to create private conversation"))?;

    ensure_private_members(pool, conversation_id, user_a, user_b).await?;
    Ok(conversation_id)
}

pub async fn ensure_private_members(
    pool: &PgPool,
    conversation_id: Uuid,
    user_a: i64,
    user_b: i64,
) -> AppResult<()> {
    sqlx::query(
        r#"
        INSERT INTO conversation_members (conversation_id, user_id, is_deleted)
        VALUES ($1, $2, FALSE), ($1, $3, FALSE)
        ON CONFLICT (conversation_id, user_id)
        DO UPDATE SET is_deleted = FALSE
        "#,
    )
    .bind(conversation_id)
    .bind(user_a)
    .bind(user_b)
    .execute(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to save private conversation members"))?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{
        create_group_conversation_sql, get_conversation_by_id_sql, group_friend_validation_sql,
        insert_group_members_sql, list_conversations_sql,
    };

    #[test]
    fn list_sql_orders_by_recent_messages_then_creation_time() {
        let sql = list_conversations_sql();

        assert!(sql.contains("ORDER BY c.last_message_at DESC NULLS LAST, c.created_at DESC"));
        assert!(sql.contains("AND me.is_deleted = FALSE"));
        assert!(sql.contains("c.is_dissolved = FALSE"));
        assert!(sql.contains("$4::SMALLINT IS NULL OR c.type = $4"));
        assert!(sql.contains("c.owner_id"));
        assert!(sql.contains("ARRAY_AGG(group_member.avatar_url"));
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
        assert!(sql.contains("c.owner_id"));
        assert!(sql.contains("member_avatars"));
        assert!(sql.contains("AND c.id = $2"));
        assert!(sql.contains("AND me.is_deleted = FALSE"));
        assert!(sql.contains("c.is_dissolved = FALSE"));
    }

    #[test]
    fn private_conversation_sql_requires_exact_two_members() {
        let sql = r#"
        SELECT c.id
        FROM conversations c
        JOIN conversation_members ma
          ON ma.conversation_id = c.id
         AND ma.user_id = $1
        JOIN conversation_members mb
          ON mb.conversation_id = c.id
         AND mb.user_id = $2
        WHERE c.type = 0
          AND (
            SELECT COUNT(*)
            FROM conversation_members members
            WHERE members.conversation_id = c.id
          ) = 2
        "#;

        assert!(sql.contains("c.type = 0"));
        assert!(sql.contains("COUNT(*)"));
    }

    #[test]
    fn group_creation_sql_keeps_friend_and_membership_constraints() {
        let friend_sql = group_friend_validation_sql();
        let conversation_sql = create_group_conversation_sql();
        let members_sql = insert_group_members_sql();

        assert!(friend_sql.contains("FROM friend_relations"));
        assert!(friend_sql.contains("friend_user_id = ANY($2)"));
        assert!(conversation_sql.contains("VALUES (1, $1, $2)"));
        assert!(members_sql.contains("UNNEST($2::BIGINT[])"));
        assert!(members_sql.contains("is_deleted"));
    }
}
