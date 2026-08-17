use flash_core::{AppError, AppResult};
use sqlx::{PgPool, Postgres, Transaction};
use uuid::Uuid;

use crate::models::{GroupInvitationRow, GroupMemberRow, GroupSummaryRow};

const GROUP_NOT_FOUND: &str = "group not found";
const GROUP_OPERATION_NOT_ALLOWED: &str = "group operation is not allowed";
const INVALID_GROUP_MEMBERS: &str = "invalid group members";

pub fn group_for_member_sql() -> &'static str {
    r#"
    SELECT c.id, c.name, c.owner_id, c.join_approval_required
    FROM conversations c
    JOIN conversation_members member
      ON member.conversation_id = c.id
     AND member.user_id = $2
     AND member.is_deleted = FALSE
    WHERE c.id = $1
      AND c.type = 1
      AND c.is_dissolved = FALSE
    "#
}

pub async fn get_group_for_member(
    pool: &PgPool,
    conversation_id: Uuid,
    user_id: i64,
) -> AppResult<Option<GroupSummaryRow>> {
    sqlx::query_as::<_, GroupSummaryRow>(group_for_member_sql())
        .bind(conversation_id)
        .bind(user_id)
        .fetch_optional(pool)
        .await
        .map_err(|_| AppError::internal_server_error("failed to load group"))
}

