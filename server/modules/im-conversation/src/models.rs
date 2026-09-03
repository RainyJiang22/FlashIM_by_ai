use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, sqlx::FromRow)]
pub struct ConversationListRow {
    pub id: Uuid,
    pub r#type: i16,
    pub name: Option<String>,
    pub avatar: Option<String>,
    pub owner_id: Option<i64>,
    pub member_avatars: Vec<String>,
    pub member_count: i32,
    pub peer_user_id: Option<i64>,
    pub peer_nickname: Option<String>,
    pub peer_avatar: Option<String>,
    pub last_message_at: Option<DateTime<Utc>>,
    pub last_message_preview: Option<String>,
    pub unread_count: i32,
    pub announcement: Option<String>,
    pub is_dissolved: bool,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct ConversationListItem {
    pub id: Uuid,
    pub r#type: i16,
    pub name: Option<String>,
    pub avatar: Option<String>,
    pub owner_id: Option<String>,
    pub member_avatars: Vec<String>,
    pub member_count: i32,
    pub peer_user_id: Option<String>,
    pub peer_nickname: Option<String>,
    pub peer_avatar: Option<String>,
    pub last_message_at: Option<DateTime<Utc>>,
    pub last_message_preview: Option<String>,
    pub unread_count: i32,
    pub announcement: String,
    pub is_dissolved: bool,
    pub created_at: DateTime<Utc>,
}

impl From<ConversationListRow> for ConversationListItem {
    fn from(row: ConversationListRow) -> Self {
        Self {
            id: row.id,
            r#type: row.r#type,
            name: row.name,
            avatar: row.avatar,
            owner_id: row.owner_id.map(|id| id.to_string()),
            member_avatars: row.member_avatars,
            member_count: row.member_count,
            peer_user_id: row.peer_user_id.map(|id| id.to_string()),
            peer_nickname: row.peer_nickname,
            peer_avatar: row.peer_avatar,
            last_message_at: row.last_message_at,
            last_message_preview: row.last_message_preview,
            unread_count: row.unread_count,
            announcement: row.announcement.unwrap_or_default(),
            is_dissolved: row.is_dissolved,
            created_at: row.created_at,
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct ConversationListQuery {
    pub limit: Option<i64>,
    pub offset: Option<i64>,
    pub r#type: Option<i16>,
}

#[derive(Debug, Deserialize)]
pub struct CreateConversationBody {
    pub r#type: String,
    pub name: String,
    pub member_ids: Vec<i64>,
}

#[cfg(test)]
mod tests {
    use chrono::Utc;
    use uuid::Uuid;

    use super::{ConversationListItem, ConversationListRow};

    #[test]
    fn group_row_maps_owner_and_member_avatars() {
        let row = ConversationListRow {
            id: Uuid::nil(),
            r#type: 1,
            name: Some("测试群".to_string()),
            avatar: Some("grid:identicon:10001".to_string()),
            owner_id: Some(10001),
            member_avatars: vec!["identicon:10001".to_string()],
            member_count: 1,
            peer_user_id: None,
            peer_nickname: None,
            peer_avatar: None,
            last_message_at: None,
            last_message_preview: None,
            unread_count: 0,
            announcement: Some("欢迎加入".to_string()),
            is_dissolved: false,
            created_at: Utc::now(),
        };

        let item = ConversationListItem::from(row);
        assert_eq!(item.owner_id.as_deref(), Some("10001"));
        assert_eq!(item.avatar.as_deref(), Some("grid:identicon:10001"));
        assert_eq!(item.member_avatars, ["identicon:10001"]);
        assert_eq!(item.member_count, 1);
        assert_eq!(item.announcement, "欢迎加入");
        assert!(item.peer_user_id.is_none());
    }
}
