use async_trait::async_trait;
use chrono::{DateTime, Utc};
use flash_core::{AppError, AppResult, runtime::postgres::PostgresRuntime};
use serde_json::Value;
use sqlx::FromRow;
use std::sync::Arc;

use crate::store::{
    AccountAggregate, AccountRecord, AuthStore, CredentialRecord, CredentialType, NewProfile,
    ProfileRecord, UpdateProfilePatch,
};

#[derive(Clone)]
pub struct PostgresAuthStore {
    postgres: Arc<PostgresRuntime>,
}

impl PostgresAuthStore {
    pub fn new(postgres: Arc<PostgresRuntime>) -> Self {
        Self { postgres }
    }

    async fn load_account_aggregate(&self, account_id: i64) -> AppResult<Option<AccountAggregate>> {
        let Some(account_row) = sqlx::query_as::<_, AccountRow>(
            r#"
            SELECT id, status, primary_identifier, created_at, updated_at
            FROM accounts
            WHERE id = $1
            "#,
        )
        .bind(account_id)
        .fetch_optional(self.postgres.pool())
        .await
        .map_err(database_error)?
        else {
            return Ok(None);
        };

        let Some(profile_row) = sqlx::query_as::<_, ProfileRow>(
            r#"
            SELECT account_id, nickname, avatar_url, signature, bio, updated_at
            FROM user_profiles
            WHERE account_id = $1
            "#,
        )
        .bind(account_id)
        .fetch_optional(self.postgres.pool())
        .await
        .map_err(database_error)?
        else {
            return Ok(None);
        };

        let credential_rows = sqlx::query_as::<_, CredentialRow>(
            r#"
            SELECT
                id,
                account_id,
                credential_type,
                identifier,
                password_hash,
                metadata,
                verified_at,
                created_at,
                updated_at
            FROM auth_credentials
            WHERE account_id = $1
            ORDER BY id ASC
            "#,
        )
        .bind(account_id)
        .fetch_all(self.postgres.pool())
        .await
        .map_err(database_error)?;

        let credentials = credential_rows
            .into_iter()
            .map(CredentialRecord::try_from)
            .collect::<AppResult<Vec<_>>>()?;

        Ok(Some(AccountAggregate {
            account: account_row.into(),
            profile: profile_row.into(),
            credentials,
        }))
    }
}

#[async_trait]
impl AuthStore for PostgresAuthStore {
    async fn save_sms_code(
        &self,
        phone: &str,
        code: &str,
        purpose: &str,
        expires_at: DateTime<Utc>,
    ) -> AppResult<()> {
        sqlx::query(
            r#"
            INSERT INTO sms_codes (phone, code, purpose, expires_at)
            VALUES ($1, $2, $3, $4)
            "#,
        )
        .bind(phone)
        .bind(code)
        .bind(purpose)
        .bind(expires_at)
        .execute(self.postgres.pool())
        .await
        .map_err(database_error)?;

        Ok(())
    }

    async fn consume_sms_code(&self, phone: &str, code: &str, purpose: &str) -> AppResult<bool> {
        let result = sqlx::query_scalar::<_, i64>(
            r#"
            WITH target AS (
                SELECT id
                FROM sms_codes
                WHERE phone = $1
                  AND code = $2
                  AND purpose = $3
                  AND consumed_at IS NULL
                  AND expires_at > NOW()
                ORDER BY created_at DESC
                LIMIT 1
                FOR UPDATE
            )
            UPDATE sms_codes
            SET consumed_at = NOW()
            WHERE id IN (SELECT id FROM target)
            RETURNING id
            "#,
        )
        .bind(phone)
        .bind(code)
        .bind(purpose)
        .fetch_optional(self.postgres.pool())
        .await
        .map_err(database_error)?;

        Ok(result.is_some())
    }

    async fn find_account_by_id(&self, account_id: i64) -> AppResult<Option<AccountAggregate>> {
        self.load_account_aggregate(account_id).await
    }

    async fn find_account_by_credential(
        &self,
        credential_type: CredentialType,
        identifier: &str,
    ) -> AppResult<Option<AccountAggregate>> {
        let account_id = sqlx::query_scalar::<_, i64>(
            r#"
            SELECT account_id
            FROM auth_credentials
            WHERE credential_type = $1 AND identifier = $2
            LIMIT 1
            "#,
        )
        .bind(credential_type.as_str())
        .bind(identifier)
        .fetch_optional(self.postgres.pool())
        .await
        .map_err(database_error)?;

        match account_id {
            Some(account_id) => self.load_account_aggregate(account_id).await,
            None => Ok(None),
        }
    }

    async fn create_account_with_phone(
        &self,
        phone: &str,
        profile: NewProfile,
    ) -> AppResult<AccountAggregate> {
        let mut tx = self.postgres.pool().begin().await.map_err(database_error)?;

        let account_row = sqlx::query_as::<_, AccountRow>(
            r#"
            INSERT INTO accounts (primary_identifier)
            VALUES ($1)
            RETURNING id, status, primary_identifier, created_at, updated_at
            "#,
        )
        .bind(phone)
        .fetch_one(&mut *tx)
        .await
        .map_err(database_error)?;

        sqlx::query(
            r#"
            INSERT INTO user_profiles (account_id, nickname, avatar_url, signature, bio)
            VALUES ($1, $2, $3, $4, $5)
            "#,
        )
        .bind(account_row.id)
        .bind(&profile.nickname)
        .bind(
            profile
                .avatar_url
                .unwrap_or_else(|| format!("identicon:{}", account_row.id)),
        )
        .bind(&profile.signature)
        .bind(&profile.bio)
        .execute(&mut *tx)
        .await
        .map_err(database_error)?;

        sqlx::query(
            r#"
            INSERT INTO auth_credentials (
                account_id,
                credential_type,
                identifier,
                metadata,
                verified_at
            )
            VALUES ($1, $2, $3, '{}'::jsonb, NOW())
            "#,
        )
        .bind(account_row.id)
        .bind(CredentialType::Phone.as_str())
        .bind(phone)
        .execute(&mut *tx)
        .await
        .map_err(database_error)?;

        tx.commit().await.map_err(database_error)?;

        self.load_account_aggregate(account_row.id)
            .await?
            .ok_or_else(|| AppError::internal_server_error("internal server error"))
    }

