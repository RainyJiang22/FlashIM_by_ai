use chrono::Utc;
use rand::Rng;

use crate::{
    auth::{
        jwt::{decode_token, sign_token},
        password,
    },
    error::{AppError, AppResult},
    models::{
        auth::{
            ChangePasswordRequest, LoginRequest, LoginResponse, LoginType, PasswordUpdatedResponse,
            SetPasswordRequest, SetPasswordResponse, SmsResponse,
        },
        user::{ProfileResponse, UserRecord},
    },
    services::user_service,
    state::AppState,
};

pub(crate) async fn issue_sms_code(state: &AppState, phone: &str) -> AppResult<SmsResponse> {
    let phone = phone.trim().to_string();
    if phone.is_empty() {
        return Err(AppError::bad_request("phone is required"));
    }

    let code = random_sms_code();
    state
        .auth_store
        .save_sms_code(&phone, &code, "login", Utc::now() + state.sms_code_ttl)
        .await?;

    Ok(SmsResponse {
        phone,
        code: if state.expose_debug_sms_code {
            code
        } else {
            String::new()
        },
    })
}

pub(crate) async fn login(state: &AppState, request: LoginRequest) -> AppResult<LoginResponse> {
    let user = match request.login_type {
        LoginType::SmsCode => {
            login_with_sms_code(state, request.phone.as_deref(), request.code.as_deref()).await?
        }
        LoginType::Password => {
            login_with_password(
                state,
                request.identifier.as_deref(),
                request.password.as_deref(),
            )
            .await?
        }
    };

    let token = sign_token(state, user.account_id).map_err(|error| {
        println!(
            "jwt sign failed: account_id={}, error={error}",
            user.account_id
        );
        AppError::internal_server_error("failed to sign token")
    })?;

    Ok(LoginResponse {
        token,
        account_id: user.account_id,
        password_setup_required: !user.has_password,
    })
}

async fn login_with_sms_code(
    state: &AppState,
    phone: Option<&str>,
    code: Option<&str>,
) -> AppResult<UserRecord> {
    let phone = required_field(phone, "phone and code are required")?;
    let code = required_field(code, "phone and code are required")?;

    if !state
        .auth_store
        .consume_sms_code(&phone, &code, "login")
        .await?
    {
        return Err(AppError::unauthorized("invalid or expired code"));
    }

    user_service::find_or_create_account_by_phone(state, &phone).await
}

async fn login_with_password(
    state: &AppState,
    identifier: Option<&str>,
    password: Option<&str>,
) -> AppResult<UserRecord> {
    let identifier = required_field(identifier, "identifier and password are required")?;
    let password = required_field(password, "identifier and password are required")?;

    let credential = state
        .auth_store
        .find_password_credential_by_identifier(&identifier)
        .await?
        .ok_or(AppError::unauthorized("invalid phone or password"))?;

    let stored_hash = credential
        .password_hash
        .as_deref()
        .ok_or(AppError::unauthorized("invalid phone or password"))?;
    let is_valid = password::verify_password(&password, stored_hash).map_err(|error| {
        println!(
            "password verify failed: account_id={}, error={error}",
            credential.account_id
        );
        AppError::internal_server_error("internal server error")
    })?;
    if !is_valid {
        return Err(AppError::unauthorized("invalid phone or password"));
    }

    user_service::load_user_by_account_id(state, credential.account_id).await
}

pub(crate) async fn load_profile(state: &AppState, token: &str) -> AppResult<ProfileResponse> {
    let user = authenticate_user(state, token).await?;
    Ok(ProfileResponse {
        account_id: user.account_id,
        nickname: user.nickname,
        avatar: user.avatar,
        phone: user.phone,
        has_password: user.has_password,
    })
}

pub(crate) async fn authenticate_user(state: &AppState, token: &str) -> AppResult<UserRecord> {
    let claims = decode_token(state, token).map_err(|_| AppError::unauthorized("invalid token"))?;
    user_service::load_user_by_account_id(state, claims.account_id).await
}

pub(crate) async fn set_password(
    state: &AppState,
    token: &str,
    request: SetPasswordRequest,
) -> AppResult<SetPasswordResponse> {
    let user = authenticate_user(state, token).await?;
    if user.has_password {
        return Err(AppError::conflict("password already set"));
    }

    let new_password = required_nonempty(request.new_password, "new_password is required")?;
    let password_hash = password::hash_password(&new_password).map_err(|error| {
        println!(
            "password hash failed: account_id={}, error={error}",
            user.account_id
        );
        AppError::internal_server_error("internal server error")
    })?;
    let updated_at = state
        .auth_store
        .upsert_password_credential(user.account_id, &user.phone, &password_hash)
        .await?;

    Ok(SetPasswordResponse {
        password_setup_required: false,
        updated_at,
    })
}

pub(crate) async fn change_password(
    state: &AppState,
    token: &str,
    request: ChangePasswordRequest,
) -> AppResult<PasswordUpdatedResponse> {
    let user = authenticate_user(state, token).await?;
    let old_password = required_nonempty(request.old_password, "old_password is required")?;
    let new_password = required_nonempty(request.new_password, "new_password is required")?;

    let credential = state
        .auth_store
        .find_password_credential_by_account_id(user.account_id)
        .await?
        .ok_or(AppError::conflict("password is not set"))?;

    let current_hash = credential
        .password_hash
        .as_deref()
        .ok_or(AppError::conflict("password is not set"))?;
    let is_valid = password::verify_password(&old_password, current_hash).map_err(|error| {
        println!(
            "password verify failed: account_id={}, error={error}",
            user.account_id
        );
        AppError::internal_server_error("internal server error")
    })?;
    if !is_valid {
        return Err(AppError::unauthorized("invalid old password"));
    }

    let new_hash = password::hash_password(&new_password).map_err(|error| {
        println!(
            "password hash failed: account_id={}, error={error}",
            user.account_id
        );
        AppError::internal_server_error("internal server error")
    })?;
    let updated_at = state
        .auth_store
        .upsert_password_credential(user.account_id, &credential.identifier, &new_hash)
        .await?;

    Ok(PasswordUpdatedResponse { updated_at })
}

fn random_sms_code() -> String {
    let mut rng = rand::rng();
    format!("{:06}", rng.random_range(0..1_000_000))
}

fn required_field(value: Option<&str>, message: &'static str) -> AppResult<String> {
    let value = value.unwrap_or_default().trim().to_string();
    if value.is_empty() {
        return Err(AppError::bad_request(message));
    }
    Ok(value)
}

fn required_nonempty(value: String, message: &'static str) -> AppResult<String> {
    let trimmed = value.trim().to_string();
    if trimmed.is_empty() {
        return Err(AppError::bad_request(message));
    }
    Ok(trimmed)
}
