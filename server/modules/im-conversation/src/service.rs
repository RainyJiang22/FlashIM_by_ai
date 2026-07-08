use chrono::{DateTime, Utc};
use flash_core::{AppError, AppResult, SharedContext};
use uuid::Uuid;

use crate::models::{ConversationListItem, ConversationListQuery};

const DEFAULT_LIMIT: i64 = 20;
const MAX_LIMIT: i64 = 100;

pub fn normalize_pagination(query: ConversationListQuery) -> AppResult<(i64, i64)> {
    let limit = query.limit.unwrap_or(DEFAULT_LIMIT);
    if limit < 1 {
        return Err(AppError::bad_request("invalid limit"));
    }

    let offset = query.offset.unwrap_or(0);
    if offset < 0 {
        return Err(AppError::bad_request("invalid offset"));
    }

    Ok((limit.min(MAX_LIMIT), offset))
}

pub async fn list_conversations(
    context: &SharedContext,
    user_id: i64,
    query: ConversationListQuery,
) -> AppResult<Vec<ConversationListItem>> {
    let (limit, offset) = normalize_pagination(query)?;
    let rows = crate::repository::list_conversations_by_user(
        context.postgres.pool(),
        user_id,
        limit,
        offset,
    )
    .await?;

    Ok(rows.into_iter().map(ConversationListItem::from).collect())
}

pub async fn get_conversation_by_id(
    context: &SharedContext,
    user_id: i64,
    conversation_id: Uuid,
) -> AppResult<ConversationListItem> {
    let row = crate::repository::get_conversation_by_id(
        context.postgres.pool(),
        user_id,
        conversation_id,
    )
    .await?
    .ok_or(AppError::not_found("conversation not found"))?;

    Ok(ConversationListItem::from(row))
}

pub async fn mark_read(
    context: &SharedContext,
    user_id: i64,
    conversation_id: Uuid,
) -> AppResult<()> {
    let updated =
        crate::repository::mark_read(context.postgres.pool(), user_id, conversation_id).await?;
    if !updated {
        return Err(AppError::not_found("conversation not found"));
    }

    Ok(())
}

pub struct ConversationMessageService<'a> {
    context: &'a SharedContext,
}

impl<'a> ConversationMessageService<'a> {
    pub fn new(context: &'a SharedContext) -> Self {
        Self { context }
    }

    pub async fn is_member(&self, conversation_id: Uuid, user_id: i64) -> AppResult<bool> {
        crate::repository::is_member(self.context.postgres.pool(), conversation_id, user_id).await
    }

    pub async fn get_member_ids(&self, conversation_id: Uuid) -> AppResult<Vec<i64>> {
        crate::repository::get_member_ids(self.context.postgres.pool(), conversation_id).await
    }

    pub async fn update_last_message(
        &self,
        conversation_id: Uuid,
        preview: &str,
        last_message_at: DateTime<Utc>,
    ) -> AppResult<()> {
        crate::repository::update_last_message(
            self.context.postgres.pool(),
            conversation_id,
            preview,
            last_message_at,
        )
        .await
    }

    pub async fn increment_unread(&self, conversation_id: Uuid, sender_id: i64) -> AppResult<()> {
        crate::repository::increment_unread(
            self.context.postgres.pool(),
            conversation_id,
            sender_id,
        )
        .await
    }

    pub async fn get_unread_counts(
        &self,
        conversation_id: Uuid,
        member_ids: &[i64],
    ) -> AppResult<Vec<(i64, i32)>> {
        crate::repository::get_unread_counts(
            self.context.postgres.pool(),
            conversation_id,
            member_ids,
        )
        .await
    }

    pub async fn get_total_unread_by_user(&self, user_id: i64) -> AppResult<i32> {
        crate::repository::get_total_unread_by_user(self.context.postgres.pool(), user_id).await
    }
}

#[cfg(test)]
mod tests {
    use crate::{models::ConversationListQuery, service::normalize_pagination};

    #[test]
    fn pagination_defaults_to_twenty() {
        let (limit, offset) = normalize_pagination(ConversationListQuery {
            limit: None,
            offset: None,
        })
        .expect("pagination should be valid");

        assert_eq!((limit, offset), (20, 0));
    }

    #[test]
    fn pagination_clamps_limit_to_maximum() {
        let (limit, offset) = normalize_pagination(ConversationListQuery {
            limit: Some(200),
            offset: Some(30),
        })
        .expect("pagination should be valid");

        assert_eq!((limit, offset), (100, 30));
    }

    #[test]
    fn pagination_rejects_invalid_values() {
        assert!(
            normalize_pagination(ConversationListQuery {
                limit: Some(0),
                offset: Some(0),
            })
            .is_err()
        );
        assert!(
            normalize_pagination(ConversationListQuery {
                limit: Some(20),
                offset: Some(-1),
            })
            .is_err()
        );
    }
}
