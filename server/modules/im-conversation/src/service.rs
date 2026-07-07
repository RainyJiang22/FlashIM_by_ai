use flash_core::{AppError, AppResult, SharedContext};

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
