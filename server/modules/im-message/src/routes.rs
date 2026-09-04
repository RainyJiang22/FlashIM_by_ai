use std::sync::Arc;

use axum::{
    Json, Router,
    extract::{Path, Query, State},
    http::HeaderMap,
    response::IntoResponse,
    routing::get,
};
use flash_core::{AppResult, SharedContext, jwt::extract_user_id, response::utf8_json};
use uuid::Uuid;

use crate::{
    broadcast::NoopBroadcaster,
    models::{ConversationMessageSearchQuery, GlobalMessageSearchQuery, MessageQuery},
    service::{MessageService, SendMessageInput},
};

pub async fn search_messages(
    State(context): State<SharedContext>,
    headers: HeaderMap,
    Query(query): Query<GlobalMessageSearchQuery>,
) -> AppResult<impl IntoResponse> {
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let service = MessageService::new(Arc::new(NoopBroadcaster));
    let messages = service.search_messages(&context, user_id, query).await?;
    Ok(utf8_json(Json(messages)))
}

pub async fn search_conversation_messages(
    State(context): State<SharedContext>,
    headers: HeaderMap,
    Path(conversation_id): Path<Uuid>,
    Query(query): Query<ConversationMessageSearchQuery>,
) -> AppResult<impl IntoResponse> {
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let service = MessageService::new(Arc::new(NoopBroadcaster));
    let messages = service
        .search_conversation_messages(&context, user_id, conversation_id, query)
        .await?;
    Ok(utf8_json(Json(messages)))
}

pub async fn list_messages(
    State(context): State<SharedContext>,
    headers: HeaderMap,
    Path(conversation_id): Path<Uuid>,
    Query(query): Query<MessageQuery>,
) -> AppResult<impl IntoResponse> {
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let service = MessageService::new(Arc::new(NoopBroadcaster));
    let messages = service
        .get_history(&context, user_id, conversation_id, query)
        .await?;

    Ok(utf8_json(Json(messages)))
}

pub async fn get_message_read_status(
    State(context): State<SharedContext>,
    headers: HeaderMap,
    Path((conversation_id, message_id)): Path<(Uuid, Uuid)>,
) -> AppResult<impl IntoResponse> {
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let service = MessageService::new(Arc::new(NoopBroadcaster));
    let status = service
        .get_read_status(&context, user_id, conversation_id, message_id)
        .await?;
    Ok(utf8_json(Json(status)))
}

pub fn router() -> Router<SharedContext> {
    Router::new()
        .route("/api/messages/search", get(search_messages))
        .route("/conversations/{id}/messages", get(list_messages))
        .route(
            "/conversations/{id}/messages/search",
            get(search_conversation_messages),
        )
        .route(
            "/conversations/{conversation_id}/messages/{message_id}/read-status",
            get(get_message_read_status),
        )
}

#[allow(dead_code)]
pub async fn send_message_for_ws<B>(
    context: &SharedContext,
    service: &MessageService<B>,
    input: SendMessageInput,
) -> AppResult<crate::service::SendMessageOutput>
where
    B: crate::broadcast::MessageBroadcaster,
{
    service.send(context, input).await
}
