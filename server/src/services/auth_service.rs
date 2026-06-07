use rand::Rng;

use crate::{
    auth::jwt::{decode_token, sign_token},
    error::{AppError, AppResult},
    models::{
        auth::{LoginRequest, LoginResponse, LoginType, SmsResponse},
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
    state.store.save_sms_code(phone.clone(), code.clone()).await;

    Ok(SmsResponse { phone, code })
}

pub(crate) async fn login(state: &AppState, request: LoginRequest) -> AppResult<LoginResponse> {
    let user = match request.login_type {
        LoginType::SmsCode => {
            login_with_sms_code(state, request.phone.as_deref(), request.code.as_deref()).await?
        }
        LoginType::Password => {
            login_with_password(
                state,
                request.account.as_deref(),
                request.password.as_deref(),
            )
            .await?
        }
    };

    let token = sign_token(state, user.user_id).map_err(|error| {
        println!("jwt sign failed: user_id={}, error={error}", user.user_id);
        AppError::internal_server_error("failed to sign token")
    })?;

    Ok(LoginResponse {
        token,
        user_id: user.user_id,
    })
}

async fn login_with_sms_code(
    state: &AppState,
    phone: Option<&str>,
    code: Option<&str>,
) -> AppResult<UserRecord> {
    let phone = required_field(phone, "phone and code are required")?;
    let code = required_field(code, "phone and code are required")?;

    if !state.store.consume_sms_code(&phone, &code).await {
        return Err(AppError::unauthorized("invalid or expired code"));
    }

    Ok(user_service::find_or_create_user(state, &phone).await)
}

async fn login_with_password(
    state: &AppState,
    account: Option<&str>,
    password: Option<&str>,
) -> AppResult<UserRecord> {
    let account = required_field(account, "account and password are required")?;
    let password = required_field(password, "account and password are required")?;

    state
        .store
        .verify_password_account(&account, &password)
        .await
        .ok_or(AppError::unauthorized("invalid account or password"))
}

pub(crate) async fn load_profile(state: &AppState, token: &str) -> AppResult<ProfileResponse> {
    let user = authenticate_user(state, token).await?;
    Ok(ProfileResponse {
        user_id: user.user_id,
        nickname: user.nickname,
        avatar: user.avatar,
        phone: user.phone,
    })
}

pub(crate) async fn authenticate_user(state: &AppState, token: &str) -> AppResult<UserRecord> {
    let claims = decode_token(state, token).map_err(|_| AppError::unauthorized("invalid token"))?;
    state
        .store
        .user_by_id(claims.user_id)
        .await
        .ok_or(AppError::unauthorized("invalid token"))
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
