use chrono::Utc;
use flash_core::{AppContext, AppError, AppResult};
use rand::Rng;

use crate::{
    jwt::{decode_token, sign_token},
    models::auth::{LoginRequest, LoginResponse, LoginType, SmsResponse},
    password,
    services::user_service,
    store::AuthStore,
};

pub async fn issue_sms_code(
    context: &AppContext,
    store: &dyn AuthStore,
    phone: &str,
) -> AppResult<SmsResponse> {
    let phone = phone.trim().to_string();
    if phone.is_empty() {
        return Err(AppError::bad_request("phone is required"));
    }

    let code = random_sms_code();
    store
        .save_sms_code(&phone, &code, "login", Utc::now() + context.sms_code_ttl)
        .await?;

    Ok(SmsResponse {
        phone,
        code: if context.expose_debug_sms_code {
            code
        } else {
            String::new()
        },
    })
}

pub async fn login(
    context: &AppContext,
    store: &dyn AuthStore,
    request: LoginRequest,
) -> AppResult<LoginResponse> {
    let user = match request.login_type {
        LoginType::SmsCode => {
            login_with_sms_code(store, request.phone.as_deref(), request.code.as_deref()).await?
        }
        LoginType::Password => {
            login_with_password(
                store,
                request.identifier.as_deref(),
                request.password.as_deref(),
            )
            .await?
        }
    };

    let token = sign_token(context, user.account_id).map_err(|error| {
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
    store: &dyn AuthStore,
    phone: Option<&str>,
    code: Option<&str>,
) -> AppResult<crate::models::user::UserRecord> {
    let phone = required_field(phone, "phone and code are required")?;
    let code = required_field(code, "phone and code are required")?;

    if !store.consume_sms_code(&phone, &code, "login").await? {
        return Err(AppError::unauthorized("invalid or expired code"));
    }

    user_service::find_or_create_account_by_phone(store, &phone).await
}

async fn login_with_password(
    store: &dyn AuthStore,
    identifier: Option<&str>,
    password: Option<&str>,
) -> AppResult<crate::models::user::UserRecord> {
    let identifier = required_field(identifier, "identifier and password are required")?;
    let password = required_field(password, "identifier and password are required")?;

    let credential = store
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

    user_service::load_user_by_account_id(store, credential.account_id).await
}

pub async fn authenticate_user(
    context: &AppContext,
    store: &dyn AuthStore,
    token: &str,
) -> AppResult<crate::models::user::UserRecord> {
    let claims =
        decode_token(context, token).map_err(|_| AppError::unauthorized("invalid token"))?;
    user_service::load_user_by_account_id(store, claims.account_id).await
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
