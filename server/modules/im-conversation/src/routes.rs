use axum::{
    Json, Router,
    extract::{Path, Query, State},
    http::HeaderMap,
    response::IntoResponse,
    routing::{get, post},
};
use flash_core::{AppResult, SharedContext, jwt::extract_user_id, response::utf8_json};
use serde::Serialize;
use uuid::Uuid;

use crate::models::{ConversationListQuery, CreateConversationBody};

pub async fn create_conversation(
    State(context): State<SharedContext>,
    headers: HeaderMap,
    Json(body): Json<CreateConversationBody>,
) -> AppResult<impl IntoResponse> {
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let conversation = crate::service::create_conversation(&context, user_id, body).await?;
    Ok(utf8_json(Json(conversation)))
}

pub async fn list_conversations(
    State(context): State<SharedContext>,
    headers: HeaderMap,
    Query(query): Query<ConversationListQuery>,
) -> AppResult<impl IntoResponse> {
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let conversations = crate::service::list_conversations(&context, user_id, query).await?;
    Ok(utf8_json(Json(conversations)))
}

pub async fn get_conversation(
    State(context): State<SharedContext>,
    headers: HeaderMap,
    Path(conversation_id): Path<Uuid>,
) -> AppResult<impl IntoResponse> {
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let conversation =
        crate::service::get_conversation_by_id(&context, user_id, conversation_id).await?;
    Ok(utf8_json(Json(conversation)))
}

pub async fn mark_conversation_read(
    State(context): State<SharedContext>,
    headers: HeaderMap,
    Path(conversation_id): Path<Uuid>,
) -> AppResult<impl IntoResponse> {
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    crate::service::mark_read(&context, user_id, conversation_id).await?;
    Ok(utf8_json(Json(MarkReadResponse {
        message: "conversation marked as read",
    })))
}

#[derive(Serialize)]
struct MarkReadResponse {
    message: &'static str,
}

pub fn router() -> Router<SharedContext> {
    Router::new()
        .route(
            "/conversations",
            get(list_conversations).post(create_conversation),
        )
        .route("/conversations/{id}", get(get_conversation))
        .route("/conversations/{id}/read", post(mark_conversation_read))
}
