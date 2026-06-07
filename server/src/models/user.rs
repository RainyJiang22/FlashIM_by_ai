use serde::{Deserialize, Serialize};

#[derive(Clone, Serialize, Deserialize)]
pub struct UserRecord {
    pub user_id: u64,
    pub nickname: String,
    pub avatar: String,
    pub phone: String,
}

#[derive(Serialize, Deserialize)]
pub struct ProfileResponse {
    pub user_id: u64,
    pub nickname: String,
    pub avatar: String,
    pub phone: String,
}
