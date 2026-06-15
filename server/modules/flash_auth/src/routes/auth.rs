use axum::{Extension, Json, extract::State, http::HeaderMap, response::IntoResponse};
use flash_core::{AppError, AppResult, SharedContext, response::utf8_json};

use crate::{
    jwt::extract_token,
    models::auth::{ChangePasswordRequest, LoginRequest, SetPasswordRequest, SmsRequest},
    services::auth_service,
    store::SharedAuthStore,
};

pub async fn send_sms_code(
    State(context): State<SharedContext>,
    Extension(store): Extension<SharedAuthStore>,
    Json(request): Json<SmsRequest>,
) -> AppResult<impl IntoResponse> {
    let response =
        auth_service::issue_sms_code(context.as_ref(), store.as_ref(), &request.phone).await?;
    Ok(utf8_json(Json(response)))
}

pub async fn login(
    State(context): State<SharedContext>,
    Extension(store): Extension<SharedAuthStore>,
    Json(request): Json<LoginRequest>,
) -> AppResult<impl IntoResponse> {
    let response = auth_service::login(context.as_ref(), store.as_ref(), request).await?;
    Ok(utf8_json(Json(response)))
}

pub async fn set_password(
    State(context): State<SharedContext>,
    Extension(store): Extension<SharedAuthStore>,
    headers: HeaderMap,
    Json(request): Json<SetPasswordRequest>,
) -> AppResult<impl IntoResponse> {
    let token = extract_token(&headers).ok_or(AppError::unauthorized("missing token"))?;
    let response =
        auth_service::set_password(context.as_ref(), store.as_ref(), token, request).await?;
    Ok(utf8_json(Json(response)))
}

pub async fn change_password(
    State(context): State<SharedContext>,
    Extension(store): Extension<SharedAuthStore>,
    headers: HeaderMap,
    Json(request): Json<ChangePasswordRequest>,
) -> AppResult<impl IntoResponse> {
    let token = extract_token(&headers).ok_or(AppError::unauthorized("missing token"))?;
    let response =
        auth_service::change_password(context.as_ref(), store.as_ref(), token, request).await?;
    Ok(utf8_json(Json(response)))
}
