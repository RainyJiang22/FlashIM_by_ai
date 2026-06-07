use axum::{Json, extract::State, http::HeaderMap, response::IntoResponse};

use crate::{
    auth::jwt::extract_token,
    error::{AppError, AppResult},
    response::utf8_json,
    services::auth_service,
    state::SharedState,
};

pub async fn user_profile(
    State(state): State<SharedState>,
    headers: HeaderMap,
) -> AppResult<impl IntoResponse> {
    let token = extract_token(&headers).ok_or(AppError::unauthorized("missing token"))?;
    let profile = auth_service::load_profile(state.as_ref(), token).await?;
    Ok(utf8_json(Json(profile)))
}
