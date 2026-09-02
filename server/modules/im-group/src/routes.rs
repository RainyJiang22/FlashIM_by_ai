use std::sync::Arc;

use axum::{
    Extension, Json, Router,
    extract::{Path, Query, State},
    http::HeaderMap,
    response::IntoResponse,
    routing::{delete, get, patch, post},
};
use flash_core::{AppResult, SharedContext, jwt::extract_user_id, response::utf8_json};
use im_message::broadcast::MessageBroadcaster;
use uuid::Uuid;

use crate::{
    broadcast::{GroupBroadcaster, NoopGroupBroadcaster},
    models::{
        GroupActionResponse, GroupMemberIdsBody, GroupSearchQuery, HandleJoinRequestBody,
        JoinGroupBody, TransferGroupOwnerBody, UpdateGroupAnnouncementBody, UpdateGroupNameBody,
        UpdateGroupNicknameBody, UpdateGroupSettingsBody,
    },
    service::GroupService,
};

pub fn router() -> Router<SharedContext> {
    router_with_broadcaster(Arc::new(NoopGroupBroadcaster))
}

pub fn router_with_broadcaster<B>(broadcaster: Arc<B>) -> Router<SharedContext>
where
    B: GroupBroadcaster + MessageBroadcaster + 'static,
{
    Router::new()
        .route("/groups/search", get(search_groups::<B>))
        .route("/groups/join-requests", get(list_join_requests::<B>))
        .route("/groups/{id}/join", post(join_group::<B>))
        .route(
            "/groups/{id}/join-requests/{request_id}/handle",
            post(handle_join_request::<B>),
        )
        .route(
            "/groups/{id}",
            get(get_group::<B>).delete(dissolve_group::<B>),
        )
        .route("/groups/{id}/name", patch(update_group_name::<B>))
        .route("/groups/{id}/nickname", patch(update_group_nickname::<B>))
        .route("/groups/{id}/owner", patch(transfer_group_owner::<B>))
        .route(
            "/groups/{id}/announcement",
            patch(update_group_announcement::<B>),
        )
        .route("/groups/{id}/leave", post(leave_group::<B>))
        .route("/groups/{id}/settings", patch(update_group_settings::<B>))
        .route("/groups/{id}/members", post(add_group_members::<B>))
        .route(
            "/groups/{id}/members/{member_id}",
            delete(remove_group_member::<B>),
        )
        .route("/groups/{id}/invitations", post(invite_group_members::<B>))
        .route(
            "/group-invitations/{id}/accept",
            post(accept_group_invitation::<B>),
        )
        .layer(Extension(broadcaster))
}

async fn search_groups<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Query(query): Query<GroupSearchQuery>,
) -> AppResult<impl IntoResponse>
where
    B: GroupBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let response = GroupService::new(broadcaster)
        .search(&context, user_id, &query.keyword)
        .await?;
    Ok(utf8_json(Json(response)))
}

async fn join_group<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Path(conversation_id): Path<Uuid>,
    Json(body): Json<JoinGroupBody>,
) -> AppResult<impl IntoResponse>
where
    B: GroupBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let response = GroupService::new(broadcaster)
        .join(&context, user_id, conversation_id, body)
        .await?;
    Ok(utf8_json(Json(response)))
}

async fn list_join_requests<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
) -> AppResult<impl IntoResponse>
where
    B: GroupBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let response = GroupService::new(broadcaster)
        .list_join_requests(&context, user_id)
        .await?;
    Ok(utf8_json(Json(response)))
}

async fn handle_join_request<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Path((conversation_id, request_id)): Path<(Uuid, Uuid)>,
    Json(body): Json<HandleJoinRequestBody>,
) -> AppResult<impl IntoResponse>
where
    B: GroupBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let response = GroupService::new(broadcaster)
        .handle_join_request(&context, user_id, conversation_id, request_id, body)
        .await?;
    Ok(utf8_json(Json(response)))
}

async fn get_group<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Path(conversation_id): Path<Uuid>,
) -> AppResult<impl IntoResponse>
where
    B: GroupBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let detail = GroupService::new(broadcaster)
        .get_detail(&context, user_id, conversation_id)
        .await?;
    Ok(utf8_json(Json(detail)))
}

