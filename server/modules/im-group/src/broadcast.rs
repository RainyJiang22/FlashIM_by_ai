use async_trait::async_trait;
use chrono::{DateTime, Utc};
use flash_core::AppResult;
use im_message::{
    broadcast::MessageBroadcaster,
    service::{ConversationUpdate, MessagePayload},
};
use uuid::Uuid;

#[derive(Clone, Debug)]
pub struct GroupJoinRequestPayload {
    pub request_id: Uuid,
    pub conversation_id: Uuid,
    pub group_name: String,
    pub group_avatar: String,
    pub applicant_id: i64,
    pub applicant_name: String,
    pub applicant_avatar: String,
    pub message: String,
    pub status: i16,
    pub created_at: DateTime<Utc>,
    pub handled_at: Option<DateTime<Utc>>,
}

#[async_trait]
pub trait GroupBroadcaster: Send + Sync {
    async fn broadcast_group_join_request(
        &self,
        to_user_id: i64,
        event: GroupJoinRequestPayload,
    ) -> AppResult<()>;
}

#[derive(Clone, Default)]
pub struct NoopGroupBroadcaster;

#[async_trait]
impl GroupBroadcaster for NoopGroupBroadcaster {
    async fn broadcast_group_join_request(
        &self,
        _to_user_id: i64,
        _event: GroupJoinRequestPayload,
    ) -> AppResult<()> {
        Ok(())
    }
}

#[async_trait]
impl MessageBroadcaster for NoopGroupBroadcaster {
    async fn broadcast_message(
        &self,
        _message: MessagePayload,
        _member_ids: &[i64],
        _exclude_sender: Option<i64>,
    ) -> AppResult<()> {
        Ok(())
    }

    async fn broadcast_conversation_updates(
        &self,
        _updates: Vec<ConversationUpdate>,
        _member_ids: &[i64],
    ) -> AppResult<()> {
        Ok(())
    }
}
