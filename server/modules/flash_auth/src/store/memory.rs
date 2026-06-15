use std::{
    collections::HashMap,
    sync::atomic::{AtomicI64, Ordering},
};

use async_trait::async_trait;
use chrono::{DateTime, Utc};
use flash_core::AppResult;
use serde_json::json;
use tokio::sync::RwLock;

use crate::store::{
    AccountAggregate, AccountRecord, AuthStore, CredentialRecord, CredentialType, NewProfile,
    ProfileRecord,
};

pub struct InMemoryStore {
    sms_codes: RwLock<HashMap<(String, String), Vec<SmsCodeRecord>>>,
    accounts_by_id: RwLock<HashMap<i64, AccountRecord>>,
    profiles_by_account_id: RwLock<HashMap<i64, ProfileRecord>>,
    credentials_by_id: RwLock<HashMap<i64, CredentialRecord>>,
    credential_ids_by_lookup: RwLock<HashMap<(String, String), i64>>,
    next_account_id: AtomicI64,
    next_credential_id: AtomicI64,
    next_sms_code_id: AtomicI64,
}

impl Default for InMemoryStore {
    fn default() -> Self {
        Self::new()
    }
}

impl InMemoryStore {
    pub fn new() -> Self {
        Self {
            sms_codes: RwLock::new(HashMap::new()),
            accounts_by_id: RwLock::new(HashMap::new()),
            profiles_by_account_id: RwLock::new(HashMap::new()),
            credentials_by_id: RwLock::new(HashMap::new()),
            credential_ids_by_lookup: RwLock::new(HashMap::new()),
            next_account_id: AtomicI64::new(10001),
            next_credential_id: AtomicI64::new(1),
            next_sms_code_id: AtomicI64::new(1),
        }
    }

    async fn load_account_aggregate(&self, account_id: i64) -> Option<AccountAggregate> {
        let account = self.accounts_by_id.read().await.get(&account_id).cloned()?;
        let profile = self
            .profiles_by_account_id
            .read()
            .await
            .get(&account_id)
            .cloned()?;
        let credentials = self
            .credentials_by_id
            .read()
            .await
            .values()
            .filter(|credential| credential.account_id == account_id)
            .cloned()
            .collect();

        Some(AccountAggregate {
            account,
            profile,
            credentials,
        })
    }
}

#[async_trait]
impl AuthStore for InMemoryStore {
    async fn save_sms_code(
        &self,
        phone: &str,
        code: &str,
        purpose: &str,
        expires_at: DateTime<Utc>,
    ) -> AppResult<()> {
        let record = SmsCodeRecord {
            code: code.to_string(),
            expires_at,
            consumed_at: None,
        };

        let _ = self.next_sms_code_id.fetch_add(1, Ordering::Relaxed);

        self.sms_codes
            .write()
            .await
            .entry((phone.to_string(), purpose.to_string()))
            .or_default()
            .push(record);

        Ok(())
    }

    async fn consume_sms_code(&self, phone: &str, code: &str, purpose: &str) -> AppResult<bool> {
        let mut sms_codes = self.sms_codes.write().await;
        let Some(records) = sms_codes.get_mut(&(phone.to_string(), purpose.to_string())) else {
            return Ok(false);
        };

        let now = Utc::now();
        if let Some(record) = records.iter_mut().rev().find(|record| {
            record.code == code && record.consumed_at.is_none() && record.expires_at > now
        }) {
            record.consumed_at = Some(now);
            return Ok(true);
        }

        Ok(false)
    }

    async fn find_account_by_id(&self, account_id: i64) -> AppResult<Option<AccountAggregate>> {
        Ok(self.load_account_aggregate(account_id).await)
    }

    async fn find_account_by_credential(
        &self,
        credential_type: CredentialType,
        identifier: &str,
    ) -> AppResult<Option<AccountAggregate>> {
        let credential_id = self
            .credential_ids_by_lookup
            .read()
            .await
            .get(&(credential_type.as_str().to_string(), identifier.to_string()))
            .copied();

        let Some(credential_id) = credential_id else {
            return Ok(None);
        };

        let account_id = self
            .credentials_by_id
            .read()
            .await
            .get(&credential_id)
            .map(|credential| credential.account_id);

        match account_id {
            Some(account_id) => Ok(self.load_account_aggregate(account_id).await),
            None => Ok(None),
        }
    }

