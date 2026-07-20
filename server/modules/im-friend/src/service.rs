use std::sync::Arc;

use chrono::Utc;
use flash_core::{AppError, AppResult, SharedContext};
use im_conversation::service::ConversationMessageService;
use im_message::{
    broadcast::MessageBroadcaster,
    service::{MessageService, SendMessageInput},
};
use uuid::Uuid;

use crate::{
    broadcast::{
        FriendAcceptedPayload, FriendBroadcaster, FriendRemovedPayload, FriendRequestPayload,
        FriendUserPayload,
    },
    models::{
        AcceptFriendRequestResponse, FRIEND_REQUEST_ACCEPTED, FRIEND_REQUEST_PENDING,
        FRIEND_REQUEST_REJECTED, FriendRequestListQuery, FriendRequestResponse, FriendUserResponse,
        MessageResponse, ReceivedFriendRequestResponse, RejectFriendRequestResponse,
        SendFriendRequestBody, SentFriendRequestResponse, UserSearchQuery,
    },
    repository,
};

const DEFAULT_LIMIT: i64 = 50;
const MAX_LIMIT: i64 = 100;
const DEFAULT_SEARCH_LIMIT: i64 = 20;
const MAX_SEARCH_LIMIT: i64 = 50;
const MAX_REQUEST_MESSAGE_CHARS: usize = 200;

#[derive(Clone)]
pub struct FriendService<B> {
    broadcaster: Arc<B>,
}

