use async_trait::async_trait;
use flash_core::{AppError, AppResult};
use im_message::{
    broadcast::MessageBroadcaster,
    service::{ConversationUpdate as DomainConversationUpdate, MessagePayload},
};
use sqlx::PgPool;

use crate::{
    frame::{chat_message_frame, conversation_update_frame},
    proto::{ChatMessage, ConversationUpdate},
    state::WsState,
};

#[derive(Clone)]
pub struct WsBroadcaster {
    state: WsState,
    pool: PgPool,
}

impl WsBroadcaster {
    pub fn new(state: WsState, pool: PgPool) -> Self {
        Self { state, pool }
    }
}

#[async_trait]
impl MessageBroadcaster for WsBroadcaster {
    async fn broadcast_message(
        &self,
        message: MessagePayload,
        member_ids: &[i64],
        exclude_sender: Option<i64>,
    ) -> AppResult<()> {
        let frame = chat_message_frame(to_proto_message(&self.pool, message).await?);
        for member_id in member_ids {
            if Some(*member_id) == exclude_sender {
                continue;
            }
            self.state.send_to_user(*member_id, frame.clone());
        }

        Ok(())
    }

    async fn broadcast_conversation_updates(
        &self,
        updates: Vec<DomainConversationUpdate>,
        _member_ids: &[i64],
    ) -> AppResult<()> {
        for update in updates {
            let user_id = update.user_id;
            let frame = conversation_update_frame(to_proto_update(&self.pool, update).await?);
            self.state.send_to_user(user_id, frame);
        }

        Ok(())
    }
}

#[derive(sqlx::FromRow)]
struct SenderProfile {
    nickname: Option<String>,
    avatar_url: Option<String>,
}

async fn load_sender_profile(pool: &PgPool, sender_id: i64) -> AppResult<Option<SenderProfile>> {
    sqlx::query_as::<_, SenderProfile>(
        r#"
        SELECT nickname, avatar_url
        FROM user_profiles
        WHERE account_id = $1
        "#,
    )
    .bind(sender_id)
    .fetch_optional(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to load sender profile"))
}

async fn load_total_unread(pool: &PgPool, user_id: i64) -> AppResult<i32> {
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

async fn to_proto_message(pool: &PgPool, message: MessagePayload) -> AppResult<ChatMessage> {
    let sender_profile = load_sender_profile(pool, message.sender_id).await?;

    Ok(ChatMessage {
        id: message.id.to_string(),
        conversation_id: message.conversation_id.to_string(),
        sender_id: message.sender_id,
        seq: message.seq,
        r#type: message.msg_type as i32,
        content: message.content,
        extra: message
            .extra
            .map(|value| value.to_string())
            .unwrap_or_default(),
        status: message.status as i32,
        created_at: message.created_at.to_rfc3339(),
        sender_name: sender_profile
            .as_ref()
            .and_then(|profile| profile.nickname.clone())
            .unwrap_or_default(),
        sender_avatar: sender_profile
            .and_then(|profile| profile.avatar_url)
            .unwrap_or_default(),
    })
}

async fn to_proto_update(
    pool: &PgPool,
    update: DomainConversationUpdate,
) -> AppResult<ConversationUpdate> {
    let total_unread = load_total_unread(pool, update.user_id).await?;

    Ok(ConversationUpdate {
        conversation_id: update.conversation_id.to_string(),
        last_message_preview: update.last_message_preview,
        last_message_at: update.last_message_at.to_rfc3339(),
        unread_count: update.unread_count,
        total_unread,
    })
}

#[cfg(test)]
mod tests {
    use crate::proto::{ChatMessage, ConversationUpdate};

    #[test]
    fn proto_message_keeps_sender_profile_fields() {
        let message = ChatMessage {
            id: "00000000-0000-0000-0000-000000000001".to_string(),
            conversation_id: "00000000-0000-0000-0000-000000000002".to_string(),
            sender_id: 2,
            seq: 1,
            r#type: 0,
            content: "hello".to_string(),
            extra: String::new(),
            status: 0,
            created_at: "2026-04-03T00:00:00Z".to_string(),
            sender_name: "朱红".to_string(),
            sender_avatar: "identicon:2".to_string(),
        };

        assert_eq!(message.sender_name, "朱红");
        assert_eq!(message.sender_avatar, "identicon:2");
    }

    #[test]
    fn proto_update_keeps_total_unread_field() {
        let update = ConversationUpdate {
            conversation_id: "00000000-0000-0000-0000-000000000001".to_string(),
            last_message_preview: "hello".to_string(),
            last_message_at: "2026-04-03T00:00:00Z".to_string(),
            unread_count: 1,
            total_unread: 9,
        };

        assert_eq!(update.total_unread, 9);
    }
}
