use std::sync::Arc;

use chrono::{DateTime, Utc};
use flash_core::{AppError, AppResult, SharedContext};
use im_conversation::service::ConversationMessageService;
use serde_json::Value;
use uuid::Uuid;

use crate::{
    broadcast::MessageBroadcaster,
    models::{MessageQuery, MessageRow, MessageWithSender, NewMessage},
    repository,
    seq::SeqGenerator,
};

const DEFAULT_LIMIT: i64 = 50;
const MAX_LIMIT: i64 = 100;
const DEFAULT_BEFORE_SEQ: i64 = i64::MAX;

#[derive(Clone, Debug)]
pub struct SendMessageInput {
    pub conversation_id: Uuid,
    pub sender_id: i64,
    pub msg_type: i16,
    pub content: String,
    pub extra: Option<Value>,
}

#[derive(Clone, Debug)]
pub struct MessagePayload {
    pub id: Uuid,
    pub conversation_id: Uuid,
    pub sender_id: i64,
    pub seq: i64,
    pub msg_type: i16,
    pub content: String,
    pub extra: Option<Value>,
    pub status: i16,
    pub created_at: DateTime<Utc>,
}

impl From<MessageRow> for MessagePayload {
    fn from(row: MessageRow) -> Self {
        Self {
            id: row.id,
            conversation_id: row.conversation_id,
            sender_id: row.sender_id,
            seq: row.seq,
            msg_type: row.r#type,
            content: row.content,
            extra: row.extra,
            status: row.status,
            created_at: row.created_at,
        }
    }
}

#[derive(Clone, Debug)]
pub struct MessageAck {
    pub message_id: Uuid,
    pub seq: i64,
}

#[derive(Clone, Debug)]
pub struct ConversationUpdate {
    pub conversation_id: Uuid,
    pub user_id: i64,
    pub last_message_preview: String,
    pub last_message_at: DateTime<Utc>,
    pub unread_count: i32,
}

#[derive(Clone, Debug)]
pub struct SendMessageOutput {
    pub message: MessagePayload,
    pub ack: MessageAck,
    pub conversation_updates: Vec<ConversationUpdate>,
}

#[derive(Clone)]
pub struct MessageService<B> {
    broadcaster: Arc<B>,
}

impl<B> MessageService<B>
where
    B: MessageBroadcaster,
{
    pub fn new(broadcaster: Arc<B>) -> Self {
        Self { broadcaster }
    }

    pub async fn send(
        &self,
        context: &SharedContext,
        input: SendMessageInput,
    ) -> AppResult<SendMessageOutput> {
        if input.content.trim().is_empty() {
            return Err(AppError::bad_request("message content is empty"));
        }

        if input.msg_type != 0 {
            return Err(AppError::bad_request("unsupported message type"));
        }

        let pool = context.postgres.pool();
        let conversation_service = ConversationMessageService::new(context);
        if !conversation_service
            .is_member(input.conversation_id, input.sender_id)
            .await?
        {
            return Err(AppError::not_found("conversation not found"));
        }

        let seq = SeqGenerator::next_seq(pool, input.conversation_id).await?;
        let message = repository::insert_message(
            pool,
            NewMessage {
                conversation_id: input.conversation_id,
                sender_id: input.sender_id,
                seq,
                r#type: input.msg_type,
                content: input.content,
                extra: input.extra,
            },
        )
        .await?;
        let payload = MessagePayload::from(message);
        let preview = build_preview(&payload.content);

        conversation_service
            .update_last_message(payload.conversation_id, &preview, payload.created_at)
            .await?;
        conversation_service
            .increment_unread(payload.conversation_id, payload.sender_id)
            .await?;

        let member_ids = conversation_service
            .get_member_ids(payload.conversation_id)
            .await?;
        let unread_counts = conversation_service
            .get_unread_counts(payload.conversation_id, &member_ids)
            .await?;
        let updates = unread_counts
            .into_iter()
            .map(|(user_id, unread_count)| ConversationUpdate {
                conversation_id: payload.conversation_id,
                user_id,
                last_message_preview: preview.clone(),
                last_message_at: payload.created_at,
                unread_count,
            })
            .collect::<Vec<_>>();

        self.broadcaster
            .broadcast_message(payload.clone(), &member_ids, Some(payload.sender_id))
            .await?;
        self.broadcaster
            .broadcast_conversation_updates(updates.clone(), &member_ids)
            .await?;

        Ok(SendMessageOutput {
            ack: MessageAck {
                message_id: payload.id,
                seq: payload.seq,
            },
            message: payload,
            conversation_updates: updates,
        })
    }

    pub async fn get_history(
        &self,
        context: &SharedContext,
        user_id: i64,
        conversation_id: Uuid,
        query: MessageQuery,
    ) -> AppResult<Vec<MessageWithSender>> {
        let (before_seq, limit) = normalize_history_query(query)?;
        let conversation_service = ConversationMessageService::new(context);
        if !conversation_service
            .is_member(conversation_id, user_id)
            .await?
        {
            return Err(AppError::not_found("conversation not found"));
        }

        let rows =
            repository::find_before(context.postgres.pool(), conversation_id, before_seq, limit)
                .await?;

        Ok(rows.into_iter().map(MessageWithSender::from).collect())
    }
}

pub fn normalize_history_query(query: MessageQuery) -> AppResult<(i64, i64)> {
    let before_seq = query.before_seq.unwrap_or(DEFAULT_BEFORE_SEQ);
    if before_seq < 1 {
        return Err(AppError::bad_request("invalid before_seq"));
    }

    let limit = query.limit.unwrap_or(DEFAULT_LIMIT);
    if limit < 1 {
        return Err(AppError::bad_request("invalid limit"));
    }

    Ok((before_seq, limit.min(MAX_LIMIT)))
}

fn build_preview(content: &str) -> String {
    content.chars().take(100).collect()
}

#[cfg(test)]
mod tests {
    use crate::{models::MessageQuery, service::normalize_history_query};

    #[test]
    fn history_query_defaults_and_clamps_limit() {
        let (before_seq, limit) = normalize_history_query(MessageQuery {
            before_seq: None,
            limit: Some(300),
        })
        .expect("query should be valid");

        assert_eq!(before_seq, i64::MAX);
        assert_eq!(limit, 100);
    }

    #[test]
    fn history_query_rejects_invalid_values() {
        assert!(
            normalize_history_query(MessageQuery {
                before_seq: Some(0),
                limit: Some(20),
            })
            .is_err()
        );
        assert!(
            normalize_history_query(MessageQuery {
                before_seq: Some(10),
                limit: Some(0),
            })
            .is_err()
        );
    }
}
