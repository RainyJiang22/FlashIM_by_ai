use chrono::{DateTime, Utc};
use flash_core::{AppError, AppResult, SharedContext};
use sqlx::{Postgres, Transaction};
use std::collections::HashSet;
use uuid::Uuid;

use crate::models::{
    ConversationListItem, ConversationListQuery, CreateConversationBody, JoinedGroupSearchQuery,
};

const DEFAULT_LIMIT: i64 = 20;
const MAX_LIMIT: i64 = 100;
const DEFAULT_SEARCH_LIMIT: i64 = 20;
const MAX_SEARCH_LIMIT: i64 = 50;
const MAX_SEARCH_QUERY_CHARS: usize = 100;

pub async fn refresh_group_avatar_in_transaction(
    transaction: &mut Transaction<'_, Postgres>,
    conversation_id: Uuid,
) -> AppResult<String> {
    crate::repository::refresh_group_avatar(transaction, conversation_id).await
}

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

pub fn normalize_list_query(query: ConversationListQuery) -> AppResult<(i64, i64, Option<i16>)> {
    let conversation_type = query.r#type;
    if conversation_type.is_some_and(|value| value != 0 && value != 1) {
        return Err(AppError::bad_request("invalid conversation type"));
    }
    let (limit, offset) = normalize_pagination(query)?;
    Ok((limit, offset, conversation_type))
}

#[derive(Debug, PartialEq, Eq)]
pub struct CreateGroupInput {
    pub name: String,
    pub member_ids: Vec<i64>,
}

pub fn normalize_group_input(
    owner_id: i64,
    body: CreateConversationBody,
) -> AppResult<CreateGroupInput> {
    if body.r#type.trim() != "group" {
        return Err(AppError::bad_request("unsupported conversation type"));
    }

    let name = body.name.trim().to_string();
    if name.is_empty() || name.chars().count() > 100 {
        return Err(AppError::bad_request("invalid group name"));
    }
    if !(2..=199).contains(&body.member_ids.len()) {
        return Err(AppError::bad_request("invalid group member count"));
    }

    let mut unique_ids = HashSet::with_capacity(body.member_ids.len());
    for member_id in &body.member_ids {
        if *member_id == owner_id || !unique_ids.insert(*member_id) {
            return Err(AppError::bad_request("invalid group members"));
        }
    }

    Ok(CreateGroupInput {
        name,
        member_ids: body.member_ids,
    })
}

pub async fn list_conversations(
    context: &SharedContext,
    user_id: i64,
    query: ConversationListQuery,
) -> AppResult<Vec<ConversationListItem>> {
    let (limit, offset, conversation_type) = normalize_list_query(query)?;
    let rows = crate::repository::list_conversations_by_user(
        context.postgres.pool(),
        user_id,
        limit,
        offset,
        conversation_type,
    )
    .await?;

    Ok(rows.into_iter().map(ConversationListItem::from).collect())
}

pub async fn search_joined_groups(
    context: &SharedContext,
    user_id: i64,
    query: JoinedGroupSearchQuery,
) -> AppResult<Vec<ConversationListItem>> {
    let (like_pattern, limit) = normalize_joined_group_search(query)?;
    let rows = crate::repository::search_joined_groups(
        context.postgres.pool(),
        user_id,
        &like_pattern,
        limit,
    )
    .await?;
    Ok(rows.into_iter().map(ConversationListItem::from).collect())
}

fn normalize_joined_group_search(query: JoinedGroupSearchQuery) -> AppResult<(String, i64)> {
    let value = query.q.trim();
    if value.is_empty() || value.chars().count() > MAX_SEARCH_QUERY_CHARS {
        return Err(AppError::bad_request("invalid group search query"));
    }
    let limit = query.limit.unwrap_or(DEFAULT_SEARCH_LIMIT);
    if limit < 1 {
        return Err(AppError::bad_request("invalid limit"));
    }
    let escaped = value
        .replace('\\', "\\\\")
        .replace('%', "\\%")
        .replace('_', "\\_");
    Ok((format!("%{escaped}%"), limit.min(MAX_SEARCH_LIMIT)))
}