impl<B> FriendService<B>
where
    B: FriendBroadcaster + MessageBroadcaster,
{
    pub fn new(broadcaster: Arc<B>) -> Self {
        Self { broadcaster }
    }

    pub async fn send_request(
        &self,
        context: &SharedContext,
        from_user_id: i64,
        body: SendFriendRequestBody,
    ) -> AppResult<FriendRequestResponse> {
        let message = normalize_message(body.message)?;
        if from_user_id == body.to_user_id {
            return Err(AppError::bad_request("cannot add yourself"));
        }

        let pool = context.postgres.pool();
        if !repository::user_exists(pool, body.to_user_id).await? {
            return Err(AppError::not_found("user not found"));
        }
        if repository::are_friends(pool, from_user_id, body.to_user_id).await? {
            return Err(AppError::conflict("already friends"));
        }

        let row = repository::upsert_friend_request(pool, from_user_id, body.to_user_id, &message)
            .await?;
        self.broadcaster
            .broadcast_friend_request(
                body.to_user_id,
                FriendRequestPayload {
                    request_id: row.id,
                    from_user: from_payload_from_request(&row),
                    message: row.message.clone(),
                    created_at: row.created_at,
                },
            )
            .await?;

        Ok(FriendRequestResponse::from(row))
    }

    pub async fn list_received_requests(
        &self,
        context: &SharedContext,
        user_id: i64,
        query: FriendRequestListQuery,
    ) -> AppResult<Vec<ReceivedFriendRequestResponse>> {
        let (status, limit, offset) = normalize_request_list_query(query)?;
        let rows = repository::list_received_requests(
            context.postgres.pool(),
            user_id,
            status,
            limit,
            offset,
        )
        .await?;

        Ok(rows
            .into_iter()
            .map(ReceivedFriendRequestResponse::from)
            .collect())
    }

    pub async fn list_sent_requests(
        &self,
        context: &SharedContext,
        user_id: i64,
        query: FriendRequestListQuery,
    ) -> AppResult<Vec<SentFriendRequestResponse>> {
        let (status, limit, offset) = normalize_request_list_query(query)?;
        let rows =
            repository::list_sent_requests(context.postgres.pool(), user_id, status, limit, offset)
                .await?;

        Ok(rows
            .into_iter()
            .map(SentFriendRequestResponse::from)
            .collect())
    }

    pub async fn accept_request(
        &self,
        context: &SharedContext,
        operator_id: i64,
        request_id: Uuid,
    ) -> AppResult<AcceptFriendRequestResponse> {
        let pool = context.postgres.pool();
        let row = repository::get_request_by_id(pool, request_id)
            .await?
            .ok_or(AppError::not_found("friend request not found"))?;
        if row.to_user_id != operator_id {
            return Err(AppError::forbidden("cannot accept this friend request"));
        }
        if row.status != FRIEND_REQUEST_PENDING {
            return Err(AppError::conflict("friend request is not pending"));
        }

        let accepted = repository::accept_request(pool, request_id).await?;
        repository::insert_friend_relations(
            pool,
            accepted.from_user_id,
            accepted.to_user_id,
            accepted.id,
        )
        .await?;
        repository::mark_reverse_pending_accepted(pool, accepted.to_user_id, accepted.from_user_id)
            .await?;

        let conversation_service = ConversationMessageService::new(context);
        let conversation_id = conversation_service
            .create_or_get_private(accepted.from_user_id, accepted.to_user_id)
            .await?;

        let greeting = if accepted.message.trim().is_empty() {
            "我们已经是好友了".to_string()
        } else {
            accepted.message.clone()
        };
        let message_service = MessageService::new(self.broadcaster.clone());
        message_service
            .send(
                context,
                SendMessageInput {
                    conversation_id,
                    sender_id: accepted.from_user_id,
                    msg_type: 0,
                    content: greeting,
                    extra: None,
                },
            )
            .await?;

        self.broadcaster
            .broadcast_friend_accepted(
                accepted.from_user_id,
                FriendAcceptedPayload {
                    request_id: accepted.id,
                    friend: to_payload_from_request(&accepted),
                    conversation_id,
                    accepted_at: accepted.handled_at.unwrap_or_else(Utc::now),
                },
            )
            .await?;

        Ok(AcceptFriendRequestResponse {
            request_id: accepted.id,
            friend: FriendUserResponse {
                account_id: accepted.from_user_id,
                nickname: accepted.from_nickname,
                avatar: accepted.from_avatar,
                signature: accepted.from_signature,
                flash_id: accepted
                    .from_flash_id
                    .or_else(|| Some(format!("flash_{}", accepted.from_user_id))),
                relation_status: Some("friend".to_string()),
                created_at: None,
            },
            conversation_id,
        })
    }

    pub async fn reject_request(
        &self,
        context: &SharedContext,
        operator_id: i64,
        request_id: Uuid,
    ) -> AppResult<RejectFriendRequestResponse> {
        let pool = context.postgres.pool();
        let row = repository::get_request_by_id(pool, request_id)
            .await?
            .ok_or(AppError::not_found("friend request not found"))?;
        if row.to_user_id != operator_id {
            return Err(AppError::forbidden("cannot reject this friend request"));
        }
        if row.status != FRIEND_REQUEST_PENDING {
            return Err(AppError::conflict("friend request is not pending"));
        }

        let row = repository::reject_request(pool, request_id).await?;
        Ok(RejectFriendRequestResponse {
            request_id: row.id,
            status: "rejected".to_string(),
        })
    }

    pub async fn delete_request(
        &self,
        context: &SharedContext,
        operator_id: i64,
        request_id: Uuid,
    ) -> AppResult<MessageResponse> {
        let pool = context.postgres.pool();
        let row = repository::get_request_by_id(pool, request_id)
            .await?
            .ok_or(AppError::not_found("friend request not found"))?;
        if row.from_user_id != operator_id && row.to_user_id != operator_id {
            return Err(AppError::not_found("friend request not found"));
        }
        if row.status == FRIEND_REQUEST_PENDING {
            return Err(AppError::conflict(
                "pending friend request cannot be deleted",
            ));
        }
        if !repository::hide_request_for_user(pool, request_id, operator_id).await? {
            return Err(AppError::not_found("friend request not found"));
        }

        Ok(MessageResponse {
            message: "friend request deleted",
        })
    }

    pub async fn list_friends(
        &self,
        context: &SharedContext,
        user_id: i64,
    ) -> AppResult<Vec<FriendUserResponse>> {
        let rows = repository::list_friends(context.postgres.pool(), user_id).await?;
        Ok(rows.into_iter().map(FriendUserResponse::from).collect())
    }

    pub async fn remove_friend(
        &self,
        context: &SharedContext,
        user_id: i64,
        friend_user_id: i64,
    ) -> AppResult<MessageResponse> {
        if user_id == friend_user_id {
            return Err(AppError::bad_request("invalid friend user"));
        }
        let pool = context.postgres.pool();
        if !repository::are_friends(pool, user_id, friend_user_id).await? {
            return Err(AppError::not_found("friend relation not found"));
        }
        let current_user = repository::get_public_user(pool, friend_user_id, user_id)
            .await?
            .ok_or(AppError::not_found("user not found"))?;
        let friend_user = repository::get_public_user(pool, user_id, friend_user_id)
            .await?
            .ok_or(AppError::not_found("user not found"))?;
        let removed = repository::remove_friend_relations(pool, user_id, friend_user_id).await?;
        if removed == 0 {
            return Err(AppError::not_found("friend relation not found"));
        }

        let removed_at = Utc::now();
        self.broadcaster
            .broadcast_friend_removed(
                user_id,
                FriendRemovedPayload {
                    friend: payload_from_user_row(friend_user.clone()),
                    removed_at,
                },
            )
            .await?;
        self.broadcaster
            .broadcast_friend_removed(
                friend_user_id,
                FriendRemovedPayload {
                    friend: payload_from_user_row(current_user),
                    removed_at,
                },
            )
            .await?;

        Ok(MessageResponse {
            message: "friend removed",
        })
    }

    pub async fn search_users(
        &self,
        context: &SharedContext,
        user_id: i64,
        query: UserSearchQuery,
    ) -> AppResult<Vec<FriendUserResponse>> {
        let (q, limit) = normalize_search_query(query)?;
        let rows = repository::search_users(context.postgres.pool(), user_id, &q, limit).await?;
        Ok(rows.into_iter().map(FriendUserResponse::from).collect())
    }

    pub async fn get_public_user(
        &self,
        context: &SharedContext,
        user_id: i64,
        account_id: i64,
    ) -> AppResult<FriendUserResponse> {
        let row = repository::get_public_user(context.postgres.pool(), user_id, account_id)
            .await?
            .ok_or(AppError::not_found("user not found"))?;
        Ok(FriendUserResponse::from(row))
    }
}

