use serde::{Deserialize, Serialize};

#[derive(Serialize)]
pub struct ConversationResponse {
    pub title: &'static str,
    #[serde(rename = "lastMsg")]
    pub last_msg: &'static str,
    pub time: &'static str,
}

#[derive(Deserialize)]
pub struct ChatRoomWsQuery {
    pub token: Option<String>,
}

#[derive(Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ChatRoomClientEvent {
    Ping,
    Chat { text: String },
}

#[derive(Clone, Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ChatRoomServerEvent {
    AuthReady {
        user_id: u64,
        nickname: String,
        avatar: String,
    },
    Chat {
        message_id: u64,
        user_id: u64,
        nickname: String,
        avatar: String,
        text: String,
        sent_at: u64,
    },
    Pong {
        sent_at: u64,
    },
    Error {
        message: String,
    },
}
