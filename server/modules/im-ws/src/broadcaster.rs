use async_trait::async_trait;
use flash_core::{AppError, AppResult};
use im_friend::broadcast::{
    FriendAcceptedPayload, FriendBroadcaster, FriendRemovedPayload, FriendRequestPayload,
    FriendUserPayload,
};
use im_group::broadcast::{
    GroupBroadcaster, GroupInfoRecipient, GroupInfoUpdatePayload, GroupJoinRequestPayload,
};
use im_message::{
    broadcast::MessageBroadcaster,
    service::{ConversationUpdate as DomainConversationUpdate, MessagePayload, ReadReceiptPayload},
};
use sqlx::PgPool;

use crate::{
    frame::{
        chat_message_frame, conversation_update_frame, friend_accepted_frame, friend_removed_frame,
        friend_request_frame, group_info_update_frame, group_join_request_frame,
        read_receipt_frame, user_offline_frame, user_online_frame,
    },
    proto::{
        ChatMessage, ConversationUpdate, FriendAcceptedEvent, FriendRemovedEvent,
        FriendRequestEvent, FriendUser, GroupInfoUpdateNotification, GroupJoinRequestNotification,
        ReadReceipt, UserPresenceEvent,
    },
    state::WsState,
};

#[derive(Clone)]
pub struct WsBroadcaster {
    state: WsState,
    pool: PgPool,
}

impl WsBroadcaster {
    pub fn new(state: WsState, pool: PgPool) -> Self {
        Self { state, pool }
    }
}

#[async_trait]
impl MessageBroadcaster for WsBroadcaster {
    async fn broadcast_message(
        &self,
        message: MessagePayload,
        member_ids: &[i64],
        exclude_sender: Option<i64>,
    ) -> AppResult<()> {
        let frame = chat_message_frame(to_proto_message(&self.pool, message).await?);
        for member_id in member_ids {
            if Some(*member_id) == exclude_sender {
                continue;
            }
            self.state.send_to_user(*member_id, frame.clone());
        }

        Ok(())
    }

    async fn broadcast_conversation_updates(
        &self,
        updates: Vec<DomainConversationUpdate>,
        _member_ids: &[i64],
    ) -> AppResult<()> {
        for update in updates {
            let user_id = update.user_id;
            let frame = conversation_update_frame(to_proto_update(&self.pool, update).await?);
            self.state.send_to_user(user_id, frame);
        }

        Ok(())
    }

    async fn broadcast_read_receipt(
        &self,
        receipt: ReadReceiptPayload,
        member_ids: &[i64],
    ) -> AppResult<()> {
        let frame = read_receipt_frame(ReadReceipt {
            conversation_id: receipt.conversation_id.to_string(),
            reader_id: receipt.reader_id,
            previous_read_seq: receipt.previous_read_seq,
            read_seq: receipt.read_seq,
        });
        for member_id in member_ids {
            self.state.send_to_user(*member_id, frame.clone());
        }
        Ok(())
    }
}

#[async_trait]
impl FriendBroadcaster for WsBroadcaster {
    async fn broadcast_friend_request(
        &self,
        to_user_id: i64,
        event: FriendRequestPayload,
    ) -> AppResult<()> {
        self.state.send_to_user(
            to_user_id,
            friend_request_frame(FriendRequestEvent {
                request_id: event.request_id.to_string(),
                from_user: Some(to_proto_friend_user(event.from_user)),
                message: event.message,
                created_at: event.created_at.to_rfc3339(),
            }),
        );
        Ok(())
    }

    async fn broadcast_friend_accepted(
        &self,
        to_user_id: i64,
        event: FriendAcceptedPayload,
    ) -> AppResult<()> {
        self.state.send_to_user(
            to_user_id,
            friend_accepted_frame(FriendAcceptedEvent {
                request_id: event.request_id.to_string(),
                friend: Some(to_proto_friend_user(event.friend)),
                conversation_id: event.conversation_id.to_string(),
                accepted_at: event.accepted_at.to_rfc3339(),
            }),
        );
        Ok(())
    }

    async fn broadcast_friend_removed(
        &self,
        to_user_id: i64,
        event: FriendRemovedPayload,
    ) -> AppResult<()> {
        self.state.send_to_user(
            to_user_id,
            friend_removed_frame(FriendRemovedEvent {
                friend: Some(to_proto_friend_user(event.friend)),
                removed_at: event.removed_at.to_rfc3339(),
            }),
        );
        Ok(())
    }

    async fn broadcast_friend_presence(
        &self,
        to_user_id: i64,
        friend_user_id: i64,
        is_friend: bool,
    ) -> AppResult<()> {
        let event = UserPresenceEvent {
            user_id: friend_user_id,
        };
        if is_friend {
            if self.state.is_online(friend_user_id) {
                self.state
                    .send_to_user(to_user_id, user_online_frame(event));
            }
        } else {
            self.state
                .send_to_user(to_user_id, user_offline_frame(event));
        }
        Ok(())
    }
}