    async fn update_profile(
        &self,
        account_id: i64,
        patch: UpdateProfilePatch,
    ) -> AppResult<Option<AccountAggregate>> {
        let updated = sqlx::query_scalar::<_, i64>(
            r#"
            UPDATE user_profiles
            SET
                nickname = COALESCE($2, nickname),
                avatar_url = COALESCE($3, avatar_url),
                signature = COALESCE($4, signature),
                updated_at = NOW()
            WHERE account_id = $1
            RETURNING account_id
            "#,
        )
        .bind(account_id)
        .bind(patch.nickname.as_deref())
        .bind(patch.avatar_url.as_deref())
        .bind(patch.signature.as_deref())
        .fetch_optional(self.postgres.pool())
        .await
        .map_err(database_error)?;

        match updated {
            Some(updated_account_id) => self.load_account_aggregate(updated_account_id).await,
            None => Ok(None),
        }
    }

    async fn upsert_password_credential(
        &self,
        account_id: i64,
        identifier: &str,
        password_hash: &str,
    ) -> AppResult<DateTime<Utc>> {
        sqlx::query_scalar::<_, DateTime<Utc>>(
            r#"
            INSERT INTO auth_credentials (
                account_id,
                credential_type,
                identifier,
                password_hash,
                metadata,
                verified_at
            )
            VALUES ($1, $2, $3, $4, '{}'::jsonb, NOW())
            ON CONFLICT (credential_type, identifier)
            DO UPDATE SET
                password_hash = EXCLUDED.password_hash,
                verified_at = NOW(),
                updated_at = NOW()
            RETURNING updated_at
            "#,
        )
        .bind(account_id)
        .bind(CredentialType::Password.as_str())
        .bind(identifier)
        .bind(password_hash)
        .fetch_one(self.postgres.pool())
        .await
        .map_err(database_error)
    }

    async fn find_password_credential_by_identifier(
        &self,
        identifier: &str,
    ) -> AppResult<Option<CredentialRecord>> {
        sqlx::query_as::<_, CredentialRow>(
            r#"
            SELECT
                id,
                account_id,
                credential_type,
                identifier,
                password_hash,
                metadata,
                verified_at,
                created_at,
                updated_at
            FROM auth_credentials
            WHERE credential_type = $1 AND identifier = $2
            LIMIT 1
            "#,
        )
        .bind(CredentialType::Password.as_str())
        .bind(identifier)
        .fetch_optional(self.postgres.pool())
        .await
        .map_err(database_error)?
        .map(CredentialRecord::try_from)
        .transpose()
    }

    async fn find_password_credential_by_account_id(
        &self,
        account_id: i64,
    ) -> AppResult<Option<CredentialRecord>> {
        sqlx::query_as::<_, CredentialRow>(
            r#"
            SELECT
                id,
                account_id,
                credential_type,
                identifier,
                password_hash,
                metadata,
                verified_at,
                created_at,
                updated_at
            FROM auth_credentials
            WHERE account_id = $1 AND credential_type = $2
            LIMIT 1
            "#,
        )
        .bind(account_id)
        .bind(CredentialType::Password.as_str())
        .fetch_optional(self.postgres.pool())
        .await
        .map_err(database_error)?
        .map(CredentialRecord::try_from)
        .transpose()
    }
}

fn database_error(error: sqlx::Error) -> AppError {
    println!("database error: {error}");
    AppError::internal_server_error("internal server error")
}

#[derive(FromRow)]
struct AccountRow {
    id: i64,
    status: String,
    primary_identifier: String,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

impl From<AccountRow> for AccountRecord {
    fn from(value: AccountRow) -> Self {
        Self {
            id: value.id,
            status: value.status,
            primary_identifier: value.primary_identifier,
            created_at: value.created_at,
            updated_at: value.updated_at,
        }
    }
}

#[derive(FromRow)]
struct ProfileRow {
    account_id: i64,
    nickname: String,
    avatar_url: String,
    signature: String,
    bio: String,
    updated_at: DateTime<Utc>,
}

impl From<ProfileRow> for ProfileRecord {
    fn from(value: ProfileRow) -> Self {
        Self {
            account_id: value.account_id,
            nickname: value.nickname,
            avatar_url: value.avatar_url,
            signature: value.signature,
            bio: value.bio,
            updated_at: value.updated_at,
        }
    }
}

#[derive(FromRow)]
struct CredentialRow {
    id: i64,
    account_id: i64,
    credential_type: String,
    identifier: String,
    password_hash: Option<String>,
    metadata: Value,
    verified_at: Option<DateTime<Utc>>,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

impl TryFrom<CredentialRow> for CredentialRecord {
    type Error = AppError;

    fn try_from(value: CredentialRow) -> Result<Self, Self::Error> {
        let credential_type = CredentialType::from_db(&value.credential_type)
            .ok_or_else(|| AppError::internal_server_error("internal server error"))?;

        Ok(Self {
            id: value.id,
            account_id: value.account_id,
            credential_type,
            identifier: value.identifier,
            password_hash: value.password_hash,
            metadata: value.metadata,
            verified_at: value.verified_at,
            created_at: value.created_at,
            updated_at: value.updated_at,
        })
    }
}
