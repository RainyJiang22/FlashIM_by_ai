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

        match input.msg_type {
            0 => {}
            1 => validate_image_extra(&input.extra)?,
            2 => validate_video_extra(&input.extra)?,
            3 => validate_file_extra(&input.extra)?,
            4 => validate_group_invitation_extra(&input.extra)?,
            _ => return Err(AppError::bad_request("unsupported message type")),
        }

        let preview = build_preview(input.msg_type, &input.content);
        let persisted = repository::persist_message(
            context.postgres.pool(),
            NewMessage {
                conversation_id: input.conversation_id,
                sender_id: input.sender_id,
                seq: 0,
                r#type: input.msg_type,
                content: input.content,
                extra: input.extra,
            },
            &preview,
        )
        .await?;
        let payload = MessagePayload::from(persisted.row);
        let member_ids = persisted.member_ids;
        let updates = persisted
            .unread_counts
            .into_iter()
            .map(|(user_id, unread_count)| ConversationUpdate {
                conversation_id: payload.conversation_id,
                user_id,
                last_message_preview: preview.clone(),
                last_message_at: payload.created_at,
                unread_count,
            })
            .collect::<Vec<_>>();

        let _ = self
            .broadcaster
            .broadcast_message(payload.clone(), &member_ids, Some(payload.sender_id))
            .await;
        let _ = self
            .broadcaster
            .broadcast_conversation_updates(updates.clone(), &member_ids)
            .await;

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

fn build_preview(msg_type: i16, content: &str) -> String {
    match msg_type {
        1 => "[图片]".to_string(),
        2 => "[视频]".to_string(),
        3 => "[文件]".to_string(),
        4 => "[群聊邀请]".to_string(),
        _ => content.chars().take(100).collect(),
    }
}

fn validate_image_extra(extra: &Option<Value>) -> AppResult<()> {
    let extra = extra
        .as_ref()
        .and_then(Value::as_object)
        .ok_or(AppError::bad_request("invalid image extra"))?;
    require_key(extra, "width", "invalid image extra")?;
    require_key(extra, "height", "invalid image extra")?;
    require_key(extra, "thumbnail_url", "invalid image extra")?;
    Ok(())
}

fn validate_video_extra(extra: &Option<Value>) -> AppResult<()> {
    let extra = extra
        .as_ref()
        .and_then(Value::as_object)
        .ok_or(AppError::bad_request("invalid video extra"))?;
    require_key(extra, "thumbnail_url", "invalid video extra")?;
    require_key(extra, "duration_ms", "invalid video extra")?;
    Ok(())
}

fn validate_file_extra(extra: &Option<Value>) -> AppResult<()> {
    let extra = extra
        .as_ref()
        .and_then(Value::as_object)
        .ok_or(AppError::bad_request("invalid file extra"))?;
    require_key(extra, "file_name", "invalid file extra")?;
    require_key(extra, "file_url", "invalid file extra")?;
    require_key(extra, "file_type", "invalid file extra")?;
    Ok(())
}

fn validate_group_invitation_extra(extra: &Option<Value>) -> AppResult<()> {
    let extra = extra
        .as_ref()
        .and_then(Value::as_object)
        .ok_or(AppError::bad_request("invalid group invitation extra"))?;
    for key in ["invitation_id", "group_id", "group_name", "inviter_name"] {
        require_key(extra, key, "invalid group invitation extra")?;
    }
    Ok(())
}

fn require_key(
    object: &serde_json::Map<String, Value>,
    key: &str,
    message: &'static str,
) -> AppResult<()> {
    match object.get(key) {
        Some(Value::Null) | None => Err(AppError::bad_request(message)),
        Some(Value::String(value)) if value.trim().is_empty() => {
            Err(AppError::bad_request(message))
        }
        Some(_) => Ok(()),
    }
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use crate::{
        models::MessageQuery,
        service::{
            build_preview, normalize_history_query, validate_file_extra,
            validate_group_invitation_extra, validate_image_extra, validate_video_extra,
        },
    };

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

    #[test]
    fn build_preview_uses_media_placeholders() {
        assert_eq!(build_preview(1, "hello"), "[图片]");
        assert_eq!(build_preview(2, "hello"), "[视频]");
        assert_eq!(build_preview(3, "hello"), "[文件]");
        assert_eq!(build_preview(4, "hello"), "[群聊邀请]");
        assert_eq!(build_preview(0, "hello"), "hello");
    }

    #[test]
    fn media_extra_validation_rejects_missing_fields() {
        assert!(validate_image_extra(&Some(json!({"width": 1}))).is_err());
        assert!(validate_video_extra(&Some(json!({"thumbnail_url": "x"}))).is_err());
        assert!(validate_file_extra(&Some(json!({"file_name": "x"}))).is_err());
    }

    #[test]
    fn media_extra_validation_accepts_expected_shapes() {
        assert!(
            validate_image_extra(&Some(json!({
                "width": 1,
                "height": 1,
                "thumbnail_url": "/uploads/thumb/test.webp"
            })))
            .is_ok()
        );
        assert!(
            validate_video_extra(&Some(json!({
                "thumbnail_url": "/uploads/thumb/test.jpg",
                "duration_ms": 1000
            })))
            .is_ok()
        );
        assert!(
            validate_file_extra(&Some(json!({
                "file_name": "a.pdf",
                "file_url": "/uploads/file/a.pdf",
                "file_type": "pdf"
            })))
            .is_ok()
        );
        assert!(
            validate_group_invitation_extra(&Some(json!({
                "invitation_id": "invitation-id",
                "group_id": "group-id",
                "group_name": "测试群",
                "inviter_name": "小雨"
            })))
            .is_ok()
        );
    }
}
