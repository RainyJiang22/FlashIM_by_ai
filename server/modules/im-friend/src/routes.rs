use std::sync::Arc;

use axum::{
    Extension, Json, Router,
    extract::{Path, Query, State},
    http::HeaderMap,
    response::IntoResponse,
    routing::{delete, get, post},
};
use flash_core::{AppResult, SharedContext, jwt::extract_user_id, response::utf8_json};
use im_message::broadcast::MessageBroadcaster;
use uuid::Uuid;

use crate::{
    broadcast::{FriendBroadcaster, NoopFriendBroadcaster},
    models::{FriendRequestListQuery, FriendSearchQuery, SendFriendRequestBody, UserSearchQuery},
    service::FriendService,
};

pub fn router() -> Router<SharedContext> {
    router_with_broadcaster(Arc::new(NoopFriendBroadcaster))
}

pub fn router_with_broadcaster<B>(broadcaster: Arc<B>) -> Router<SharedContext>
where
    B: FriendBroadcaster + MessageBroadcaster + 'static,
{
    Router::new()
        .route("/api/friends/requests", post(send_request::<B>))
        .route(
            "/api/friends/requests/received",
            get(list_received_requests::<B>),
        )
        .route("/api/friends/requests/sent", get(list_sent_requests::<B>))
        .route(
            "/api/friends/requests/{id}/accept",
            post(accept_request::<B>),
        )
        .route(
            "/api/friends/requests/{id}/reject",
            post(reject_request::<B>),
        )
        .route("/api/friends/requests/{id}", delete(delete_request::<B>))
        .route("/api/friends", get(list_friends::<B>))
        .route("/api/friends/search", get(search_friends::<B>))
        .route("/api/friends/{friend_user_id}", delete(remove_friend::<B>))
        .route("/api/users/search", get(search_users::<B>))
        .route("/api/users/{account_id}", get(get_public_user::<B>))
        .layer(Extension(broadcaster))
}

async fn send_request<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Json(body): Json<SendFriendRequestBody>,
) -> AppResult<impl IntoResponse>
where
    B: FriendBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let service = FriendService::new(broadcaster);
    let response = service.send_request(&context, user_id, body).await?;
    Ok(utf8_json(Json(response)))
}

async fn list_received_requests<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Query(query): Query<FriendRequestListQuery>,
) -> AppResult<impl IntoResponse>
where
    B: FriendBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let service = FriendService::new(broadcaster);
    let response = service
        .list_received_requests(&context, user_id, query)
        .await?;
    Ok(utf8_json(Json(response)))
}

async fn list_sent_requests<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Query(query): Query<FriendRequestListQuery>,
) -> AppResult<impl IntoResponse>
where
    B: FriendBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let service = FriendService::new(broadcaster);
    let response = service.list_sent_requests(&context, user_id, query).await?;
    Ok(utf8_json(Json(response)))
}

async fn accept_request<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Path(request_id): Path<Uuid>,
) -> AppResult<impl IntoResponse>
where
    B: FriendBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let service = FriendService::new(broadcaster);
    let response = service
        .accept_request(&context, user_id, request_id)
        .await?;
    Ok(utf8_json(Json(response)))
}

async fn reject_request<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Path(request_id): Path<Uuid>,
) -> AppResult<impl IntoResponse>
where
    B: FriendBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let service = FriendService::new(broadcaster);
    let response = service
        .reject_request(&context, user_id, request_id)
        .await?;
    Ok(utf8_json(Json(response)))
}

async fn delete_request<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Path(request_id): Path<Uuid>,
) -> AppResult<impl IntoResponse>
where
    B: FriendBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let service = FriendService::new(broadcaster);
    let response = service
        .delete_request(&context, user_id, request_id)
        .await?;
    Ok(utf8_json(Json(response)))
}

async fn list_friends<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
) -> AppResult<impl IntoResponse>
where
    B: FriendBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let service = FriendService::new(broadcaster);
    let response = service.list_friends(&context, user_id).await?;
    Ok(utf8_json(Json(response)))
}

async fn remove_friend<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Path(friend_user_id): Path<i64>,
) -> AppResult<impl IntoResponse>
where
    B: FriendBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let service = FriendService::new(broadcaster);
    let response = service
        .remove_friend(&context, user_id, friend_user_id)
        .await?;
    Ok(utf8_json(Json(response)))
}

async fn search_friends<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Query(query): Query<FriendSearchQuery>,
) -> AppResult<impl IntoResponse>
where
    B: FriendBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let service = FriendService::new(broadcaster);
    let response = service.search_friends(&context, user_id, query).await?;
    Ok(utf8_json(Json(response)))
}

async fn search_users<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Query(query): Query<UserSearchQuery>,
) -> AppResult<impl IntoResponse>
where
    B: FriendBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let service = FriendService::new(broadcaster);
    let response = service.search_users(&context, user_id, query).await?;
    Ok(utf8_json(Json(response)))
}

async fn get_public_user<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Path(account_id): Path<i64>,
) -> AppResult<impl IntoResponse>
where
    B: FriendBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let service = FriendService::new(broadcaster);
    let response = service
        .get_public_user(&context, user_id, account_id)
        .await?;
    Ok(utf8_json(Json(response)))
}
