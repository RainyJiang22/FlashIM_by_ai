use rand::Rng;

use crate::{
    error::{AppError, AppResult},
    models::user::UserRecord,
    state::AppState,
    store::{AccountAggregate, CredentialType, NewProfile},
};

pub(crate) async fn find_or_create_account_by_phone(
    state: &AppState,
    phone: &str,
) -> AppResult<UserRecord> {
    if let Some(account) = state
        .auth_store
        .find_account_by_credential(CredentialType::Phone, phone)
        .await?
    {
        return account_to_user_record(account);
    }

    let account = state
        .auth_store
        .create_account_with_phone(
            phone,
            NewProfile {
                nickname: phone.to_string(),
                avatar_url: random_avatar_url(),
                bio: String::new(),
            },
        )
        .await?;

    account_to_user_record(account)
}

pub(crate) async fn load_user_by_account_id(
    state: &AppState,
    account_id: i64,
) -> AppResult<UserRecord> {
    let Some(account) = state.auth_store.find_account_by_id(account_id).await? else {
        return Err(AppError::unauthorized("invalid token"));
    };

    account_to_user_record(account)
}

fn account_to_user_record(account: AccountAggregate) -> AppResult<UserRecord> {
    let phone = account
        .credentials
        .iter()
        .find(|credential| matches!(credential.credential_type, CredentialType::Phone))
        .map(|credential| credential.identifier.clone())
        .unwrap_or_else(|| account.account.primary_identifier.clone());

    Ok(UserRecord {
        account_id: account.account.id,
        nickname: account.profile.nickname,
        avatar: account.profile.avatar_url,
        phone,
        has_password: account.credentials.iter().any(|credential| {
            matches!(credential.credential_type, CredentialType::Password)
                && credential.password_hash.is_some()
        }),
    })
}

fn random_avatar_url() -> String {
    let mut rng = rand::rng();
    let seed = rng.random::<u64>();
    format!("https://picsum.photos/seed/{seed}/120/120")
}
