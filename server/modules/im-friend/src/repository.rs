use flash_core::{AppError, AppResult};
use sqlx::PgPool;
use uuid::Uuid;

use crate::models::{
    FriendRequestRow, FriendUserRow, RELATION_FRIEND, RELATION_NONE, RELATION_PENDING_RECEIVED,
    RELATION_PENDING_SENT,
};

const USER_SELECT: &str = r#"
    p.account_id,
    p.nickname,
    p.avatar_url AS avatar,
    p.signature,
    p.flash_id,
"#;

pub fn relation_status_case() -> &'static str {
    r#"
    CASE
        WHEN EXISTS (
            SELECT 1 FROM friend_relations fr
            WHERE fr.user_id = $1 AND fr.friend_user_id = p.account_id
        ) THEN 'friend'
        WHEN EXISTS (
            SELECT 1 FROM friend_requests req
            WHERE req.from_user_id = $1
              AND req.to_user_id = p.account_id
              AND req.status = 0
        ) THEN 'pending_sent'
        WHEN EXISTS (
            SELECT 1 FROM friend_requests req
            WHERE req.from_user_id = p.account_id
              AND req.to_user_id = $1
              AND req.status = 0
        ) THEN 'pending_received'
        ELSE 'none'
    END AS relation_status
    "#
}

