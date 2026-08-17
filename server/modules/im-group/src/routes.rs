use std::sync::Arc;

use axum::{
    Extension, Json, Router,
    extract::{Path, State},
    http::HeaderMap,
    response::IntoResponse,
    routing::{delete, get, patch, post},
};
use flash_core::{AppResult, SharedContext, jwt::extract_user_id, response::utf8_json};
use im_message::broadcast::{MessageBroadcaster, NoopBroadcaster};
use uuid::Uuid;

use crate::{
    models::{
        GroupActionResponse, GroupMemberIdsBody, UpdateGroupNameBody, UpdateGroupSettingsBody,
    },
    service::GroupService,
};

pub fn router() -> Router<SharedContext> {
    router_with_broadcaster(Arc::new(NoopBroadcaster))
}

pub fn router_with_broadcaster<B>(broadcaster: Arc<B>) -> Router<SharedContext>
where
    B: MessageBroadcaster + 'static,
{
    Router::new()
        .route(
            "/groups/{id}",
            get(get_group::<B>).delete(dissolve_group::<B>),
        )
        .route("/groups/{id}/name", patch(update_group_name::<B>))
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

async fn get_group<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Path(conversation_id): Path<Uuid>,
) -> AppResult<impl IntoResponse>
where
    B: MessageBroadcaster,
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
    B: MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let detail = GroupService::new(broadcaster)
        .update_name(&context, user_id, conversation_id, body)
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
    B: MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let detail = GroupService::new(broadcaster)
        .update_settings(&context, user_id, conversation_id, body)
        .await?;
    Ok(utf8_json(Json(detail)))
}

async fn add_group_members<B>(
    State(context): State<SharedContext>,
    Extension(broadcaster): Extension<Arc<B>>,
    headers: HeaderMap,
    Path(conversation_id): Path<Uuid>,
    Json(body): Json<GroupMemberIdsBody>,
) -> AppResult<impl IntoResponse>
where
    B: MessageBroadcaster,
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
    B: MessageBroadcaster,
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
    B: MessageBroadcaster,
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
    B: MessageBroadcaster,
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
    B: MessageBroadcaster,
{
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    GroupService::new(broadcaster)
        .dissolve_group(&context, user_id, conversation_id)
        .await?;
    Ok(utf8_json(Json(GroupActionResponse {
        message: "group dissolved",
    })))
}