#[async_trait]
impl GroupBroadcaster for WsBroadcaster {
    async fn broadcast_group_join_request(
        &self,
        to_user_id: i64,
        event: GroupJoinRequestPayload,
    ) -> AppResult<()> {
        self.state.send_to_user(
            to_user_id,
            group_join_request_frame(GroupJoinRequestNotification {
                request_id: event.request_id.to_string(),
                conversation_id: event.conversation_id.to_string(),
                group_name: event.group_name,
                group_avatar: event.group_avatar,
                applicant_id: event.applicant_id,
                applicant_name: event.applicant_name,
                applicant_avatar: event.applicant_avatar,
                message: event.message,
                status: event.status as i32,
                created_at: event.created_at.to_rfc3339(),
                handled_at: event
                    .handled_at
                    .map(|value| value.to_rfc3339())
                    .unwrap_or_default(),
            }),
        );
        Ok(())
    }

    async fn broadcast_group_info_update(
        &self,
        recipients: &[GroupInfoRecipient],
        event: GroupInfoUpdatePayload,
    ) -> AppResult<()> {
        for recipient in recipients {
            self.state.send_to_user(
                recipient.user_id,
                group_info_update_frame(GroupInfoUpdateNotification {
                    conversation_id: event.conversation_id.to_string(),
                    name: event.name.clone(),
                    avatar: event.avatar.clone(),
                    owner_id: event.owner_id,
                    member_count: event.member_count,
                    announcement: event.announcement.clone(),
                    announcement_updated_at: event
                        .announcement_updated_at
                        .map(|value| value.to_rfc3339())
                        .unwrap_or_default(),
                    announcement_updated_by: event.announcement_updated_by.unwrap_or_default(),
                    is_dissolved: event.is_dissolved,
                    membership_active: recipient.membership_active,
                    current_user_role: recipient.current_user_role.to_string(),
                    change_type: event.change_type.to_string(),
                }),
            );
        }
        Ok(())
    }
}

#[derive(sqlx::FromRow)]
struct SenderProfile {
    nickname: Option<String>,
    avatar_url: Option<String>,
}

fn sender_profile_sql() -> &'static str {
    r#"
        SELECT
            COALESCE(NULLIF(BTRIM(member.group_nickname), ''), profile.nickname) AS nickname,
            profile.avatar_url
        FROM user_profiles profile
        LEFT JOIN conversation_members member
          ON member.conversation_id = $1
         AND member.user_id = profile.account_id
        WHERE profile.account_id = $2
        "#
}

async fn load_sender_profile(
    pool: &PgPool,
    conversation_id: uuid::Uuid,
    sender_id: i64,
) -> AppResult<Option<SenderProfile>> {
    sqlx::query_as::<_, SenderProfile>(sender_profile_sql())
        .bind(conversation_id)
        .bind(sender_id)
        .fetch_optional(pool)
        .await
        .map_err(|_| AppError::internal_server_error("failed to load sender profile"))
}

async fn load_total_unread(pool: &PgPool, user_id: i64) -> AppResult<i32> {
    sqlx::query_scalar::<_, i32>(
        r#"
        SELECT COALESCE(SUM(unread_count), 0)::INT
        FROM conversation_members member
        WHERE member.user_id = $1
          AND member.is_deleted = FALSE
          AND (
              member.is_hidden = FALSE
              OR COALESCE(
                  (
                      SELECT current_seq
                      FROM conversation_seq
                      WHERE conversation_id = member.conversation_id
                  ),
                  0
              ) > member.hidden_through_seq
          )
        "#,
    )
    .bind(user_id)
    .fetch_one(pool)
    .await
    .map_err(|_| AppError::internal_server_error("failed to load total unread count"))
}

async fn to_proto_message(pool: &PgPool, message: MessagePayload) -> AppResult<ChatMessage> {
    let sender_profile =
        load_sender_profile(pool, message.conversation_id, message.sender_id).await?;

    Ok(ChatMessage {
        id: message.id.to_string(),
        conversation_id: message.conversation_id.to_string(),
        sender_id: message.sender_id,
        seq: message.seq,
        r#type: message.msg_type as i32,
        content: message.content,
        extra: message
            .extra
            .map(|value| value.to_string())
            .unwrap_or_default(),
        status: message.status as i32,
        created_at: message.created_at.to_rfc3339(),
        sender_name: sender_profile
            .as_ref()
            .and_then(|profile| profile.nickname.clone())
            .unwrap_or_default(),
        sender_avatar: sender_profile
            .and_then(|profile| profile.avatar_url)
            .unwrap_or_default(),
        read_count: message.read_count,
    })
}

