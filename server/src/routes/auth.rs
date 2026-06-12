use axum::{Json, extract::State, http::HeaderMap, response::IntoResponse};

use crate::{
    auth::jwt::extract_token,
    error::AppError,
    error::AppResult,
    models::auth::{ChangePasswordRequest, LoginRequest, SetPasswordRequest, SmsRequest},
    response::utf8_json,
    services::auth_service,
    state::SharedState,
};

pub async fn send_sms_code(
    State(state): State<SharedState>,
    Json(request): Json<SmsRequest>,
) -> AppResult<impl IntoResponse> {
    let response = auth_service::issue_sms_code(state.as_ref(), &request.phone).await?;
    Ok(utf8_json(Json(response)))
}

pub async fn login(
    State(state): State<SharedState>,
    Json(request): Json<LoginRequest>,
) -> AppResult<impl IntoResponse> {
    let response = auth_service::login(state.as_ref(), request).await?;
    Ok(utf8_json(Json(response)))
}

pub async fn set_password(
    State(state): State<SharedState>,
    headers: HeaderMap,
    Json(request): Json<SetPasswordRequest>,
) -> AppResult<impl IntoResponse> {
    let token = extract_token(&headers).ok_or(AppError::unauthorized("missing token"))?;
    let response = auth_service::set_password(state.as_ref(), token, request).await?;
    Ok(utf8_json(Json(response)))
}

pub async fn change_password(
    State(state): State<SharedState>,
    headers: HeaderMap,
    Json(request): Json<ChangePasswordRequest>,
) -> AppResult<impl IntoResponse> {
    let token = extract_token(&headers).ok_or(AppError::unauthorized("missing token"))?;
    let response = auth_service::change_password(state.as_ref(), token, request).await?;
    Ok(utf8_json(Json(response)))
}
