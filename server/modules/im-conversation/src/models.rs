use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, sqlx::FromRow)]
pub struct ConversationListRow {
    pub id: Uuid,
    pub r#type: i16,
    pub name: Option<String>,
    pub peer_user_id: Option<i64>,
    pub peer_nickname: Option<String>,
    pub peer_avatar: Option<String>,
    pub last_message_at: Option<DateTime<Utc>>,
    pub last_message_preview: Option<String>,
    pub unread_count: i32,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct ConversationListItem {
    pub id: Uuid,
    pub r#type: i16,
    pub name: Option<String>,
    pub peer_user_id: Option<String>,
    pub peer_nickname: Option<String>,
    pub peer_avatar: Option<String>,
    pub last_message_at: Option<DateTime<Utc>>,
    pub last_message_preview: Option<String>,
    pub unread_count: i32,
    pub created_at: DateTime<Utc>,
}

impl From<ConversationListRow> for ConversationListItem {
    fn from(row: ConversationListRow) -> Self {
        Self {
            id: row.id,
            r#type: row.r#type,
            name: row.name,
            peer_user_id: row.peer_user_id.map(|id| id.to_string()),
            peer_nickname: row.peer_nickname,
            peer_avatar: row.peer_avatar,
            last_message_at: row.last_message_at,
            last_message_preview: row.last_message_preview,
            unread_count: row.unread_count,
            created_at: row.created_at,
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct ConversationListQuery {
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}
