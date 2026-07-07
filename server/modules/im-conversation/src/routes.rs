use axum::{
    Json, Router,
    extract::{Query, State},
    http::HeaderMap,
    response::IntoResponse,
    routing::get,
};
use flash_core::{AppResult, SharedContext, jwt::extract_user_id, response::utf8_json};

use crate::models::ConversationListQuery;

pub async fn list_conversations(
    State(context): State<SharedContext>,
    headers: HeaderMap,
    Query(query): Query<ConversationListQuery>,
) -> AppResult<impl IntoResponse> {
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let conversations = crate::service::list_conversations(&context, user_id, query).await?;
    Ok(utf8_json(Json(conversations)))
}

pub fn router() -> Router<SharedContext> {
    Router::new().route("/conversations", get(list_conversations))
}
