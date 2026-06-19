use serde::{Deserialize, Serialize};

#[derive(Clone, Serialize, Deserialize)]
pub struct UserRecord {
    pub account_id: i64,
    pub nickname: String,
    pub avatar: String,
    pub phone: String,
    pub signature: String,
    pub has_password: bool,
}
