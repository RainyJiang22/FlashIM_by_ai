use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct UserProfileResponse {
    pub account_id: i64,
    pub nickname: String,
    pub avatar: String,
    pub phone: String,
    pub signature: String,
    pub has_password: bool,
}

#[derive(Debug, Deserialize)]
pub struct UpdateProfileRequest {
    pub nickname: Option<String>,
    pub avatar: Option<String>,
    pub signature: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct SetPasswordRequest {
    pub new_password: String,
}

#[derive(Debug, Deserialize)]
pub struct ChangePasswordRequest {
    pub old_password: String,
    pub new_password: String,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct MessageResponse {
    pub message: String,
}
