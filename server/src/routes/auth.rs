use axum::{Json, extract::State, response::IntoResponse};

use crate::{
    error::AppResult,
    models::auth::{LoginRequest, SmsRequest},
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
