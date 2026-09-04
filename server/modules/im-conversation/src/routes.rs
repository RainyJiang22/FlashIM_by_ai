use std::sync::Arc;

use axum::{
    Extension, Json, Router,
    extract::{Path, Query, State},
    http::HeaderMap,
    response::IntoResponse,
    routing::{get, post},
};
use flash_core::{AppResult, SharedContext, jwt::extract_user_id, response::utf8_json};
use serde::Serialize;
use uuid::Uuid;

use crate::models::{ConversationListQuery, CreateConversationBody, JoinedGroupSearchQuery};
use crate::notification::GroupCreationNotifier;

async fn create_conversation<N>(
    State(context): State<SharedContext>,
    Extension(notifier): Extension<Arc<N>>,
    headers: HeaderMap,
    Json(body): Json<CreateConversationBody>,
) -> AppResult<impl IntoResponse>
where
    N: GroupCreationNotifier,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let conversation = crate::service::create_conversation(&context, user_id, body).await?;
    if let Err(error) = notifier
        .notify_group_created(&context, conversation.id, user_id)
        .await
    {
        let _ = crate::service::delete_created_group(&context, user_id, conversation.id).await;
        return Err(error);
    }
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

pub async fn get_private_conversation(
    State(context): State<SharedContext>,
    headers: HeaderMap,
    Path(peer_user_id): Path<i64>,
) -> AppResult<impl IntoResponse> {
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let conversation =
        crate::service::get_private_conversation(&context, user_id, peer_user_id).await?;
    Ok(utf8_json(Json(conversation)))
}

pub async fn search_joined_groups(
    State(context): State<SharedContext>,
    headers: HeaderMap,
    Query(query): Query<JoinedGroupSearchQuery>,
) -> AppResult<impl IntoResponse> {
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let conversations = crate::service::search_joined_groups(&context, user_id, query).await?;
    Ok(utf8_json(Json(conversations)))
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

pub async fn hide_conversation_from_list(
    State(context): State<SharedContext>,
    headers: HeaderMap,
    Path(conversation_id): Path<Uuid>,
) -> AppResult<impl IntoResponse> {
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    crate::service::hide_from_list(&context, user_id, conversation_id).await?;
    Ok(utf8_json(Json(HideConversationResponse {
        message: "conversation hidden from list",
    })))
}

#[derive(Serialize)]
struct HideConversationResponse {
    message: &'static str,
}

pub fn router_with_notifier<N>(notifier: Arc<N>) -> Router<SharedContext>
where
    N: GroupCreationNotifier + 'static,
{
    Router::new()
        .route(
            "/conversations",
            get(list_conversations).post(create_conversation::<N>),
        )
        .route(
            "/api/conversations/search-joined-groups",
            get(search_joined_groups),
        )
        .route(
            "/conversations/private/{peer_user_id}",
            get(get_private_conversation),
        )
        .route(
            "/conversations/{id}",
            get(get_conversation).delete(hide_conversation_from_list),
        )
        .route("/conversations/{id}/read", post(mark_conversation_read))
        .layer(Extension(notifier))
}