    async fn create_account_with_phone(
        &self,
        phone: &str,
        profile: NewProfile,
    ) -> AppResult<AccountAggregate> {
        let account_id = self.next_account_id.fetch_add(1, Ordering::Relaxed);
        let now = Utc::now();
        let account = AccountRecord {
            id: account_id,
            status: "active".to_string(),
            primary_identifier: phone.to_string(),
            created_at: now,
            updated_at: now,
        };
        let profile = ProfileRecord {
            account_id,
            nickname: profile.nickname,
            avatar_url: profile.avatar_url,
            bio: profile.bio,
            updated_at: now,
        };
        let phone_credential = CredentialRecord {
            id: self.next_credential_id.fetch_add(1, Ordering::Relaxed),
            account_id,
            credential_type: CredentialType::Phone,
            identifier: phone.to_string(),
            password_hash: None,
            metadata: json!({}),
            verified_at: Some(now),
            created_at: now,
            updated_at: now,
        };

        self.accounts_by_id
            .write()
            .await
            .insert(account_id, account);
        self.profiles_by_account_id
            .write()
            .await
            .insert(account_id, profile);
        self.credential_ids_by_lookup.write().await.insert(
            (
                phone_credential.credential_type.as_str().to_string(),
                phone.to_string(),
            ),
            phone_credential.id,
        );
        self.credentials_by_id
            .write()
            .await
            .insert(phone_credential.id, phone_credential);

        Ok(self
            .load_account_aggregate(account_id)
            .await
            .expect("new account should be queryable"))
    }

    async fn upsert_password_credential(
        &self,
        account_id: i64,
        identifier: &str,
        password_hash: &str,
    ) -> AppResult<DateTime<Utc>> {
        let now = Utc::now();
        let lookup_key = (
            CredentialType::Password.as_str().to_string(),
            identifier.to_string(),
        );
        let existing_id = self
            .credential_ids_by_lookup
            .read()
            .await
            .get(&lookup_key)
            .copied();

        match existing_id {
            Some(credential_id) => {
                let mut credentials_by_id = self.credentials_by_id.write().await;
                if let Some(credential) = credentials_by_id.get_mut(&credential_id) {
                    credential.password_hash = Some(password_hash.to_string());
                    credential.updated_at = now;
                    credential.verified_at = Some(now);
                }
            }
            None => {
                let credential = CredentialRecord {
                    id: self.next_credential_id.fetch_add(1, Ordering::Relaxed),
                    account_id,
                    credential_type: CredentialType::Password,
                    identifier: identifier.to_string(),
                    password_hash: Some(password_hash.to_string()),
                    metadata: json!({}),
                    verified_at: Some(now),
                    created_at: now,
                    updated_at: now,
                };
                self.credential_ids_by_lookup
                    .write()
                    .await
                    .insert(lookup_key, credential.id);
                self.credentials_by_id
                    .write()
                    .await
                    .insert(credential.id, credential);
            }
        }

        Ok(now)
    }

    async fn find_password_credential_by_identifier(
        &self,
        identifier: &str,
    ) -> AppResult<Option<CredentialRecord>> {
        let lookup_key = (
            CredentialType::Password.as_str().to_string(),
            identifier.to_string(),
        );
        let credential_id = self
            .credential_ids_by_lookup
            .read()
            .await
            .get(&lookup_key)
            .copied();
        let credential = match credential_id {
            Some(id) => self.credentials_by_id.read().await.get(&id).cloned(),
            None => None,
        };

        Ok(credential)
    }

    async fn find_password_credential_by_account_id(
        &self,
        account_id: i64,
    ) -> AppResult<Option<CredentialRecord>> {
        let credential = self
            .credentials_by_id
            .read()
            .await
            .values()
            .find(|credential| {
                credential.account_id == account_id
                    && matches!(credential.credential_type, CredentialType::Password)
            })
            .cloned();
        Ok(credential)
    }
}

#[derive(Clone)]
struct SmsCodeRecord {
    code: String,
    expires_at: DateTime<Utc>,
    consumed_at: Option<DateTime<Utc>>,
}
