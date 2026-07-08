use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

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
        }
    }
}
