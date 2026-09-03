use async_trait::async_trait;
use flash_core::AppResult;

use crate::service::{ConversationUpdate, MessagePayload, ReadReceiptPayload};

#[async_trait]
pub trait MessageBroadcaster: Send + Sync {
    async fn broadcast_message(
        &self,
        message: MessagePayload,
        member_ids: &[i64],
        exclude_sender: Option<i64>,
    ) -> AppResult<()>;

    async fn broadcast_conversation_updates(
        &self,
        updates: Vec<ConversationUpdate>,
        member_ids: &[i64],
    ) -> AppResult<()>;

    async fn broadcast_read_receipt(
        &self,
        _receipt: ReadReceiptPayload,
        _member_ids: &[i64],
    ) -> AppResult<()> {
        Ok(())
    }
}

#[derive(Clone, Default)]
pub struct NoopBroadcaster;

#[async_trait]
impl MessageBroadcaster for NoopBroadcaster {
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
