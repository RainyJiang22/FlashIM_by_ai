use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
pub struct SmsRequest {
    pub phone: String,
}

#[derive(Serialize, Deserialize)]
pub struct SmsResponse {
    pub phone: String,
    pub code: String,
}

#[derive(Deserialize)]
pub struct LoginRequest {
    #[serde(default)]
    pub login_type: LoginType,
    pub phone: Option<String>,
    pub code: Option<String>,
    pub identifier: Option<String>,
    pub password: Option<String>,
}

#[derive(Serialize, Deserialize)]
pub struct LoginResponse {
    pub token: String,
    pub account_id: i64,
    pub password_setup_required: bool,
}

#[derive(Deserialize)]
pub struct SetPasswordRequest {
    pub new_password: String,
}

#[derive(Serialize, Deserialize)]
pub struct SetPasswordResponse {
    pub password_setup_required: bool,
    pub updated_at: DateTime<Utc>,
}

#[derive(Deserialize)]
pub struct ChangePasswordRequest {
    pub old_password: String,
    pub new_password: String,
}

#[derive(Serialize, Deserialize)]
pub struct PasswordUpdatedResponse {
    pub updated_at: DateTime<Utc>,
}

#[derive(Clone, Copy, Default, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum LoginType {
    #[default]
    SmsCode,
    Password,
}

#[derive(Clone, Serialize, Deserialize)]
pub struct AuthClaims {
    pub account_id: i64,
    pub exp: usize,
}
