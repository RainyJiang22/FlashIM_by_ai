use flash_core::{AppError, AppResult};

use crate::{
    models::user::UserRecord,
    store::{AccountAggregate, AuthStore, CredentialType, NewProfile},
};

pub async fn find_or_create_account_by_phone(
    store: &dyn AuthStore,
    phone: &str,
) -> AppResult<UserRecord> {
    if let Some(account) = store
        .find_account_by_credential(CredentialType::Phone, phone)
        .await?
    {
        return Ok(account_to_user_record(account));
    }

    let account = store
        .create_account_with_phone(
            phone,
            NewProfile {
                nickname: phone.to_string(),
                avatar_url: None,
                signature: String::new(),
                bio: String::new(),
            },
        )
        .await?;

    Ok(account_to_user_record(account))
}

pub async fn load_user_by_account_id(
    store: &dyn AuthStore,
    account_id: i64,
) -> AppResult<UserRecord> {
    let Some(account) = store.find_account_by_id(account_id).await? else {
        return Err(AppError::unauthorized("invalid token"));
    };

    Ok(account_to_user_record(account))
}

fn account_to_user_record(account: AccountAggregate) -> UserRecord {
    let phone = account
        .credentials
        .iter()
        .find(|credential| matches!(credential.credential_type, CredentialType::Phone))
        .map(|credential| credential.identifier.clone())
        .unwrap_or_else(|| account.account.primary_identifier.clone());

    UserRecord {
        account_id: account.account.id,
        nickname: account.profile.nickname,
        avatar: account.profile.avatar_url,
        phone,
        signature: account.profile.signature,
        has_password: account.credentials.iter().any(|credential| {
            matches!(credential.credential_type, CredentialType::Password)
                && credential.password_hash.is_some()
        }),
    }
}
