use axum::{Extension, Json, extract::State, http::HeaderMap, response::IntoResponse};
use flash_auth::{
    SharedAuthStore, UpdateProfilePatch, password,
    store::{AccountAggregate, CredentialType},
};
use flash_core::{AppError, AppResult, SharedContext, jwt::extract_user_id, response::utf8_json};

use crate::model::{
    ChangePasswordRequest, MessageResponse, SetPasswordRequest, UpdateProfileRequest,
    UserProfileResponse,
};

pub async fn profile(
    State(context): State<SharedContext>,
    Extension(store): Extension<SharedAuthStore>,
    headers: HeaderMap,
) -> AppResult<impl IntoResponse> {
    let account = load_account_from_headers(context.as_ref(), store.as_ref(), &headers).await?;
    Ok(utf8_json(Json(map_profile(&account))))
}

pub async fn update_profile(
    State(context): State<SharedContext>,
    Extension(store): Extension<SharedAuthStore>,
    headers: HeaderMap,
    Json(request): Json<UpdateProfileRequest>,
) -> AppResult<impl IntoResponse> {
    let account_id = extract_user_id(context.as_ref(), &headers)?;
    let patch = UpdateProfilePatch {
        nickname: request.nickname.map(validate_nickname).transpose()?,
        avatar_url: request.avatar.map(validate_avatar).transpose()?,
        signature: request.signature.map(validate_signature).transpose()?,
    };
    let account = store
        .update_profile(account_id, patch)
        .await?
        .ok_or(AppError::not_found("user not found"))?;

    Ok(utf8_json(Json(map_profile(&account))))
}

pub async fn set_password(
    State(context): State<SharedContext>,
    Extension(store): Extension<SharedAuthStore>,
    headers: HeaderMap,
    Json(request): Json<SetPasswordRequest>,
) -> AppResult<impl IntoResponse> {
    let account = load_account_from_headers(context.as_ref(), store.as_ref(), &headers).await?;
    if store
        .find_password_credential_by_account_id(account.account.id)
        .await?
        .is_some()
    {
        return Err(AppError::conflict("password already set"));
    }

    let new_password = validate_password(request.new_password)?;
    let password_hash = password::hash_password(&new_password)
        .map_err(|_| AppError::internal_server_error("failed to hash password"))?;
    store
        .upsert_password_credential(
            account.account.id,
            &phone_identifier(&account),
            &password_hash,
        )
        .await?;

    Ok(utf8_json(Json(MessageResponse {
        message: "password set successfully".to_string(),
    })))
}

pub async fn change_password(
    State(context): State<SharedContext>,
    Extension(store): Extension<SharedAuthStore>,
    headers: HeaderMap,
    Json(request): Json<ChangePasswordRequest>,
) -> AppResult<impl IntoResponse> {
    let account = load_account_from_headers(context.as_ref(), store.as_ref(), &headers).await?;
    let old_password = validate_password(request.old_password)?;
    let new_password = validate_password(request.new_password)?;

    let credential = store
        .find_password_credential_by_account_id(account.account.id)
        .await?
        .ok_or(AppError::not_found("password is not set"))?;
    let current_hash = credential
        .password_hash
        .as_deref()
        .ok_or(AppError::not_found("password is not set"))?;
    let is_valid = password::verify_password(&old_password, current_hash)
        .map_err(|_| AppError::internal_server_error("failed to verify password"))?;
    if !is_valid {
        return Err(AppError::unauthorized("invalid old password"));
    }

    let password_hash = password::hash_password(&new_password)
        .map_err(|_| AppError::internal_server_error("failed to hash password"))?;
    store
        .upsert_password_credential(
            account.account.id,
            &phone_identifier(&account),
            &password_hash,
        )
        .await?;

    Ok(utf8_json(Json(MessageResponse {
        message: "password changed successfully".to_string(),
    })))
}

async fn load_account_from_headers(
    context: &flash_core::AppContext,
    store: &dyn flash_auth::AuthStore,
    headers: &HeaderMap,
) -> AppResult<AccountAggregate> {
    let account_id = extract_user_id(context, headers)?;
    store
        .find_account_by_id(account_id)
        .await?
        .ok_or(AppError::not_found("user not found"))
}

fn map_profile(account: &AccountAggregate) -> UserProfileResponse {
    UserProfileResponse {
        account_id: account.account.id,
        nickname: account.profile.nickname.clone(),
        avatar: account.profile.avatar_url.clone(),
        phone: phone_identifier(account),
        signature: account.profile.signature.clone(),
        has_password: account.credentials.iter().any(|credential| {
            matches!(credential.credential_type, CredentialType::Password)
                && credential.password_hash.is_some()
        }),
    }
}

fn phone_identifier(account: &AccountAggregate) -> String {
    account
        .credentials
        .iter()
        .find(|credential| matches!(credential.credential_type, CredentialType::Phone))
        .map(|credential| credential.identifier.clone())
        .unwrap_or_else(|| account.account.primary_identifier.clone())
}

fn validate_nickname(value: String) -> AppResult<String> {
    let trimmed = value.trim().to_string();
    if trimmed.is_empty() || trimmed.chars().count() > 50 {
        return Err(AppError::bad_request("invalid nickname"));
    }
    Ok(trimmed)
}

fn validate_avatar(value: String) -> AppResult<String> {
    let trimmed = value.trim().to_string();
    if trimmed.is_empty() {
        return Err(AppError::bad_request("invalid avatar"));
    }
    Ok(trimmed)
}

fn validate_signature(value: String) -> AppResult<String> {
    if value.chars().count() > 100 {
        return Err(AppError::bad_request("invalid signature"));
    }
    Ok(value)
}

fn validate_password(value: String) -> AppResult<String> {
    let trimmed = value.trim().to_string();
    if trimmed.chars().count() < 6 {
        return Err(AppError::bad_request("password is too short"));
    }
    Ok(trimmed)
}
