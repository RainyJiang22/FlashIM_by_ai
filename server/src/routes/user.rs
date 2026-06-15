use axum::{Extension, Json, extract::State, http::HeaderMap, response::IntoResponse};
use flash_auth::{jwt::extract_token, services::auth_service, store::SharedAuthStore};
use flash_core::{AppError, AppResult, SharedContext, response::utf8_json};

use crate::models::user::ProfileResponse;

pub async fn user_profile(
    State(context): State<SharedContext>,
    Extension(store): Extension<SharedAuthStore>,
    headers: HeaderMap,
) -> AppResult<impl IntoResponse> {
    let token = extract_token(&headers).ok_or(AppError::unauthorized("missing token"))?;
    let user = auth_service::authenticate_user(context.as_ref(), store.as_ref(), token).await?;
    let profile = ProfileResponse {
        account_id: user.account_id,
        nickname: user.nickname,
        avatar: user.avatar,
        phone: user.phone,
        has_password: user.has_password,
    };
    Ok(utf8_json(Json(profile)))
}
