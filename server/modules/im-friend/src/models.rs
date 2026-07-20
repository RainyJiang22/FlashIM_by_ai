use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

pub const FRIEND_REQUEST_PENDING: i16 = 0;
pub const FRIEND_REQUEST_ACCEPTED: i16 = 1;
pub const FRIEND_REQUEST_REJECTED: i16 = 2;

pub const RELATION_NONE: &str = "none";
pub const RELATION_PENDING_SENT: &str = "pending_sent";
pub const RELATION_PENDING_RECEIVED: &str = "pending_received";
pub const RELATION_FRIEND: &str = "friend";

#[derive(Debug, Deserialize)]
pub struct FriendRequestListQuery {
    pub status: Option<String>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

#[derive(Debug, Deserialize)]
pub struct UserSearchQuery {
    pub q: String,
    pub limit: Option<i64>,
}

#[derive(Clone, Debug, sqlx::FromRow)]
pub struct FriendUserRow {
    pub account_id: i64,
    pub nickname: String,
    pub avatar: String,
    pub signature: String,
    pub flash_id: Option<String>,
    pub relation_status: Option<String>,
    pub created_at: Option<DateTime<Utc>>,
}

#[derive(Clone, Debug, Serialize)]
pub struct FriendUserResponse {
    pub account_id: i64,
    pub nickname: String,
    pub avatar: String,
    pub signature: String,
    pub flash_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub relation_status: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub created_at: Option<DateTime<Utc>>,
}

impl From<FriendUserRow> for FriendUserResponse {
    fn from(row: FriendUserRow) -> Self {
        Self {
            account_id: row.account_id,
            nickname: row.nickname,
            avatar: row.avatar,
            signature: row.signature,
            flash_id: row
                .flash_id
                .or_else(|| Some(format!("flash_{}", row.account_id))),
            relation_status: row.relation_status,
            created_at: row.created_at,
        }
    }
}

#[derive(Clone, Debug, sqlx::FromRow)]
pub struct FriendRequestRow {
    pub id: Uuid,
    pub from_user_id: i64,
    pub to_user_id: i64,
    pub message: String,
    pub status: i16,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub handled_at: Option<DateTime<Utc>>,
    pub from_nickname: String,
    pub from_avatar: String,
    pub from_signature: String,
    pub from_flash_id: Option<String>,
    pub to_nickname: String,
    pub to_avatar: String,
    pub to_signature: String,
    pub to_flash_id: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct SendFriendRequestBody {
    pub to_user_id: i64,
    pub message: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct FriendRequestResponse {
    pub id: Uuid,
    pub from_user_id: i64,
    pub to_user_id: i64,
    pub message: String,
    pub status: String,
    pub created_at: DateTime<Utc>,
}

impl From<FriendRequestRow> for FriendRequestResponse {
    fn from(row: FriendRequestRow) -> Self {
        Self {
            id: row.id,
            from_user_id: row.from_user_id,
            to_user_id: row.to_user_id,
            message: row.message,
            status: status_label(row.status).to_string(),
            created_at: row.created_at,
        }
    }
}

#[derive(Debug, Serialize)]
pub struct ReceivedFriendRequestResponse {
    pub id: Uuid,
    pub from_user: FriendUserResponse,
    pub message: String,
    pub status: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct SentFriendRequestResponse {
    pub id: Uuid,
    pub to_user: FriendUserResponse,
    pub message: String,
    pub status: String,
    pub created_at: DateTime<Utc>,
}

impl From<FriendRequestRow> for ReceivedFriendRequestResponse {
    fn from(row: FriendRequestRow) -> Self {
        let from_user_id = row.from_user_id;
        Self {
            id: row.id,
            from_user: FriendUserResponse {
                account_id: from_user_id,
                nickname: row.from_nickname,
                avatar: row.from_avatar,
                signature: row.from_signature,
                flash_id: row
                    .from_flash_id
                    .or_else(|| Some(format!("flash_{from_user_id}"))),
                relation_status: None,
                created_at: None,
            },
            message: row.message,
            status: status_label(row.status).to_string(),
            created_at: row.created_at,
        }
    }
}

impl From<FriendRequestRow> for SentFriendRequestResponse {
    fn from(row: FriendRequestRow) -> Self {
        let to_user_id = row.to_user_id;
        Self {
            id: row.id,
            to_user: FriendUserResponse {
                account_id: to_user_id,
                nickname: row.to_nickname,
                avatar: row.to_avatar,
                signature: row.to_signature,
                flash_id: row
                    .to_flash_id
                    .or_else(|| Some(format!("flash_{to_user_id}"))),
                relation_status: None,
                created_at: None,
            },
            message: row.message,
            status: status_label(row.status).to_string(),
            created_at: row.created_at,
        }
    }
}

#[derive(Debug, Serialize)]
pub struct AcceptFriendRequestResponse {
    pub request_id: Uuid,
    pub friend: FriendUserResponse,
    pub conversation_id: Uuid,
}

#[derive(Debug, Serialize)]
pub struct RejectFriendRequestResponse {
    pub request_id: Uuid,
    pub status: String,
}

#[derive(Debug, Serialize)]
pub struct MessageResponse {
    pub message: &'static str,
}

pub fn status_label(status: i16) -> &'static str {
    match status {
        FRIEND_REQUEST_ACCEPTED => "accepted",
        FRIEND_REQUEST_REJECTED => "rejected",
        _ => "pending",
    }
}
