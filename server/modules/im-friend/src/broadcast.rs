use async_trait::async_trait;
use chrono::{DateTime, Utc};
use flash_core::AppResult;
use im_message::{
    broadcast::MessageBroadcaster,
    service::{ConversationUpdate, MessagePayload},
};
use uuid::Uuid;

#[derive(Clone, Debug)]
pub struct FriendUserPayload {
    pub account_id: i64,
    pub nickname: String,
    pub avatar: String,
    pub signature: String,
    pub flash_id: Option<String>,
}

#[derive(Clone, Debug)]
pub struct FriendRequestPayload {
    pub request_id: Uuid,
    pub from_user: FriendUserPayload,
    pub message: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Clone, Debug)]
pub struct FriendAcceptedPayload {
    pub request_id: Uuid,
    pub friend: FriendUserPayload,
    pub conversation_id: Uuid,
    pub accepted_at: DateTime<Utc>,
}

#[derive(Clone, Debug)]
pub struct FriendRemovedPayload {
    pub friend: FriendUserPayload,
    pub removed_at: DateTime<Utc>,
}

#[async_trait]
pub trait FriendBroadcaster: Send + Sync {
    async fn broadcast_friend_request(
        &self,
        to_user_id: i64,
        event: FriendRequestPayload,
    ) -> AppResult<()>;

    async fn broadcast_friend_accepted(
        &self,
        to_user_id: i64,
        event: FriendAcceptedPayload,
    ) -> AppResult<()>;

    async fn broadcast_friend_removed(
        &self,
        to_user_id: i64,
        event: FriendRemovedPayload,
    ) -> AppResult<()>;

    async fn broadcast_friend_presence(
        &self,
        to_user_id: i64,
        friend_user_id: i64,
        is_friend: bool,
    ) -> AppResult<()>;
}

#[derive(Clone, Default)]
pub struct NoopFriendBroadcaster;

#[async_trait]
impl FriendBroadcaster for NoopFriendBroadcaster {
    async fn broadcast_friend_request(
        &self,
        _to_user_id: i64,
        _event: FriendRequestPayload,
    ) -> AppResult<()> {
        Ok(())
    }

    async fn broadcast_friend_accepted(
        &self,
        _to_user_id: i64,
        _event: FriendAcceptedPayload,
    ) -> AppResult<()> {
        Ok(())
    }

    async fn broadcast_friend_removed(
        &self,
        _to_user_id: i64,
        _event: FriendRemovedPayload,
    ) -> AppResult<()> {
        Ok(())
    }

    async fn broadcast_friend_presence(
        &self,
        _to_user_id: i64,
        _friend_user_id: i64,
        _is_friend: bool,
    ) -> AppResult<()> {
        Ok(())
    }
}

#[async_trait]
impl MessageBroadcaster for NoopFriendBroadcaster {
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