pub async fn user_exists(pool: &PgPool, account_id: i64) -> AppResult<bool> {
    sqlx::query_scalar::<_, bool>(
        r#"
        SELECT EXISTS(SELECT 1 FROM accounts WHERE id = $1)
        "#,
    )
    .bind(account_id)
    .fetch_one(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to verify user"))
}

pub async fn are_friends(pool: &PgPool, user_id: i64, friend_user_id: i64) -> AppResult<bool> {
    sqlx::query_scalar::<_, bool>(
        r#"
        SELECT EXISTS(
            SELECT 1
            FROM friend_relations
            WHERE user_id = $1
              AND friend_user_id = $2
        )
        "#,
    )
    .bind(user_id)
    .bind(friend_user_id)
    .fetch_one(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to verify friend relation"))
}

pub async fn search_users(
    pool: &PgPool,
    current_user_id: i64,
    query: &str,
    limit: i64,
) -> AppResult<Vec<FriendUserRow>> {
    let like_query = format!("%{query}%");
    let rows = sqlx::query_as::<_, FriendUserRow>(&format!(
        r#"
        SELECT
            {USER_SELECT}
            {relation_status},
            NULL::TIMESTAMPTZ AS created_at
        FROM user_profiles p
        LEFT JOIN auth_credentials phone
            ON phone.account_id = p.account_id
           AND phone.credential_type = 'phone'
        WHERE p.account_id <> $1
          AND (
            phone.identifier = $2
            OR p.flash_id = $2
            OR p.nickname ILIKE $3
          )
        ORDER BY
            CASE
                WHEN phone.identifier = $2 THEN 0
                WHEN p.flash_id = $2 THEN 1
                ELSE 2
            END,
            p.nickname ASC
        LIMIT $4
        "#,
        relation_status = relation_status_case()
    ))
    .bind(current_user_id)
    .bind(query)
    .bind(like_query)
    .bind(limit)
    .fetch_all(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to search users"))?;

    Ok(rows)
}

pub async fn get_public_user(
    pool: &PgPool,
    current_user_id: i64,
    account_id: i64,
) -> AppResult<Option<FriendUserRow>> {
    sqlx::query_as::<_, FriendUserRow>(&format!(
        r#"
        SELECT
            {USER_SELECT}
            {relation_status},
            NULL::TIMESTAMPTZ AS created_at
        FROM user_profiles p
        WHERE p.account_id = $2
        "#,
        relation_status = relation_status_case()
    ))
    .bind(current_user_id)
    .bind(account_id)
    .fetch_optional(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to load user profile"))
}

pub async fn upsert_friend_request(
    pool: &PgPool,
    from_user_id: i64,
    to_user_id: i64,
    message: &str,
) -> AppResult<FriendRequestRow> {
    sqlx::query_as::<_, FriendRequestRow>(&friend_request_select_sql(
        r#"
        WITH upserted AS (
            INSERT INTO friend_requests (
                from_user_id,
                to_user_id,
                message,
                status,
                created_at,
                updated_at,
                handled_at,
                from_deleted_at,
                to_deleted_at
            )
            VALUES ($1, $2, $3, 0, NOW(), NOW(), NULL, NULL, NULL)
            ON CONFLICT (from_user_id, to_user_id)
            DO UPDATE SET
                message = EXCLUDED.message,
                status = 0,
                updated_at = NOW(),
                handled_at = NULL,
                from_deleted_at = NULL,
                to_deleted_at = NULL
            RETURNING *
        )
        SELECT
        "#,
    ))
    .bind(from_user_id)
    .bind(to_user_id)
    .bind(message)
    .fetch_one(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to save friend request"))
}

pub async fn get_request_by_id(
    pool: &PgPool,
    request_id: Uuid,
) -> AppResult<Option<FriendRequestRow>> {
    sqlx::query_as::<_, FriendRequestRow>(&format!(
        r#"
        SELECT
            {projection}
        FROM friend_requests req
        JOIN user_profiles fp ON fp.account_id = req.from_user_id
        JOIN user_profiles tp ON tp.account_id = req.to_user_id
        WHERE req.id = $1
        "#,
        projection = friend_request_projection()
    ))
    .bind(request_id)
    .fetch_optional(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to load friend request"))
}

pub async fn list_received_requests(
    pool: &PgPool,
    user_id: i64,
    status: Option<i16>,
    limit: i64,
    offset: i64,
) -> AppResult<Vec<FriendRequestRow>> {
    let status_filter = if status.is_some() {
        "AND req.status = $2"
    } else {
        ""
    };
    let limit_index = if status.is_some() { "$3" } else { "$2" };
    let offset_index = if status.is_some() { "$4" } else { "$3" };
    let sql = format!(
        r#"
        SELECT
            {friend_request_projection}
        FROM friend_requests req
        JOIN user_profiles fp ON fp.account_id = req.from_user_id
        JOIN user_profiles tp ON tp.account_id = req.to_user_id
        WHERE req.to_user_id = $1
          AND req.to_deleted_at IS NULL
          {status_filter}
        ORDER BY req.updated_at DESC
        LIMIT {limit_index} OFFSET {offset_index}
        "#,
        friend_request_projection = friend_request_projection()
    );
    let mut query = sqlx::query_as::<_, FriendRequestRow>(&sql).bind(user_id);
    if let Some(status) = status {
        query = query.bind(status);
    }
    query
        .bind(limit)
        .bind(offset)
        .fetch_all(pool)
        .await
        .map_err(|_| AppError::internal_server_error("failed to list received friend requests"))
}

pub async fn list_sent_requests(
    pool: &PgPool,
    user_id: i64,
    status: Option<i16>,
    limit: i64,
    offset: i64,
) -> AppResult<Vec<FriendRequestRow>> {
    let status_filter = if status.is_some() {
        "AND req.status = $2"
    } else {
        ""
    };
    let limit_index = if status.is_some() { "$3" } else { "$2" };
    let offset_index = if status.is_some() { "$4" } else { "$3" };
    let sql = format!(
        r#"
        SELECT
            {friend_request_projection}
        FROM friend_requests req
        JOIN user_profiles fp ON fp.account_id = req.from_user_id
        JOIN user_profiles tp ON tp.account_id = req.to_user_id
        WHERE req.from_user_id = $1
          AND req.from_deleted_at IS NULL
          {status_filter}
        ORDER BY req.updated_at DESC
        LIMIT {limit_index} OFFSET {offset_index}
        "#,
        friend_request_projection = friend_request_projection()
    );
    let mut query = sqlx::query_as::<_, FriendRequestRow>(&sql).bind(user_id);
    if let Some(status) = status {
        query = query.bind(status);
    }
    query
        .bind(limit)
        .bind(offset)
        .fetch_all(pool)
        .await
        .map_err(|_| AppError::internal_server_error("failed to list sent friend requests"))
}

pub async fn accept_request(pool: &PgPool, request_id: Uuid) -> AppResult<FriendRequestRow> {
    sqlx::query_as::<_, FriendRequestRow>(&friend_request_select_sql(
        r#"
        WITH updated AS (
            UPDATE friend_requests
            SET status = 1,
                updated_at = NOW(),
                handled_at = NOW()
            WHERE id = $1
            RETURNING *
        )
        SELECT
        "#,
    ))
    .bind(request_id)
    .fetch_one(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to accept friend request"))
}

pub async fn reject_request(pool: &PgPool, request_id: Uuid) -> AppResult<FriendRequestRow> {
    sqlx::query_as::<_, FriendRequestRow>(&friend_request_select_sql(
        r#"
        WITH updated AS (
            UPDATE friend_requests
            SET status = 2,
                updated_at = NOW(),
                handled_at = NOW()
            WHERE id = $1
            RETURNING *
        )
        SELECT
        "#,
    ))
    .bind(request_id)
    .fetch_one(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to reject friend request"))
}

pub async fn hide_request_for_user(
    pool: &PgPool,
    request_id: Uuid,
    user_id: i64,
) -> AppResult<bool> {
    let result = sqlx::query(
        r#"
        UPDATE friend_requests
        SET from_deleted_at = CASE WHEN from_user_id = $2 THEN NOW() ELSE from_deleted_at END,
            to_deleted_at = CASE WHEN to_user_id = $2 THEN NOW() ELSE to_deleted_at END,
            updated_at = NOW()
        WHERE id = $1
          AND status <> 0
          AND (from_user_id = $2 OR to_user_id = $2)
        "#,
    )
    .bind(request_id)
    .bind(user_id)
    .execute(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to delete friend request"))?;

    Ok(result.rows_affected() > 0)
}

pub async fn insert_friend_relations(
    pool: &PgPool,
    user_id: i64,
    friend_user_id: i64,
    request_id: Uuid,
) -> AppResult<()> {
    sqlx::query(
        r#"
        INSERT INTO friend_relations (user_id, friend_user_id, source_request_id)
        VALUES ($1, $2, $3), ($2, $1, $3)
        ON CONFLICT (user_id, friend_user_id)
        DO UPDATE SET source_request_id = EXCLUDED.source_request_id
        "#,
    )
    .bind(user_id)
    .bind(friend_user_id)
    .bind(request_id)
    .execute(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to save friend relation"))?;

    Ok(())
}

pub async fn mark_reverse_pending_accepted(
    pool: &PgPool,
    from_user_id: i64,
    to_user_id: i64,
) -> AppResult<()> {
    sqlx::query(
        r#"
        UPDATE friend_requests
        SET status = 1,
            updated_at = NOW(),
            handled_at = NOW()
        WHERE from_user_id = $1
          AND to_user_id = $2
          AND status = 0
        "#,
    )
    .bind(from_user_id)
    .bind(to_user_id)
    .execute(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to update reverse friend request"))?;

    Ok(())
}

pub async fn remove_friend_relations(
    pool: &PgPool,
    user_id: i64,
    friend_user_id: i64,
) -> AppResult<u64> {
    let result = sqlx::query(
        r#"
        DELETE FROM friend_relations
        WHERE (user_id = $1 AND friend_user_id = $2)
           OR (user_id = $2 AND friend_user_id = $1)
        "#,
    )
    .bind(user_id)
    .bind(friend_user_id)
    .execute(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to remove friend relation"))?;

    Ok(result.rows_affected())
}

pub async fn list_friends(pool: &PgPool, user_id: i64) -> AppResult<Vec<FriendUserRow>> {
    sqlx::query_as::<_, FriendUserRow>(
        r#"
        SELECT
            p.account_id,
            p.nickname,
            p.avatar_url AS avatar,
            p.signature,
            p.flash_id,
            'friend' AS relation_status,
            fr.created_at
        FROM friend_relations fr
        JOIN user_profiles p ON p.account_id = fr.friend_user_id
        WHERE fr.user_id = $1
        ORDER BY p.nickname ASC, fr.created_at DESC
        "#,
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to list friends"))
}

pub fn relation_status_priority(status: &[&str]) -> &'static str {
    if status.contains(&RELATION_FRIEND) {
        RELATION_FRIEND
    } else if status.contains(&RELATION_PENDING_SENT) {
        RELATION_PENDING_SENT
    } else if status.contains(&RELATION_PENDING_RECEIVED) {
        RELATION_PENDING_RECEIVED
    } else {
        RELATION_NONE
    }
}

fn friend_request_select_sql(prefix: &str) -> String {
    format!(
        r#"
        {prefix}
            {projection}
        FROM {source} req
        JOIN user_profiles fp ON fp.account_id = req.from_user_id
        JOIN user_profiles tp ON tp.account_id = req.to_user_id
        "#,
        projection = friend_request_projection(),
        source = if prefix.contains("upserted") {
            "upserted"
        } else if prefix.contains("updated") {
            "updated"
        } else {
            "friend_requests"
        }
    )
}

fn friend_request_projection() -> &'static str {
    r#"
            req.id,
            req.from_user_id,
            req.to_user_id,
            req.message,
            req.status,
            req.created_at,
            req.updated_at,
            req.handled_at,
            fp.nickname AS from_nickname,
            fp.avatar_url AS from_avatar,
            fp.signature AS from_signature,
            fp.flash_id AS from_flash_id,
            tp.nickname AS to_nickname,
            tp.avatar_url AS to_avatar,
            tp.signature AS to_signature,
            tp.flash_id AS to_flash_id
    "#
}

#[cfg(test)]
mod tests {
    use crate::models::{
        RELATION_FRIEND, RELATION_NONE, RELATION_PENDING_RECEIVED, RELATION_PENDING_SENT,
    };

    use super::{relation_status_case, relation_status_priority};

    #[test]
    fn relation_status_sql_has_expected_priority() {
        let sql = relation_status_case();

        assert!(sql.find("'friend'").unwrap() < sql.find("'pending_sent'").unwrap());
        assert!(sql.find("'pending_sent'").unwrap() < sql.find("'pending_received'").unwrap());
    }

    #[test]
    fn relation_status_priority_prefers_friend() {
        assert_eq!(
            relation_status_priority(&[RELATION_PENDING_SENT, RELATION_FRIEND]),
            RELATION_FRIEND
        );
        assert_eq!(
            relation_status_priority(&[RELATION_PENDING_RECEIVED]),
            RELATION_PENDING_RECEIVED
        );
        assert_eq!(relation_status_priority(&[]), RELATION_NONE);
    }
}
