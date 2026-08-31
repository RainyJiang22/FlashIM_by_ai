use std::{collections::HashSet, sync::Arc};

use chrono::Utc;
use flash_core::{AppError, AppResult, SharedContext};
use im_conversation::{ConversationListItem, service::ConversationMessageService};
use im_message::{
    broadcast::MessageBroadcaster,
    service::{ConversationUpdate, MessageService, SendMessageInput},
};
use serde_json::json;
use uuid::Uuid;

use crate::{
    broadcast::{GroupBroadcaster, GroupJoinRequestPayload},
    models::{
        GroupDetail, GroupInvitationItem, GroupInvitationListResponse, GroupJoinRequestItem,
        GroupJoinRequestListResponse, GroupMemberIdsBody, GroupSearchItem, GroupSearchResponse,
        HandleJoinRequestBody, JoinGroupBody, JoinGroupResponse, UpdateGroupNameBody,
        UpdateGroupSettingsBody,
    },
    repository,
};

fn normalize_group_name(body: UpdateGroupNameBody) -> AppResult<String> {
    let name = body.name.trim().to_string();
    if name.is_empty() || name.chars().count() > 100 {
        return Err(AppError::bad_request("invalid group name"));
    }
    Ok(name)
}

fn normalize_member_ids(actor_id: i64, body: GroupMemberIdsBody) -> AppResult<Vec<i64>> {
    if body.member_ids.is_empty() || body.member_ids.len() > 199 {
        return Err(AppError::bad_request("invalid group member count"));
    }
    let mut unique = HashSet::with_capacity(body.member_ids.len());
    for member_id in &body.member_ids {
        if *member_id == actor_id || !unique.insert(*member_id) {
            return Err(AppError::bad_request("invalid group members"));
        }
    }
    Ok(body.member_ids)
}

fn normalize_search_keyword(value: &str) -> AppResult<String> {
    let keyword = value.trim().to_string();
    if keyword.is_empty() || keyword.chars().count() > 100 {
        return Err(AppError::bad_request("invalid group search keyword"));
    }
    Ok(keyword)
}

fn normalize_join_message(body: JoinGroupBody) -> AppResult<String> {
    let message = body.message.unwrap_or_default().trim().to_string();
    let message = if message.is_empty() {
        "请求加入群聊".to_string()
    } else {
        message
    };
    if message.chars().count() > 200 {
        return Err(AppError::bad_request("invalid join request message"));
    }
    Ok(message)
}

pub struct GroupService<B> {
    broadcaster: Arc<B>,
}