fn normalize_message(message: Option<String>) -> AppResult<String> {
    let message = message.unwrap_or_default().trim().to_string();
    if message.chars().count() > MAX_REQUEST_MESSAGE_CHARS {
        return Err(AppError::bad_request("friend request message is too long"));
    }
    Ok(message)
}

fn normalize_request_list_query(
    query: FriendRequestListQuery,
) -> AppResult<(Option<i16>, i64, i64)> {
    let status = match query.status.as_deref().unwrap_or("pending") {
        "pending" => Some(FRIEND_REQUEST_PENDING),
        "accepted" => Some(FRIEND_REQUEST_ACCEPTED),
        "rejected" => Some(FRIEND_REQUEST_REJECTED),
        "all" => None,
        _ => return Err(AppError::bad_request("invalid friend request status")),
    };
    let limit = query.limit.unwrap_or(DEFAULT_LIMIT);
    if limit < 1 {
        return Err(AppError::bad_request("invalid limit"));
    }
    let offset = query.offset.unwrap_or(0);
    if offset < 0 {
        return Err(AppError::bad_request("invalid offset"));
    }

    Ok((status, limit.min(MAX_LIMIT), offset))
}

fn normalize_search_query(query: UserSearchQuery) -> AppResult<(String, i64)> {
    let q = query.q.trim().to_string();
    if q.is_empty() {
        return Err(AppError::bad_request("search query is required"));
    }
    let limit = query.limit.unwrap_or(DEFAULT_SEARCH_LIMIT);
    if limit < 1 {
        return Err(AppError::bad_request("invalid limit"));
    }

    Ok((q, limit.min(MAX_SEARCH_LIMIT)))
}

fn from_payload_from_request(row: &crate::models::FriendRequestRow) -> FriendUserPayload {
    FriendUserPayload {
        account_id: row.from_user_id,
        nickname: row.from_nickname.clone(),
        avatar: row.from_avatar.clone(),
        signature: row.from_signature.clone(),
        flash_id: row
            .from_flash_id
            .clone()
            .or_else(|| Some(format!("flash_{}", row.from_user_id))),
    }
}

fn to_payload_from_request(row: &crate::models::FriendRequestRow) -> FriendUserPayload {
    FriendUserPayload {
        account_id: row.to_user_id,
        nickname: row.to_nickname.clone(),
        avatar: row.to_avatar.clone(),
        signature: row.to_signature.clone(),
        flash_id: row
            .to_flash_id
            .clone()
            .or_else(|| Some(format!("flash_{}", row.to_user_id))),
    }
}

fn payload_from_user_row(row: crate::models::FriendUserRow) -> FriendUserPayload {
    FriendUserPayload {
        account_id: row.account_id,
        nickname: row.nickname,
        avatar: row.avatar,
        signature: row.signature,
        flash_id: row
            .flash_id
            .or_else(|| Some(format!("flash_{}", row.account_id))),
    }
}

#[cfg(test)]
mod tests {
    use crate::models::FriendRequestListQuery;

    use super::{normalize_message, normalize_request_list_query};

    #[test]
    fn normalize_message_rejects_too_long_text() {
        let long_message = "你".repeat(201);

        assert!(normalize_message(Some(long_message)).is_err());
        assert_eq!(
            normalize_message(Some(" hello ".to_string())).unwrap(),
            "hello"
        );
    }

    #[test]
    fn request_list_defaults_to_pending() {
        let (status, limit, offset) = normalize_request_list_query(FriendRequestListQuery {
            status: None,
            limit: Some(200),
            offset: Some(3),
        })
        .unwrap();

        assert_eq!(status, Some(crate::models::FRIEND_REQUEST_PENDING));
        assert_eq!(limit, 100);
        assert_eq!(offset, 3);
    }
}