pub async fn list_group_members(
    pool: &PgPool,
    conversation_id: Uuid,
) -> AppResult<Vec<GroupMemberRow>> {
    sqlx::query_as::<_, GroupMemberRow>(
        r#"
        SELECT
            member.user_id AS account_id,
            profile.nickname,
            profile.avatar_url AS avatar,
            member.joined_at
        FROM conversation_members member
        JOIN conversations c ON c.id = member.conversation_id
        LEFT JOIN user_profiles profile ON profile.account_id = member.user_id
        WHERE member.conversation_id = $1
          AND member.is_deleted = FALSE
          AND c.type = 1
          AND c.is_dissolved = FALSE
        ORDER BY (member.user_id = c.owner_id) DESC, member.joined_at ASC
        "#,
    )
    .bind(conversation_id)
    .fetch_all(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to list group members"))
}

pub async fn update_group_name(
    pool: &PgPool,
    conversation_id: Uuid,
    owner_id: i64,
    name: &str,
) -> AppResult<()> {
    let result = sqlx::query(
        r#"
        UPDATE conversations
        SET name = $3, updated_at = NOW()
        WHERE id = $1
          AND owner_id = $2
          AND type = 1
          AND is_dissolved = FALSE
        "#,
    )
    .bind(conversation_id)
    .bind(owner_id)
    .bind(name)
    .execute(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to update group name"))?;
    if result.rows_affected() == 0 {
        return Err(AppError::forbidden(GROUP_OPERATION_NOT_ALLOWED));
    }
    Ok(())
}

pub async fn update_group_settings(
    pool: &PgPool,
    conversation_id: Uuid,
    owner_id: i64,
    join_approval_required: bool,
) -> AppResult<()> {
    let result = sqlx::query(
        r#"
        UPDATE conversations
        SET join_approval_required = $3, updated_at = NOW()
        WHERE id = $1
          AND owner_id = $2
          AND type = 1
          AND is_dissolved = FALSE
        "#,
    )
    .bind(conversation_id)
    .bind(owner_id)
    .bind(join_approval_required)
    .execute(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to update group settings"))?;
    if result.rows_affected() == 0 {
        return Err(AppError::forbidden(GROUP_OPERATION_NOT_ALLOWED));
    }
    Ok(())
}

async fn lock_group_for_actor(
    transaction: &mut Transaction<'_, Postgres>,
    conversation_id: Uuid,
    actor_id: i64,
) -> AppResult<GroupSummaryRow> {
    sqlx::query_as::<_, GroupSummaryRow>(
        r#"
        SELECT c.id, c.name, c.owner_id, c.join_approval_required
        FROM conversations c
        JOIN conversation_members actor
          ON actor.conversation_id = c.id
         AND actor.user_id = $2
         AND actor.is_deleted = FALSE
        WHERE c.id = $1
          AND c.type = 1
          AND c.is_dissolved = FALSE
        FOR UPDATE OF c
        "#,
    )
    .bind(conversation_id)
    .bind(actor_id)
    .fetch_optional(&mut **transaction)
    .await
    .map_err(|_| AppError::internal_server_error("failed to lock group"))?
    .ok_or(AppError::not_found(GROUP_NOT_FOUND))
}

async fn validate_actor_friends(
    transaction: &mut Transaction<'_, Postgres>,
    actor_id: i64,
    member_ids: &[i64],
) -> AppResult<()> {
    let friend_count = sqlx::query_scalar::<_, i64>(
        r#"
        SELECT COUNT(*)::BIGINT
        FROM friend_relations
        WHERE user_id = $1
          AND friend_user_id = ANY($2)
        "#,
    )
    .bind(actor_id)
    .bind(member_ids)
    .fetch_one(&mut **transaction)
    .await
    .map_err(|_| AppError::internal_server_error("failed to verify group friends"))?;
    if friend_count != member_ids.len() as i64 {
        return Err(AppError::bad_request(INVALID_GROUP_MEMBERS));
    }
    Ok(())
}

async fn active_member_count(
    transaction: &mut Transaction<'_, Postgres>,
    conversation_id: Uuid,
) -> AppResult<i64> {
    sqlx::query_scalar::<_, i64>(
        r#"
        SELECT COUNT(*)::BIGINT
        FROM conversation_members
        WHERE conversation_id = $1
          AND is_deleted = FALSE
        "#,
    )
    .bind(conversation_id)
    .fetch_one(&mut **transaction)
    .await
    .map_err(|_| AppError::internal_server_error("failed to count group members"))
}

async fn ensure_targets_are_not_members(
    transaction: &mut Transaction<'_, Postgres>,
    conversation_id: Uuid,
    member_ids: &[i64],
) -> AppResult<()> {
    let existing_count = sqlx::query_scalar::<_, i64>(
        r#"
        SELECT COUNT(*)::BIGINT
        FROM conversation_members
        WHERE conversation_id = $1
          AND user_id = ANY($2)
          AND is_deleted = FALSE
        "#,
    )
    .bind(conversation_id)
    .bind(member_ids)
    .fetch_one(&mut **transaction)
    .await
    .map_err(|_| AppError::internal_server_error("failed to verify existing group members"))?;
    if existing_count != 0 {
        return Err(AppError::conflict("group member already exists"));
    }
    Ok(())
}

pub async fn add_group_members(
    pool: &PgPool,
    conversation_id: Uuid,
    actor_id: i64,
    member_ids: &[i64],
) -> AppResult<()> {
    let mut transaction = pool
        .begin()
        .await
        .map_err(|_| AppError::internal_server_error("failed to start member transaction"))?;
    let group = lock_group_for_actor(&mut transaction, conversation_id, actor_id).await?;
    if actor_id != group.owner_id && group.join_approval_required {
        return Err(AppError::forbidden(GROUP_OPERATION_NOT_ALLOWED));
    }
    validate_actor_friends(&mut transaction, actor_id, member_ids).await?;
    ensure_targets_are_not_members(&mut transaction, conversation_id, member_ids).await?;
    let member_count = active_member_count(&mut transaction, conversation_id).await?;
    if member_count + member_ids.len() as i64 > 200 {
        return Err(AppError::conflict("group member limit reached"));
    }

    sqlx::query(
        r#"
        INSERT INTO conversation_members (
            conversation_id, user_id, unread_count, last_read_seq, is_deleted, joined_at
        )
        SELECT $1, member_id, 0, 0, FALSE, NOW()
        FROM UNNEST($2::BIGINT[]) AS member_id
        ON CONFLICT (conversation_id, user_id)
        DO UPDATE SET
            unread_count = 0,
            last_read_seq = 0,
            is_deleted = FALSE,
            joined_at = NOW()
        "#,
    )
    .bind(conversation_id)
    .bind(member_ids)
    .execute(&mut *transaction)
    .await
    .map_err(|_| AppError::internal_server_error("failed to add group members"))?;

    transaction
        .commit()
        .await
        .map_err(|_| AppError::internal_server_error("failed to commit member transaction"))
}

pub async fn remove_group_member(
    pool: &PgPool,
    conversation_id: Uuid,
    owner_id: i64,
    member_id: i64,
) -> AppResult<()> {
    let mut transaction = pool
        .begin()
        .await
        .map_err(|_| AppError::internal_server_error("failed to start member transaction"))?;
    let group = lock_group_for_actor(&mut transaction, conversation_id, owner_id).await?;
    if group.owner_id != owner_id {
        return Err(AppError::forbidden(GROUP_OPERATION_NOT_ALLOWED));
    }
    if member_id == group.owner_id {
        return Err(AppError::bad_request("group owner cannot be removed"));
    }
    let result = sqlx::query(
        r#"
        UPDATE conversation_members
        SET is_deleted = TRUE, unread_count = 0
        WHERE conversation_id = $1
          AND user_id = $2
          AND is_deleted = FALSE
        "#,
    )
    .bind(conversation_id)
    .bind(member_id)
    .execute(&mut *transaction)
    .await
    .map_err(|_| AppError::internal_server_error("failed to remove group member"))?;
    if result.rows_affected() == 0 {
        return Err(AppError::not_found("group member not found"));
    }
    transaction
        .commit()
        .await
        .map_err(|_| AppError::internal_server_error("failed to commit member transaction"))
}

pub struct InvitationCreation {
    pub invitation: GroupInvitationRow,
    pub is_new: bool,
}

pub async fn create_group_invitations(
    pool: &PgPool,
    conversation_id: Uuid,
    inviter_id: i64,
    invitee_ids: &[i64],
) -> AppResult<Vec<InvitationCreation>> {
    let mut transaction = pool
        .begin()
        .await
        .map_err(|_| AppError::internal_server_error("failed to start invitation transaction"))?;
    let group = lock_group_for_actor(&mut transaction, conversation_id, inviter_id).await?;
    if inviter_id == group.owner_id || !group.join_approval_required {
        return Err(AppError::forbidden(GROUP_OPERATION_NOT_ALLOWED));
    }
    validate_actor_friends(&mut transaction, inviter_id, invitee_ids).await?;
    ensure_targets_are_not_members(&mut transaction, conversation_id, invitee_ids).await?;
    let member_count = active_member_count(&mut transaction, conversation_id).await?;
    if member_count + invitee_ids.len() as i64 > 200 {
        return Err(AppError::conflict("group member limit reached"));
    }

    let mut creations = Vec::with_capacity(invitee_ids.len());
    for invitee_id in invitee_ids {
        let inserted = sqlx::query_as::<_, GroupInvitationRow>(
            r#"
            INSERT INTO group_invitations (conversation_id, inviter_id, invitee_id)
            VALUES ($1, $2, $3)
            ON CONFLICT (conversation_id, invitee_id) WHERE status = 0
            DO NOTHING
            RETURNING id, conversation_id, inviter_id, invitee_id, status
            "#,
        )
        .bind(conversation_id)
        .bind(inviter_id)
        .bind(invitee_id)
        .fetch_optional(&mut *transaction)
        .await
        .map_err(|_| AppError::internal_server_error("failed to create group invitation"))?;

        let (invitation, is_new) = match inserted {
            Some(invitation) => (invitation, true),
            None => {
                let existing = sqlx::query_as::<_, GroupInvitationRow>(
                    r#"
                    SELECT id, conversation_id, inviter_id, invitee_id, status
                    FROM group_invitations
                    WHERE conversation_id = $1
                      AND invitee_id = $2
                      AND status = 0
                    "#,
                )
                .bind(conversation_id)
                .bind(invitee_id)
                .fetch_one(&mut *transaction)
                .await
                .map_err(|_| AppError::internal_server_error("failed to load group invitation"))?;
                (existing, false)
            }
        };
        creations.push(InvitationCreation { invitation, is_new });
    }
    transaction
        .commit()
        .await
        .map_err(|_| AppError::internal_server_error("failed to commit invitation transaction"))?;
    Ok(creations)
}

pub async fn delete_pending_invitation(
    pool: &PgPool,
    invitation_id: Uuid,
    inviter_id: i64,
) -> AppResult<()> {
    sqlx::query("DELETE FROM group_invitations WHERE id = $1 AND inviter_id = $2 AND status = 0")
        .bind(invitation_id)
        .bind(inviter_id)
        .execute(pool)
        .await
        .map_err(|_| AppError::internal_server_error("failed to remove undelivered invitation"))?;
    Ok(())
}

pub async fn accept_group_invitation(
    pool: &PgPool,
    invitation_id: Uuid,
    invitee_id: i64,
) -> AppResult<Uuid> {
    let mut transaction = pool
        .begin()
        .await
        .map_err(|_| AppError::internal_server_error("failed to start invitation transaction"))?;
    let initial_invitation = sqlx::query_as::<_, GroupInvitationRow>(
        r#"
        SELECT id, conversation_id, inviter_id, invitee_id, status
        FROM group_invitations
        WHERE id = $1 AND invitee_id = $2
        "#,
    )
    .bind(invitation_id)
    .bind(invitee_id)
    .fetch_optional(&mut *transaction)
    .await
    .map_err(|_| AppError::internal_server_error("failed to load group invitation"))?
    .ok_or(AppError::not_found("group invitation not found"))?;

    let active_group = sqlx::query_scalar::<_, Uuid>(
        r#"
        SELECT id
        FROM conversations
        WHERE id = $1 AND type = 1 AND is_dissolved = FALSE
        FOR UPDATE
        "#,
    )
    .bind(initial_invitation.conversation_id)
    .fetch_optional(&mut *transaction)
    .await
    .map_err(|_| AppError::internal_server_error("failed to verify group invitation"))?;
    if active_group.is_none() {
        return Err(AppError::not_found(GROUP_NOT_FOUND));
    }

    let invitation = sqlx::query_as::<_, GroupInvitationRow>(
        r#"
        SELECT id, conversation_id, inviter_id, invitee_id, status
        FROM group_invitations
        WHERE id = $1 AND invitee_id = $2 AND conversation_id = $3
        FOR UPDATE
        "#,
    )
    .bind(invitation_id)
    .bind(invitee_id)
    .bind(initial_invitation.conversation_id)
    .fetch_optional(&mut *transaction)
    .await
    .map_err(|_| AppError::internal_server_error("failed to lock group invitation"))?
    .ok_or(AppError::not_found("group invitation not found"))?;
    if invitation.status == 1 {
        transaction.commit().await.map_err(|_| {
            AppError::internal_server_error("failed to commit invitation transaction")
        })?;
        return Ok(invitation.conversation_id);
    }

    let inviter_is_member = sqlx::query_scalar::<_, bool>(
        r#"
        SELECT EXISTS(
            SELECT 1 FROM conversation_members
            WHERE conversation_id = $1 AND user_id = $2 AND is_deleted = FALSE
        )
        "#,
    )
    .bind(invitation.conversation_id)
    .bind(invitation.inviter_id)
    .fetch_one(&mut *transaction)
    .await
    .map_err(|_| AppError::internal_server_error("failed to verify group inviter"))?;
    if !inviter_is_member {
        return Err(AppError::conflict("group invitation is no longer valid"));
    }
    let member_count = active_member_count(&mut transaction, invitation.conversation_id).await?;
    if member_count >= 200 {
        return Err(AppError::conflict("group member limit reached"));
    }

    sqlx::query(
        r#"
        INSERT INTO conversation_members (
            conversation_id, user_id, unread_count, last_read_seq, is_deleted, joined_at
        ) VALUES ($1, $2, 0, 0, FALSE, NOW())
        ON CONFLICT (conversation_id, user_id)
        DO UPDATE SET unread_count = 0, last_read_seq = 0, is_deleted = FALSE, joined_at = NOW()
        "#,
    )
    .bind(invitation.conversation_id)
    .bind(invitee_id)
    .execute(&mut *transaction)
    .await
    .map_err(|_| AppError::internal_server_error("failed to accept group invitation"))?;
    sqlx::query(
        "UPDATE group_invitations SET status = 1, handled_at = NOW() WHERE id = $1 AND status = 0",
    )
    .bind(invitation_id)
    .execute(&mut *transaction)
    .await
    .map_err(|_| AppError::internal_server_error("failed to update group invitation"))?;
    transaction
        .commit()
        .await
        .map_err(|_| AppError::internal_server_error("failed to commit invitation transaction"))?;
    Ok(invitation.conversation_id)
}

pub async fn dissolve_group(pool: &PgPool, conversation_id: Uuid, owner_id: i64) -> AppResult<()> {
    let mut transaction = pool
        .begin()
        .await
        .map_err(|_| AppError::internal_server_error("failed to start dissolve transaction"))?;
    let group = lock_group_for_actor(&mut transaction, conversation_id, owner_id).await?;
    if group.owner_id != owner_id {
        return Err(AppError::forbidden(GROUP_OPERATION_NOT_ALLOWED));
    }
    sqlx::query(
        r#"
        UPDATE conversations
        SET is_dissolved = TRUE, dissolved_at = NOW(), updated_at = NOW()
        WHERE id = $1 AND is_dissolved = FALSE
        "#,
    )
    .bind(conversation_id)
    .execute(&mut *transaction)
    .await
    .map_err(|_| AppError::internal_server_error("failed to dissolve group"))?;
    sqlx::query(
        "UPDATE conversation_members SET is_deleted = TRUE, unread_count = 0 WHERE conversation_id = $1",
    )
    .bind(conversation_id)
    .execute(&mut *transaction)
    .await
    .map_err(|_| AppError::internal_server_error("failed to remove dissolved group members"))?;
    sqlx::query("DELETE FROM group_invitations WHERE conversation_id = $1 AND status = 0")
        .bind(conversation_id)
        .execute(&mut *transaction)
        .await
        .map_err(|_| AppError::internal_server_error("failed to invalidate group invitations"))?;
    transaction
        .commit()
        .await
        .map_err(|_| AppError::internal_server_error("failed to commit dissolve transaction"))
}

#[cfg(test)]
mod tests {
    use super::group_for_member_sql;

    #[test]
    fn group_queries_require_active_membership_and_active_group() {
        let sql = group_for_member_sql();
        assert!(sql.contains("member.is_deleted = FALSE"));
        assert!(sql.contains("c.type = 1"));
        assert!(sql.contains("c.is_dissolved = FALSE"));
    }
}