async fn to_proto_update(
    pool: &PgPool,
    update: DomainConversationUpdate,
) -> AppResult<ConversationUpdate> {
    let total_unread = load_total_unread(pool, update.user_id).await?;

    Ok(ConversationUpdate {
        conversation_id: update.conversation_id.to_string(),
        last_message_preview: update.last_message_preview,
        last_message_at: update.last_message_at.to_rfc3339(),
        unread_count: update.unread_count,
        total_unread,
    })
}

fn to_proto_friend_user(user: FriendUserPayload) -> FriendUser {
    FriendUser {
        account_id: user.account_id,
        nickname: user.nickname,
        avatar: user.avatar,
        signature: user.signature,
        flash_id: user.flash_id.unwrap_or_default(),
    }
}

#[cfg(test)]
mod tests {
    use super::{WsBroadcaster, sender_profile_sql};
    use crate::{
        frame::decode_frame,
        proto::{ChatMessage, ConversationUpdate, UserPresenceEvent, WsFrameType},
        state::WsState,
    };
    use im_friend::broadcast::FriendBroadcaster;
    use prost::Message;
    use sqlx::postgres::PgPoolOptions;
    use uuid::Uuid;

    #[test]
    fn sender_profile_prefers_group_nickname() {
        let sql = sender_profile_sql();
        assert!(sql.contains("member.group_nickname"));
        assert!(sql.contains("profile.nickname"));
        assert!(sql.contains("COALESCE"));
    }

    #[test]
    fn proto_message_keeps_sender_profile_fields() {
        let message = ChatMessage {
            id: "00000000-0000-0000-0000-000000000001".to_string(),
            conversation_id: "00000000-0000-0000-0000-000000000002".to_string(),
            sender_id: 2,
            seq: 1,
            r#type: 0,
            content: "hello".to_string(),
            extra: String::new(),
            status: 0,
            created_at: "2026-04-03T00:00:00Z".to_string(),
            sender_name: "朱红".to_string(),
            sender_avatar: "identicon:2".to_string(),
            read_count: 0,
        };

        assert_eq!(message.sender_name, "朱红");
        assert_eq!(message.sender_avatar, "identicon:2");
    }

    #[test]
    fn proto_message_keeps_extra_payload() {
        let message = ChatMessage {
            id: "00000000-0000-0000-0000-000000000001".to_string(),
            conversation_id: "00000000-0000-0000-0000-000000000002".to_string(),
            sender_id: 2,
            seq: 1,
            r#type: 1,
            content: "https://example.com/a.jpg".to_string(),
            extra: r#"{"thumbnail_url":"/uploads/thumb/a.webp"}"#.to_string(),
            status: 0,
            created_at: "2026-04-03T00:00:00Z".to_string(),
            sender_name: "朱红".to_string(),
            sender_avatar: "identicon:2".to_string(),
            read_count: 0,
        };

        assert!(message.extra.contains("thumbnail_url"));
    }

    #[test]
    fn proto_update_keeps_total_unread_field() {
        let update = ConversationUpdate {
            conversation_id: "00000000-0000-0000-0000-000000000001".to_string(),
            last_message_preview: "hello".to_string(),
            last_message_at: "2026-04-03T00:00:00Z".to_string(),
            unread_count: 1,
            total_unread: 9,
        };

        assert_eq!(update.total_unread, 9);
    }

    #[tokio::test]
    async fn friend_visibility_sends_current_presence_to_recipient() {
        let state = WsState::default();
        let mut recipient = state.register(1, Uuid::new_v4()).receiver;
        let _friend = state.register(2, Uuid::new_v4());
        let pool = PgPoolOptions::new()
            .connect_lazy("postgres://localhost/flash_im")
            .expect("valid lazy pool");
        let broadcaster = WsBroadcaster::new(state, pool);

        broadcaster
            .broadcast_friend_presence(1, 2, true)
            .await
            .expect("broadcast online friend");
        let frame = recipient.recv().await.expect("online frame");
        let (frame_type, payload) = decode_frame(&frame).expect("decode online frame");
        assert_eq!(frame_type, WsFrameType::UserOnline);
        assert_eq!(
            UserPresenceEvent::decode(payload.as_slice())
                .unwrap()
                .user_id,
            2
        );

        broadcaster
            .broadcast_friend_presence(1, 2, false)
            .await
            .expect("broadcast hidden friend");
        let frame = recipient.recv().await.expect("offline frame");
        let (frame_type, payload) = decode_frame(&frame).expect("decode offline frame");
        assert_eq!(frame_type, WsFrameType::UserOffline);
        assert_eq!(
            UserPresenceEvent::decode(payload.as_slice())
                .unwrap()
                .user_id,
            2
        );
    }
}