impl<B> GroupService<B>
where
    B: GroupBroadcaster + MessageBroadcaster,
{
    pub fn new(broadcaster: Arc<B>) -> Self {
        Self { broadcaster }
    }

    pub async fn get_detail(
        &self,
        context: &SharedContext,
        user_id: i64,
        conversation_id: Uuid,
    ) -> AppResult<GroupDetail> {
        load_detail(context, user_id, conversation_id).await
    }

    pub async fn search(
        &self,
        context: &SharedContext,
        user_id: i64,
        keyword: &str,
    ) -> AppResult<GroupSearchResponse> {
        let keyword = normalize_search_keyword(keyword)?;
        let exact_id = Uuid::parse_str(&keyword).ok();
        let groups =
            repository::search_groups(context.postgres.pool(), user_id, &keyword, exact_id)
                .await?
                .into_iter()
                .map(GroupSearchItem::from)
                .collect();
        Ok(GroupSearchResponse { groups })
    }

    pub async fn join(
        &self,
        context: &SharedContext,
        applicant_id: i64,
        conversation_id: Uuid,
        body: JoinGroupBody,
    ) -> AppResult<JoinGroupResponse> {
        let message = normalize_join_message(body)?;
        match repository::join_or_request(
            context.postgres.pool(),
            conversation_id,
            applicant_id,
            &message,
        )
        .await?
        {
            repository::JoinDecision::Joined { conversation_id } => {
                let _ = MessageService::new(self.broadcaster.clone())
                    .send_group_member_joined(context, conversation_id, applicant_id)
                    .await;
                let conversation = im_conversation::service::get_conversation_by_id(
                    context,
                    applicant_id,
                    conversation_id,
                )
                .await?;
                Ok(JoinGroupResponse {
                    auto_approved: true,
                    request_id: None,
                    conversation: Some(conversation),
                })
            }
            repository::JoinDecision::Pending(request) => {
                let request_id = request.id;
                let owner_id = request.owner_id;
                let _ = self
                    .broadcaster
                    .broadcast_group_join_request(owner_id, to_join_request_payload(&request))
                    .await;
                Ok(JoinGroupResponse {
                    auto_approved: false,
                    request_id: Some(request_id),
                    conversation: None,
                })
            }
        }
    }

    pub async fn list_join_requests(
        &self,
        context: &SharedContext,
        owner_id: i64,
    ) -> AppResult<GroupJoinRequestListResponse> {
        let requests = repository::list_join_requests(context.postgres.pool(), owner_id)
            .await?
            .iter()
            .map(GroupJoinRequestItem::from_row)
            .collect::<Vec<_>>();
        let pending_count = requests
            .iter()
            .filter(|request| request.status == "pending")
            .count();
        Ok(GroupJoinRequestListResponse {
            pending_count,
            requests,
        })
    }

    pub async fn handle_join_request(
        &self,
        context: &SharedContext,
        owner_id: i64,
        conversation_id: Uuid,
        request_id: Uuid,
        body: HandleJoinRequestBody,
    ) -> AppResult<GroupJoinRequestItem> {
        let handled = repository::handle_join_request(
            context.postgres.pool(),
            conversation_id,
            request_id,
            owner_id,
            body.approved,
        )
        .await?;
        if body.approved {
            let _ = MessageService::new(self.broadcaster.clone())
                .send_group_member_joined(context, conversation_id, handled.applicant_id)
                .await;
        }
        let _ = self
            .broadcaster
            .broadcast_group_join_request(handled.applicant_id, to_join_request_payload(&handled))
            .await;
        Ok(GroupJoinRequestItem::from_row(&handled))
    }

    pub async fn update_name(
        &self,
        context: &SharedContext,
        owner_id: i64,
        conversation_id: Uuid,
        body: UpdateGroupNameBody,
    ) -> AppResult<GroupDetail> {
        let name = normalize_group_name(body)?;
        repository::update_group_name(context.postgres.pool(), conversation_id, owner_id, &name)
            .await?;
        load_detail(context, owner_id, conversation_id).await
    }

    pub async fn update_settings(
        &self,
        context: &SharedContext,
        owner_id: i64,
        conversation_id: Uuid,
        body: UpdateGroupSettingsBody,
    ) -> AppResult<GroupDetail> {
        repository::update_group_settings(
            context.postgres.pool(),
            conversation_id,
            owner_id,
            body.join_approval_required,
        )
        .await?;
        load_detail(context, owner_id, conversation_id).await
    }

    pub async fn add_members(
        &self,
        context: &SharedContext,
        actor_id: i64,
        conversation_id: Uuid,
        body: GroupMemberIdsBody,
    ) -> AppResult<GroupDetail> {
        let member_ids = normalize_member_ids(actor_id, body)?;
        repository::add_group_members(
            context.postgres.pool(),
            conversation_id,
            actor_id,
            &member_ids,
        )
        .await?;
        let _ = self.notify_new_members(conversation_id, &member_ids).await;
        load_detail(context, actor_id, conversation_id).await
    }

    pub async fn remove_member(
        &self,
        context: &SharedContext,
        owner_id: i64,
        conversation_id: Uuid,
        member_id: i64,
    ) -> AppResult<GroupDetail> {
        repository::remove_group_member(
            context.postgres.pool(),
            conversation_id,
            owner_id,
            member_id,
        )
        .await?;
        load_detail(context, owner_id, conversation_id).await
    }

    pub async fn invite_members(
        &self,
        context: &SharedContext,
        inviter_id: i64,
        conversation_id: Uuid,
        body: GroupMemberIdsBody,
    ) -> AppResult<GroupInvitationListResponse> {
        let invitee_ids = normalize_member_ids(inviter_id, body)?;
        let detail = load_detail(context, inviter_id, conversation_id).await?;
        if detail.current_user_role == "owner" || !detail.join_approval_required {
            return Err(AppError::forbidden("group operation is not allowed"));
        }
        let inviter_name = detail
            .members
            .iter()
            .find(|member| member.account_id == inviter_id.to_string())
            .map(|member| member.nickname.clone())
            .unwrap_or_else(|| format!("用户 {inviter_id}"));
        let mut items = Vec::with_capacity(invitee_ids.len());
        let creations = repository::create_group_invitations(
            context.postgres.pool(),
            conversation_id,
            inviter_id,
            &invitee_ids,
        )
        .await?;

        for creation in creations {
            let invitee_id = creation.invitation.invitee_id;
            let delivered = if creation.is_new {
                let private_conversation = ConversationMessageService::new(context)
                    .create_or_get_private(inviter_id, invitee_id)
                    .await;
                let delivery = match private_conversation {
                    Ok(private_conversation_id) => MessageService::new(self.broadcaster.clone())
                        .send(
                            context,
                            SendMessageInput {
                                conversation_id: private_conversation_id,
                                sender_id: inviter_id,
                                msg_type: 4,
                                content: format!("邀请你加入群聊：{}", detail.name),
                                extra: Some(json!({
                                    "invitation_id": creation.invitation.id,
                                    "group_id": conversation_id,
                                    "group_name": detail.name.clone(),
                                    "inviter_name": inviter_name.clone(),
                                })),
                            },
                        )
                        .await
                        .map(|_| ()),
                    Err(error) => Err(error),
                };
                if delivery.is_err() {
                    repository::delete_pending_invitation(
                        context.postgres.pool(),
                        creation.invitation.id,
                        inviter_id,
                    )
                    .await?;
                    false
                } else {
                    true
                }
            } else {
                true
            };
            items.push(GroupInvitationItem {
                id: delivered.then_some(creation.invitation.id),
                conversation_id: creation.invitation.conversation_id,
                invitee_id: creation.invitation.invitee_id.to_string(),
                status: if delivered { "pending" } else { "failed" },
                delivered,
            });
        }

        Ok(GroupInvitationListResponse { invitations: items })
    }

    pub async fn accept_invitation(
        &self,
        context: &SharedContext,
        invitee_id: i64,
        invitation_id: Uuid,
    ) -> AppResult<ConversationListItem> {
        let conversation_id =
            repository::accept_group_invitation(context.postgres.pool(), invitation_id, invitee_id)
                .await?;
        let conversation =
            im_conversation::service::get_conversation_by_id(context, invitee_id, conversation_id)
                .await?;
        let _ = self
            .notify_new_members(conversation_id, &[invitee_id])
            .await;
        Ok(conversation)
    }

    pub async fn dissolve_group(
        &self,
        context: &SharedContext,
        owner_id: i64,
        conversation_id: Uuid,
    ) -> AppResult<()> {
        repository::dissolve_group(context.postgres.pool(), conversation_id, owner_id).await
    }

    async fn notify_new_members(&self, conversation_id: Uuid, member_ids: &[i64]) -> AppResult<()> {
        let now = Utc::now();
        let updates = member_ids
            .iter()
            .map(|member_id| ConversationUpdate {
                conversation_id,
                user_id: *member_id,
                last_message_preview: "已加入群聊".to_string(),
                last_message_at: now,
                unread_count: 0,
            })
            .collect();
        self.broadcaster
            .broadcast_conversation_updates(updates, member_ids)
            .await
    }
}

