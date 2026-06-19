use axum::{Extension, Json, extract::State, response::IntoResponse};
use flash_core::{AppResult, SharedContext, response::utf8_json};

use crate::{
    models::auth::{LoginRequest, SmsRequest},
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
