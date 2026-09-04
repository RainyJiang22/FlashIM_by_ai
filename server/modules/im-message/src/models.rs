use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use im_conversation::ConversationListItem;

#[derive(Clone, Debug, sqlx::FromRow)]
pub struct MessageRow {
    pub id: Uuid,
    pub conversation_id: Uuid,
    pub sender_id: i64,
    pub seq: i64,
    pub r#type: i16,
    pub content: String,
    pub extra: Option<serde_json::Value>,
    pub status: i16,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug)]
pub struct NewMessage {
    pub conversation_id: Uuid,
    pub sender_id: i64,
    pub seq: i64,
    pub r#type: i16,
    pub content: String,
    pub extra: Option<serde_json::Value>,
}

#[derive(Debug, Deserialize)]
pub struct MessageQuery {
    pub before_seq: Option<i64>,
    pub limit: Option<i64>,
}

#[derive(Debug, Deserialize)]
pub struct GlobalMessageSearchQuery {
    pub q: String,
    pub group_limit: Option<i64>,
    pub message_limit: Option<i64>,
}

#[derive(Debug, Deserialize)]
pub struct ConversationMessageSearchQuery {
    pub q: String,
    pub limit: Option<i64>,
}

#[derive(Clone, Debug, sqlx::FromRow)]
pub struct MessageWithSenderRow {
    pub id: Uuid,
    pub conversation_id: Uuid,
    pub sender_id: i64,
    pub sender_name: Option<String>,
    pub sender_avatar: Option<String>,
    pub seq: i64,
    pub r#type: i16,
    pub content: String,
    pub extra: Option<serde_json::Value>,
    pub status: i16,
    pub created_at: DateTime<Utc>,
    pub read_count: i32,
}

#[derive(Clone, Debug, sqlx::FromRow)]
pub struct MessageSearchRow {
    pub id: Uuid,
    pub conversation_id: Uuid,
    pub sender_id: i64,
    pub sender_name: Option<String>,
    pub sender_avatar: Option<String>,
    pub seq: i64,
    pub r#type: i16,
    pub content: String,
    pub extra: Option<serde_json::Value>,
    pub status: i16,
    pub created_at: DateTime<Utc>,
    pub read_count: i32,
    pub match_count: i64,
}

#[derive(Debug, Serialize)]
pub struct MessageWithSender {
    pub id: Uuid,
    pub conversation_id: Uuid,
    pub sender_id: String,
    pub sender_name: Option<String>,
    pub sender_avatar: Option<String>,
    pub seq: i64,
    pub msg_type: i16,
    pub content: String,
    pub extra: Option<serde_json::Value>,
    pub status: i16,
    pub created_at: DateTime<Utc>,
    pub read_count: i32,
}

impl From<MessageWithSenderRow> for MessageWithSender {
    fn from(row: MessageWithSenderRow) -> Self {
        Self {
            id: row.id,
            conversation_id: row.conversation_id,
            sender_id: row.sender_id.to_string(),
            sender_name: row.sender_name,
            sender_avatar: row.sender_avatar,
            seq: row.seq,
            msg_type: row.r#type,
            content: row.content,
            extra: row.extra,
            status: row.status,
            created_at: row.created_at,
            read_count: row.read_count,
        }
    }
}

impl From<MessageSearchRow> for MessageWithSender {
    fn from(row: MessageSearchRow) -> Self {
        Self {
            id: row.id,
            conversation_id: row.conversation_id,
            sender_id: row.sender_id.to_string(),
            sender_name: row.sender_name,
            sender_avatar: row.sender_avatar,
            seq: row.seq,
            msg_type: row.r#type,
            content: row.content,
            extra: row.extra,
            status: row.status,
            created_at: row.created_at,
            read_count: row.read_count,
        }
    }
}

#[derive(Debug, Serialize)]
pub struct MessageSearchGroup {
    pub conversation: ConversationListItem,
    pub match_count: i64,
    pub messages: Vec<MessageWithSender>,
}

#[derive(Clone, Debug, Serialize, PartialEq, Eq)]
pub struct ReadStatusMember {
    pub user_id: String,
    pub nickname: String,
    pub avatar: String,
}

#[derive(Clone, Debug, Serialize, PartialEq, Eq)]
pub struct MessageReadStatus {
    pub message_id: Uuid,
    pub conversation_id: Uuid,
    pub seq: i64,
    pub read_members: Vec<ReadStatusMember>,
    pub unread_members: Vec<ReadStatusMember>,
}
