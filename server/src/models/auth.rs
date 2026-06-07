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
    pub account: Option<String>,
    pub password: Option<String>,
}

#[derive(Serialize, Deserialize)]
pub struct LoginResponse {
    pub token: String,
    pub user_id: u64,
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
    pub user_id: u64,
    pub exp: usize,
}