async fn update_group_name<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Path(conversation_id): Path<Uuid>,
    Json(body): Json<UpdateGroupNameBody>,
) -> AppResult<impl IntoResponse>
where
    B: GroupBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let detail = GroupService::new(broadcaster)
        .update_name(&context, user_id, conversation_id, body)
        .await?;
    Ok(utf8_json(Json(detail)))
}

async fn update_group_nickname<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Path(conversation_id): Path<Uuid>,
    Json(body): Json<UpdateGroupNicknameBody>,
) -> AppResult<impl IntoResponse>
where
    B: GroupBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let detail = GroupService::new(broadcaster)
        .update_nickname(&context, user_id, conversation_id, body)
        .await?;
    Ok(utf8_json(Json(detail)))
}

async fn update_group_settings<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Path(conversation_id): Path<Uuid>,
    Json(body): Json<UpdateGroupSettingsBody>,
) -> AppResult<impl IntoResponse>
where
    B: GroupBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let detail = GroupService::new(broadcaster)
        .update_settings(&context, user_id, conversation_id, body)
        .await?;
    Ok(utf8_json(Json(detail)))
}

async fn update_group_announcement<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Path(conversation_id): Path<Uuid>,
    Json(body): Json<UpdateGroupAnnouncementBody>,
) -> AppResult<impl IntoResponse>
where
    B: GroupBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let detail = GroupService::new(broadcaster)
        .update_announcement(&context, user_id, conversation_id, body)
        .await?;
    Ok(utf8_json(Json(detail)))
}

async fn transfer_group_owner<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Path(conversation_id): Path<Uuid>,
    Json(body): Json<TransferGroupOwnerBody>,
) -> AppResult<impl IntoResponse>
where
    B: GroupBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let detail = GroupService::new(broadcaster)
        .transfer_owner(&context, user_id, conversation_id, body)
        .await?;
    Ok(utf8_json(Json(detail)))
}

async fn leave_group<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Path(conversation_id): Path<Uuid>,
) -> AppResult<impl IntoResponse>
where
    B: GroupBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    GroupService::new(broadcaster)
        .leave_group(&context, user_id, conversation_id)
        .await?;
    Ok(utf8_json(Json(GroupActionResponse {
        message: "left group",
    })))
}

async fn add_group_members<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Path(conversation_id): Path<Uuid>,
    Json(body): Json<GroupMemberIdsBody>,
) -> AppResult<impl IntoResponse>
where
    B: GroupBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let detail = GroupService::new(broadcaster)
        .add_members(&context, user_id, conversation_id, body)
        .await?;
    Ok(utf8_json(Json(detail)))
}

async fn remove_group_member<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Path((conversation_id, member_id)): Path<(Uuid, i64)>,
) -> AppResult<impl IntoResponse>
where
    B: GroupBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let detail = GroupService::new(broadcaster)
        .remove_member(&context, user_id, conversation_id, member_id)
        .await?;
    Ok(utf8_json(Json(detail)))
}

async fn invite_group_members<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Path(conversation_id): Path<Uuid>,
    Json(body): Json<GroupMemberIdsBody>,
) -> AppResult<impl IntoResponse>
where
    B: GroupBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let result = GroupService::new(broadcaster)
        .invite_members(&context, user_id, conversation_id, body)
        .await?;
    Ok(utf8_json(Json(result)))
}

async fn accept_group_invitation<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Path(invitation_id): Path<Uuid>,
) -> AppResult<impl IntoResponse>
where
    B: GroupBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let conversation = GroupService::new(broadcaster)
        .accept_invitation(&context, user_id, invitation_id)
        .await?;
    Ok(utf8_json(Json(conversation)))
}

async fn dissolve_group<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Path(conversation_id): Path<Uuid>,
) -> AppResult<impl IntoResponse>
where
    B: GroupBroadcaster + MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    GroupService::new(broadcaster)
        .dissolve_group(&context, user_id, conversation_id)
        .await?;
    Ok(utf8_json(Json(GroupActionResponse {
        message: "group dissolved",
    })))
}