fn to_join_request_payload(
    request: &crate::models::GroupJoinRequestRow,
) -> GroupJoinRequestPayload {
    let item = GroupJoinRequestItem::from_row(request);
    GroupJoinRequestPayload {
        request_id: request.id,
        conversation_id: request.conversation_id,
        group_name: item.group_name,
        group_avatar: item.group_avatar,
        applicant_id: request.applicant_id,
        applicant_name: item.applicant_name,
        applicant_avatar: item.applicant_avatar,
        message: request.message.clone(),
        status: request.status,
        created_at: request.created_at,
        handled_at: request.handled_at,
    }
}

async fn load_detail(
    context: &SharedContext,
    user_id: i64,
    conversation_id: Uuid,
) -> AppResult<GroupDetail> {
    let summary =
        repository::get_group_for_member(context.postgres.pool(), conversation_id, user_id)
            .await?
            .ok_or(AppError::not_found("group not found"))?;
    let members = repository::list_group_members(context.postgres.pool(), conversation_id).await?;
    Ok(GroupDetail::from_rows(summary, user_id, members))
}

#[cfg(test)]
mod tests {
    use crate::{
        models::{GroupMemberIdsBody, JoinGroupBody, UpdateGroupNameBody},
        service::{
            normalize_group_name, normalize_join_message, normalize_member_ids,
            normalize_search_keyword,
        },
    };

    #[test]
    fn group_name_trims_and_enforces_boundaries() {
        assert_eq!(
            normalize_group_name(UpdateGroupNameBody {
                name: "  新群名  ".to_string(),
            })
            .unwrap(),
            "新群名"
        );
        assert!(
            normalize_group_name(UpdateGroupNameBody {
                name: " ".to_string(),
            })
            .is_err()
        );
        assert!(
            normalize_group_name(UpdateGroupNameBody {
                name: "群".repeat(101),
            })
            .is_err()
        );
    }

    #[test]
    fn member_ids_reject_empty_self_and_duplicates() {
        assert!(normalize_member_ids(1, GroupMemberIdsBody { member_ids: vec![] }).is_err());
        assert!(
            normalize_member_ids(
                1,
                GroupMemberIdsBody {
                    member_ids: vec![1]
                }
            )
            .is_err()
        );
        assert!(
            normalize_member_ids(
                1,
                GroupMemberIdsBody {
                    member_ids: vec![2, 2]
                }
            )
            .is_err()
        );
        assert_eq!(
            normalize_member_ids(
                1,
                GroupMemberIdsBody {
                    member_ids: vec![2, 3]
                }
            )
            .unwrap(),
            [2, 3]
        );
    }

    #[test]
    fn search_and_join_input_boundaries_are_stable() {
        assert_eq!(normalize_search_keyword("  群聊  ").unwrap(), "群聊");
        assert!(normalize_search_keyword(" ").is_err());
        assert!(normalize_search_keyword(&"群".repeat(101)).is_err());
        assert_eq!(
            normalize_join_message(JoinGroupBody { message: None }).unwrap(),
            "请求加入群聊"
        );
        assert_eq!(
            normalize_join_message(JoinGroupBody {
                message: Some("  你好  ".to_string()),
            })
            .unwrap(),
            "你好"
        );
        assert!(
            normalize_join_message(JoinGroupBody {
                message: Some("字".repeat(201)),
            })
            .is_err()
        );
    }
}
