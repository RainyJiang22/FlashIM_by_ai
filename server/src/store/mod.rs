use async_trait::async_trait;
use chrono::{DateTime, Utc};
use serde_json::Value;

use crate::error::AppResult;

pub mod memory;
pub mod postgres;

#[derive(Clone, Debug)]
pub struct AccountRecord {
    pub id: i64,
    pub status: String,
    pub primary_identifier: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Clone, Debug)]
pub struct ProfileRecord {
    pub account_id: i64,
    pub nickname: String,
    pub avatar_url: String,
    pub bio: String,
    pub updated_at: DateTime<Utc>,
}

#[derive(Clone, Debug)]
pub struct CredentialRecord {
    pub id: i64,
    pub account_id: i64,
    pub credential_type: CredentialType,
    pub identifier: String,
    pub password_hash: Option<String>,
    pub metadata: Value,
    pub verified_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Clone, Debug)]
pub struct AccountAggregate {
    pub account: AccountRecord,
    pub profile: ProfileRecord,
    pub credentials: Vec<CredentialRecord>,
}

#[derive(Clone, Debug)]
pub struct NewProfile {
    pub nickname: String,
    pub avatar_url: String,
    pub bio: String,
}

#[derive(Clone, Debug)]
pub enum CredentialType {
    Phone,
    Password,
    Email,
    Wechat,
}

impl CredentialType {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Phone => "phone",
            Self::Password => "password",
            Self::Email => "email",
            Self::Wechat => "wechat",
        }
    }

    pub fn from_db(value: &str) -> Option<Self> {
        match value {
            "phone" => Some(Self::Phone),
            "password" => Some(Self::Password),
            "email" => Some(Self::Email),
            "wechat" => Some(Self::Wechat),
            _ => None,
        }
    }
}

#[async_trait]
pub trait AuthStore: Send + Sync {
    async fn save_sms_code(
        &self,
        phone: &str,
        code: &str,
        purpose: &str,
        expires_at: DateTime<Utc>,
    ) -> AppResult<()>;
    async fn consume_sms_code(&self, phone: &str, code: &str, purpose: &str) -> AppResult<bool>;
    async fn find_account_by_id(&self, account_id: i64) -> AppResult<Option<AccountAggregate>>;
    async fn find_account_by_credential(
        &self,
        credential_type: CredentialType,
        identifier: &str,
    ) -> AppResult<Option<AccountAggregate>>;
    async fn create_account_with_phone(
        &self,
        phone: &str,
        profile: NewProfile,
    ) -> AppResult<AccountAggregate>;
    async fn upsert_password_credential(
        &self,
        account_id: i64,
        identifier: &str,
        password_hash: &str,
    ) -> AppResult<DateTime<Utc>>;
    async fn find_password_credential_by_identifier(
        &self,
        identifier: &str,
    ) -> AppResult<Option<CredentialRecord>>;
    async fn find_password_credential_by_account_id(
        &self,
        account_id: i64,
    ) -> AppResult<Option<CredentialRecord>>;
}