pub async fn create_conversation(
    context: &SharedContext,
    owner_id: i64,
    body: CreateConversationBody,
) -> AppResult<ConversationListItem> {
    let input = normalize_group_input(owner_id, body)?;
    let conversation = crate::repository::create_group_conversation(
        context.postgres.pool(),
        owner_id,
        &input.name,
        &input.member_ids,
    )
    .await?;

    Ok(ConversationListItem::from(conversation))
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

pub async fn get_private_conversation(
    context: &SharedContext,
    user_id: i64,
    peer_user_id: i64,
) -> AppResult<ConversationListItem> {
    if user_id == peer_user_id {
        return Err(AppError::bad_request("invalid private conversation peer"));
    }
    let conversation_id = crate::repository::find_private_conversation(
        context.postgres.pool(),
        user_id,
        peer_user_id,
    )
    .await?
    .ok_or(AppError::not_found("conversation not found"))?;

    get_conversation_by_id(context, user_id, conversation_id).await
}

pub async fn delete_created_group(
    context: &SharedContext,
    owner_id: i64,
    conversation_id: Uuid,
) -> AppResult<()> {
    crate::repository::delete_created_group(context.postgres.pool(), owner_id, conversation_id)
        .await
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

pub async fn hide_from_list(
    context: &SharedContext,
    user_id: i64,
    conversation_id: Uuid,
) -> AppResult<()> {
    let updated =
        crate::repository::hide_from_list(context.postgres.pool(), user_id, conversation_id)
            .await?;
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

    pub async fn can_read_history(&self, conversation_id: Uuid, user_id: i64) -> AppResult<bool> {
        crate::repository::can_read_history(self.context.postgres.pool(), conversation_id, user_id)
            .await
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

    pub async fn create_or_get_private(&self, user_a: i64, user_b: i64) -> AppResult<Uuid> {
        if user_a == user_b {
            return Err(AppError::bad_request(
                "invalid private conversation members",
            ));
        }

        let pool = self.context.postgres.pool();
        if let Some(conversation_id) =
            crate::repository::find_private_conversation(pool, user_a, user_b).await?
        {
            crate::repository::ensure_private_members(pool, conversation_id, user_a, user_b)
                .await?;
            return Ok(conversation_id);
        }

        crate::repository::create_private_conversation(pool, user_a, user_b).await
    }
}

#[cfg(test)]
mod tests {
    use std::sync::Arc;

    use flash_core::{AppConfig, AppContext};

    use crate::{
        models::{ConversationListQuery, CreateConversationBody, JoinedGroupSearchQuery},
        service::{
            normalize_group_input, normalize_joined_group_search, normalize_list_query,
            normalize_pagination,
        },
    };

    fn list_query(limit: Option<i64>, offset: Option<i64>) -> ConversationListQuery {
        ConversationListQuery {
            limit,
            offset,
            r#type: None,
        }
    }

    #[test]
    fn pagination_defaults_to_twenty() {
        let (limit, offset) =
            normalize_pagination(list_query(None, None)).expect("pagination should be valid");

        assert_eq!((limit, offset), (20, 0));
    }

    #[test]
    fn pagination_clamps_limit_to_maximum() {
        let (limit, offset) = normalize_pagination(list_query(Some(200), Some(30)))
            .expect("pagination should be valid");

        assert_eq!((limit, offset), (100, 30));
    }

    #[test]
    fn pagination_rejects_invalid_values() {
        assert!(normalize_pagination(list_query(Some(0), Some(0))).is_err());
        assert!(normalize_pagination(list_query(Some(20), Some(-1))).is_err());
    }

    #[test]
    fn list_query_accepts_private_and_group_filters() {
        for conversation_type in [0, 1] {
            let normalized = normalize_list_query(ConversationListQuery {
                limit: None,
                offset: None,
                r#type: Some(conversation_type),
            })
            .expect("conversation type should be valid");
            assert_eq!(normalized, (20, 0, Some(conversation_type)));
        }

        assert!(
            normalize_list_query(ConversationListQuery {
                limit: None,
                offset: None,
                r#type: Some(2),
            })
            .is_err()
        );
    }

    #[test]
    fn group_input_trims_name_and_keeps_member_order() {
        let input = normalize_group_input(
            1,
            CreateConversationBody {
                r#type: "group".to_string(),
                name: "  小雨、朱红  ".to_string(),
                member_ids: vec![2, 3],
            },
        )
        .expect("group input should be valid");

        assert_eq!(input.name, "小雨、朱红");
        assert_eq!(input.member_ids, vec![2, 3]);
    }

    #[test]
    fn group_input_rejects_invalid_type_name_and_members() {
        let valid = || CreateConversationBody {
            r#type: "group".to_string(),
            name: "群聊".to_string(),
            member_ids: vec![2, 3],
        };

        let mut wrong_type = valid();
        wrong_type.r#type = "private".to_string();
        assert!(normalize_group_input(1, wrong_type).is_err());

        let mut empty_name = valid();
        empty_name.name = "   ".to_string();
        assert!(normalize_group_input(1, empty_name).is_err());

        let mut long_name = valid();
        long_name.name = "群".repeat(101);
        assert!(normalize_group_input(1, long_name).is_err());

        let mut too_few = valid();
        too_few.member_ids = vec![2];
        assert!(normalize_group_input(1, too_few).is_err());

        let mut contains_owner = valid();
        contains_owner.member_ids = vec![1, 2];
        assert!(normalize_group_input(1, contains_owner).is_err());

        let mut duplicates = valid();
        duplicates.member_ids = vec![2, 2];
        assert!(normalize_group_input(1, duplicates).is_err());
    }

    #[test]
    fn group_input_accepts_maximum_invited_members() {
        let member_ids = (2..=200).collect::<Vec<_>>();
        let input = normalize_group_input(
            1,
            CreateConversationBody {
                r#type: "group".to_string(),
                name: "大群".to_string(),
                member_ids,
            },
        )
        .expect("199 invited members should be valid");

        assert_eq!(input.member_ids.len(), 199);
    }

    #[test]
    fn joined_group_search_normalizes_keyword_and_limit() {
        let (pattern, limit) = normalize_joined_group_search(JoinedGroupSearchQuery {
            q: " 研发%_\\群 ".to_string(),
            limit: Some(999),
        })
        .unwrap();

        assert_eq!(pattern, "%研发\\%\\_\\\\群%");
        assert_eq!(limit, 50);
        assert!(
            normalize_joined_group_search(JoinedGroupSearchQuery {
                q: " ".to_string(),
                limit: None,
            })
            .is_err()
        );
    }

    #[tokio::test]
    async fn group_service_round_trips_against_configured_database() {
        let Ok(config) = AppConfig::from_env() else {
            return;
        };
        let context = Arc::new(
            AppContext::from_config(config)
                .await
                .expect("configured test database should connect"),
        );
        let pool = context.postgres.pool();
        let marker = format!("{:016x}", rand_marker());
        let mut user_ids = Vec::new();
        for index in 0..4 {
            let account_id = sqlx::query_scalar::<_, i64>(
                r#"
                INSERT INTO accounts (primary_identifier)
                VALUES ($1)
                RETURNING id
                "#,
            )
            .bind(format!("group-service-test-{marker}-{index}"))
            .fetch_one(pool)
            .await
            .expect("test account should be inserted");
            sqlx::query(
                r#"
                INSERT INTO user_profiles (account_id, nickname, avatar_url)
                VALUES ($1, $2, $3)
                "#,
            )
            .bind(account_id)
            .bind(format!("群成员{index}"))
            .bind(format!("identicon:{account_id}"))
            .execute(pool)
            .await
            .expect("test profile should be inserted");
            user_ids.push(account_id);
        }

        let owner_id = user_ids[0];
        for friend_id in &user_ids[1..3] {
            sqlx::query(
                r#"
                INSERT INTO friend_relations (user_id, friend_user_id)
                VALUES ($1, $2)
                "#,
            )
            .bind(owner_id)
            .bind(friend_id)
            .execute(pool)
            .await
            .expect("test friendship should be inserted");
        }

        let created = super::create_conversation(
            &context,
            owner_id,
            CreateConversationBody {
                r#type: "group".to_string(),
                name: "服务测试群".to_string(),
                member_ids: user_ids[1..3].to_vec(),
            },
        )
        .await
        .expect("group should be created");
        assert_eq!(created.r#type, 1);
        assert_eq!(created.owner_id, Some(owner_id.to_string()));
        let expected_avatar = format!(
            "grid:identicon:{},identicon:{},identicon:{}",
            user_ids[0], user_ids[1], user_ids[2]
        );
        assert_eq!(created.avatar.as_deref(), Some(expected_avatar.as_str()));
        assert_eq!(created.member_avatars.len(), 3);

        let groups = super::list_conversations(
            &context,
            owner_id,
            ConversationListQuery {
                limit: Some(100),
                offset: Some(0),
                r#type: Some(1),
            },
        )
        .await
        .expect("group list should load");
        assert!(groups.iter().any(|item| item.id == created.id));

        sqlx::query(
            "UPDATE conversation_members SET unread_count = 3 WHERE conversation_id = $1 AND user_id = $2",
        )
        .bind(created.id)
        .bind(owner_id)
        .execute(pool)
        .await
        .expect("test unread count should be set");
        super::hide_from_list(&context, owner_id, created.id)
            .await
            .expect("conversation should be hidden from home");
        let home_conversations = super::list_conversations(
            &context,
            owner_id,
            ConversationListQuery {
                limit: Some(100),
                offset: Some(0),
                r#type: None,
            },
        )
        .await
        .expect("home conversation list should load");
        assert!(!home_conversations.iter().any(|item| item.id == created.id));
        let hidden_group = super::get_conversation_by_id(&context, owner_id, created.id)
            .await
            .expect("hidden conversation history should remain accessible");
        assert_eq!(hidden_group.id, created.id);
        let all_groups = super::list_conversations(
            &context,
            owner_id,
            ConversationListQuery {
                limit: Some(100),
                offset: Some(0),
                r#type: Some(1),
            },
        )
        .await
        .expect("group directory should include hidden home conversations");
        assert!(all_groups.iter().any(|item| item.id == created.id));
        let conversation_message_service = super::ConversationMessageService::new(&context);
        assert_eq!(
            conversation_message_service
                .get_total_unread_by_user(owner_id)
                .await
                .expect("hidden unread total should load"),
            0
        );

        sqlx::query(
            r#"
            INSERT INTO conversation_seq (conversation_id, current_seq)
            VALUES ($1, 1)
            ON CONFLICT (conversation_id)
            DO UPDATE SET current_seq = conversation_seq.current_seq + 1
            "#,
        )
        .bind(created.id)
        .execute(pool)
        .await
        .expect("new message sequence should advance");
        let still_hidden = sqlx::query_scalar::<_, bool>(
            "SELECT is_hidden FROM conversation_members WHERE conversation_id = $1 AND user_id = $2",
        )
        .bind(created.id)
        .bind(owner_id)
        .fetch_one(pool)
        .await
        .expect("hidden flag should load");
        assert!(still_hidden);
        let restored_home = super::list_conversations(
            &context,
            owner_id,
            ConversationListQuery {
                limit: Some(100),
                offset: Some(0),
                r#type: None,
            },
        )
        .await
        .expect("advanced sequence should restore the home conversation");
        assert!(restored_home.iter().any(|item| item.id == created.id));
        assert_eq!(
            conversation_message_service
                .get_total_unread_by_user(owner_id)
                .await
                .expect("restored unread total should load"),
            3
        );

        let invalid = super::create_conversation(
            &context,
            owner_id,
            CreateConversationBody {
                r#type: "group".to_string(),
                name: "包含非好友".to_string(),
                member_ids: vec![user_ids[1], user_ids[3]],
            },
        )
        .await;
        assert!(invalid.is_err());

        sqlx::query("DELETE FROM conversations WHERE id = $1")
            .bind(created.id)
            .execute(pool)
            .await
            .expect("test conversation should be cleaned up");
        sqlx::query("DELETE FROM accounts WHERE id = ANY($1)")
            .bind(&user_ids)
            .execute(pool)
            .await
            .expect("test accounts should be cleaned up");
    }

    fn rand_marker() -> u64 {
        use std::time::{SystemTime, UNIX_EPOCH};

        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos() as u64
    }
}
