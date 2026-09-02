use std::sync::Arc;

use chrono::{DateTime, Utc};
use flash_core::{AppError, AppResult, SharedContext};
use im_conversation::service::ConversationMessageService;
use serde_json::{Map, Value, json};
use uuid::Uuid;

use crate::{
    broadcast::MessageBroadcaster,
    models::{MessageQuery, MessageRow, MessageWithSender, NewMessage},
    repository,
};

const DEFAULT_LIMIT: i64 = 50;
const MAX_LIMIT: i64 = 100;
const DEFAULT_BEFORE_SEQ: i64 = i64::MAX;
pub const GROUP_CREATED_MESSAGE_TYPE: i16 = 5;

#[derive(Clone, Debug)]
pub struct SendMessageInput {
    pub conversation_id: Uuid,
    pub sender_id: i64,
    pub msg_type: i16,
    pub content: String,
    pub extra: Option<Value>,
}

#[derive(Clone, Debug)]
pub struct MessagePayload {
    pub id: Uuid,
    pub conversation_id: Uuid,
    pub sender_id: i64,
    pub seq: i64,
    pub msg_type: i16,
    pub content: String,
    pub extra: Option<Value>,
    pub status: i16,
    pub created_at: DateTime<Utc>,
}

impl From<MessageRow> for MessagePayload {
    fn from(row: MessageRow) -> Self {
        Self {
            id: row.id,
            conversation_id: row.conversation_id,
            sender_id: row.sender_id,
            seq: row.seq,
            msg_type: row.r#type,
            content: row.content,
            extra: row.extra,
            status: row.status,
            created_at: row.created_at,
        }
    }
}

#[derive(Clone, Debug)]
pub struct MessageAck {
    pub message_id: Uuid,
    pub seq: i64,
}

#[derive(Clone, Debug)]
pub struct ConversationUpdate {
    pub conversation_id: Uuid,
    pub user_id: i64,
    pub last_message_preview: String,
    pub last_message_at: DateTime<Utc>,
    pub unread_count: i32,
}

#[derive(Clone, Debug)]
pub struct SendMessageOutput {
    pub message: MessagePayload,
    pub ack: MessageAck,
    pub conversation_updates: Vec<ConversationUpdate>,
}

#[derive(Clone)]
pub struct MessageService<B> {
    broadcaster: Arc<B>,
}

impl<B> MessageService<B>
where
    B: MessageBroadcaster,
{
    pub fn new(broadcaster: Arc<B>) -> Self {
        Self { broadcaster }
    }

    pub async fn send(
        &self,
        context: &SharedContext,
        mut input: SendMessageInput,
    ) -> AppResult<SendMessageOutput> {
        let sender_id = input.sender_id;
        input.extra = normalize_mentions(context, &input).await?;
        self.send_with_excluded_sender(context, input, Some(sender_id))
            .await
    }

    pub async fn send_group_created(
        &self,
        context: &SharedContext,
        conversation_id: Uuid,
        creator_id: i64,
    ) -> AppResult<SendMessageOutput> {
        let creator_name = repository::get_user_display_name(context.postgres.pool(), creator_id)
            .await?
            .filter(|name| !name.trim().is_empty())
            .unwrap_or_else(|| format!("用户 {creator_id}"));
        self.send_group_system_event(
            context,
            conversation_id,
            creator_id,
            format!("{creator_name} 创建了群聊"),
            "group_created",
        )
        .await
    }

    pub async fn send_group_member_joined(
        &self,
        context: &SharedContext,
        conversation_id: Uuid,
        member_id: i64,
    ) -> AppResult<SendMessageOutput> {
        let member_name = repository::get_user_display_name(context.postgres.pool(), member_id)
            .await?
            .filter(|name| !name.trim().is_empty())
            .unwrap_or_else(|| format!("用户 {member_id}"));
        self.send_group_system_event(
            context,
            conversation_id,
            member_id,
            format!("{member_name} 加入了群聊"),
            "member_joined",
        )
        .await
    }

    pub async fn send_group_members_invited(
        &self,
        context: &SharedContext,
        conversation_id: Uuid,
        inviter_id: i64,
        invitee_ids: &[i64],
    ) -> AppResult<SendMessageOutput> {
        if invitee_ids.is_empty() {
            return Err(AppError::bad_request("group invitees are empty"));
        }
        let inviter_name = repository::get_user_display_name(context.postgres.pool(), inviter_id)
            .await?
            .filter(|name| !name.trim().is_empty())
            .unwrap_or_else(|| format!("用户 {inviter_id}"));
        let display_names =
            repository::get_user_display_names(context.postgres.pool(), invitee_ids).await?;
        let invitee_names = invitee_ids
            .iter()
            .map(|invitee_id| {
                display_names
                    .get(invitee_id)
                    .cloned()
                    .unwrap_or_else(|| format!("用户 {invitee_id}"))
            })
            .collect::<Vec<_>>();
        self.send_group_system_event(
            context,
            conversation_id,
            inviter_id,
            build_group_invitation_content(&inviter_name, &invitee_names),
            "member_invited",
        )
        .await
    }

    pub async fn send_group_system_event(
        &self,
        context: &SharedContext,
        conversation_id: Uuid,
        sender_id: i64,
        content: String,
        system_event: &'static str,
    ) -> AppResult<SendMessageOutput> {
        self.send_with_excluded_sender(
            context,
            SendMessageInput {
                conversation_id,
                sender_id,
                msg_type: GROUP_CREATED_MESSAGE_TYPE,
                content,
                extra: Some(serde_json::json!({
                    "system_event": system_event,
                })),
            },
            None,
        )
        .await
    }

    pub async fn broadcast_persisted_system_message(
        &self,
        persisted: repository::PersistedMessage,
        preview: String,
    ) -> AppResult<SendMessageOutput> {
        self.publish_persisted(persisted, preview, None).await
    }

    async fn send_with_excluded_sender(
        &self,
        context: &SharedContext,
        input: SendMessageInput,
        excluded_sender: Option<i64>,
    ) -> AppResult<SendMessageOutput> {
        if input.content.trim().is_empty() {
            return Err(AppError::bad_request("message content is empty"));
        }

        match input.msg_type {
            0 => {}
            1 => validate_image_extra(&input.extra)?,
            2 => validate_video_extra(&input.extra)?,
            3 => validate_file_extra(&input.extra)?,
            4 => validate_group_invitation_extra(&input.extra)?,
            GROUP_CREATED_MESSAGE_TYPE => {}
            _ => return Err(AppError::bad_request("unsupported message type")),
        }

        let preview = build_preview(input.msg_type, &input.content);
        let persisted = repository::persist_message(
            context.postgres.pool(),
            NewMessage {
                conversation_id: input.conversation_id,
                sender_id: input.sender_id,
                seq: 0,
                r#type: input.msg_type,
                content: input.content,
                extra: input.extra,
            },
            &preview,
        )
        .await?;
        self.publish_persisted(persisted, preview, excluded_sender)
            .await
    }

    async fn publish_persisted(
        &self,
        persisted: repository::PersistedMessage,
        preview: String,
        excluded_sender: Option<i64>,
    ) -> AppResult<SendMessageOutput> {
        let payload = MessagePayload::from(persisted.row);
        let member_ids = persisted.member_ids;
        let updates = persisted
            .unread_counts
            .into_iter()
            .map(|(user_id, unread_count)| ConversationUpdate {
                conversation_id: payload.conversation_id,
                user_id,
                last_message_preview: preview.clone(),
                last_message_at: payload.created_at,
                unread_count,
            })
            .collect::<Vec<_>>();

        let _ = self
            .broadcaster
            .broadcast_message(payload.clone(), &member_ids, excluded_sender)
            .await;
        let _ = self
            .broadcaster
            .broadcast_conversation_updates(updates.clone(), &member_ids)
            .await;

        Ok(SendMessageOutput {
            ack: MessageAck {
                message_id: payload.id,
                seq: payload.seq,
            },
            message: payload,
            conversation_updates: updates,
        })
    }

    pub async fn get_history(
        &self,
        context: &SharedContext,
        user_id: i64,
        conversation_id: Uuid,
        query: MessageQuery,
    ) -> AppResult<Vec<MessageWithSender>> {
        let (before_seq, limit) = normalize_history_query(query)?;
        let conversation_service = ConversationMessageService::new(context);
        if !conversation_service
            .can_read_history(conversation_id, user_id)
            .await?
        {
            return Err(AppError::not_found("conversation not found"));
        }

        let rows =
            repository::find_before(context.postgres.pool(), conversation_id, before_seq, limit)
                .await?;

        Ok(rows.into_iter().map(MessageWithSender::from).collect())
    }
}

async fn normalize_mentions(
    context: &SharedContext,
    input: &SendMessageInput,
) -> AppResult<Option<Value>> {
    if input.msg_type != 0 {
        return Ok(input.extra.clone());
    }
    let Some(Value::Object(extra)) = input.extra.clone() else {
        return Ok(input.extra.clone());
    };
    if !extra.contains_key("mention_all") && !extra.contains_key("mention_user_ids") {
        return Ok(Some(Value::Object(extra)));
    }
    let members =
        repository::list_mention_members(context.postgres.pool(), input.conversation_id).await?;
    normalize_mentions_for_members(extra, input.sender_id, &members).map(Some)
}

fn normalize_mentions_for_members(
    mut extra: Map<String, Value>,
    sender_id: i64,
    members: &[repository::MentionMemberRow],
) -> AppResult<Value> {
    let mention_all = match extra.remove("mention_all") {
        Some(Value::Bool(value)) => value,
        Some(_) => return Err(AppError::bad_request("invalid mentions")),
        None => false,
    };
    let mention_ids = parse_mention_ids(extra.remove("mention_user_ids"))?;
    let sender = members
        .iter()
        .find(|member| member.user_id == sender_id)
        .ok_or(AppError::not_found("conversation not found"))?;
    if mention_all {
        if !mention_ids.is_empty() {
            return Err(AppError::bad_request("invalid mentions"));
        }
        if !sender.is_owner && !sender.is_admin {
            return Err(AppError::forbidden("mention all is not allowed"));
        }
        extra.insert("mention_all".to_string(), Value::Bool(true));
        extra.insert("mentions".to_string(), Value::Array(Vec::new()));
        return Ok(Value::Object(extra));
    }
    let mut normalized = Vec::with_capacity(mention_ids.len());
    for mention_id in mention_ids {
        if mention_id == sender_id {
            return Err(AppError::bad_request("invalid mentions"));
        }
        let member = members
            .iter()
            .find(|member| member.user_id == mention_id)
            .ok_or(AppError::bad_request(
                "mention targets are not active group members",
            ))?;
        normalized.push(json!({
            "user_id": member.user_id.to_string(),
            "nickname": member.nickname.clone().unwrap_or_else(|| format!("用户 {}", member.user_id)),
        }));
    }
    extra.insert("mention_all".to_string(), Value::Bool(false));
    extra.insert("mentions".to_string(), Value::Array(normalized));
    Ok(Value::Object(extra))
}

fn parse_mention_ids(value: Option<Value>) -> AppResult<Vec<i64>> {
    let Some(value) = value else {
        return Ok(Vec::new());
    };
    let Value::Array(values) = value else {
        return Err(AppError::bad_request("invalid mentions"));
    };
    if values.len() > 50 {
        return Err(AppError::bad_request("invalid mentions"));
    }
    let mut ids = Vec::with_capacity(values.len());
    for value in values {
        let id = match value {
            Value::Number(value) => value.as_i64(),
            Value::String(value) => value.parse::<i64>().ok(),
            _ => None,
        }
        .filter(|value| *value > 0)
        .ok_or(AppError::bad_request("invalid mentions"))?;
        if ids.contains(&id) {
            return Err(AppError::bad_request("invalid mentions"));
        }
        ids.push(id);
    }
    Ok(ids)
}

fn build_group_invitation_content(inviter_name: &str, invitee_names: &[String]) -> String {
    match invitee_names {
        [invitee_name] => format!("{inviter_name} 邀请 {invitee_name} 进群"),
        _ => format!("{inviter_name} 邀请 {}等进群", invitee_names.join("、")),
    }
}

pub fn normalize_history_query(query: MessageQuery) -> AppResult<(i64, i64)> {
    let before_seq = query.before_seq.unwrap_or(DEFAULT_BEFORE_SEQ);
    if before_seq < 1 {
        return Err(AppError::bad_request("invalid before_seq"));
    }

    let limit = query.limit.unwrap_or(DEFAULT_LIMIT);
    if limit < 1 {
        return Err(AppError::bad_request("invalid limit"));
    }

    Ok((before_seq, limit.min(MAX_LIMIT)))
}

fn build_preview(msg_type: i16, content: &str) -> String {
    match msg_type {
        1 => "[图片]".to_string(),
        2 => "[视频]".to_string(),
        3 => "[文件]".to_string(),
        4 => "[群聊邀请]".to_string(),
        _ => content.chars().take(100).collect(),
    }
}

fn validate_image_extra(extra: &Option<Value>) -> AppResult<()> {
    let extra = extra
        .as_ref()
        .and_then(Value::as_object)
        .ok_or(AppError::bad_request("invalid image extra"))?;
    require_key(extra, "width", "invalid image extra")?;
    require_key(extra, "height", "invalid image extra")?;
    require_key(extra, "thumbnail_url", "invalid image extra")?;
    Ok(())
}

fn validate_video_extra(extra: &Option<Value>) -> AppResult<()> {
    let extra = extra
        .as_ref()
        .and_then(Value::as_object)
        .ok_or(AppError::bad_request("invalid video extra"))?;
    require_key(extra, "thumbnail_url", "invalid video extra")?;
    require_key(extra, "duration_ms", "invalid video extra")?;
    Ok(())
}

fn validate_file_extra(extra: &Option<Value>) -> AppResult<()> {
    let extra = extra
        .as_ref()
        .and_then(Value::as_object)
        .ok_or(AppError::bad_request("invalid file extra"))?;
    require_key(extra, "file_name", "invalid file extra")?;
    require_key(extra, "file_url", "invalid file extra")?;
    require_key(extra, "file_type", "invalid file extra")?;
    Ok(())
}

fn validate_group_invitation_extra(extra: &Option<Value>) -> AppResult<()> {
    let extra = extra
        .as_ref()
        .and_then(Value::as_object)
        .ok_or(AppError::bad_request("invalid group invitation extra"))?;
    for key in ["invitation_id", "group_id", "group_name", "inviter_name"] {
        require_key(extra, key, "invalid group invitation extra")?;
    }
    Ok(())
}

fn require_key(
    object: &serde_json::Map<String, Value>,
    key: &str,
    message: &'static str,
) -> AppResult<()> {
    match object.get(key) {
        Some(Value::Null) | None => Err(AppError::bad_request(message)),
        Some(Value::String(value)) if value.trim().is_empty() => {
            Err(AppError::bad_request(message))
        }
        Some(_) => Ok(()),
    }
}

#[cfg(test)]
mod tests {
    use serde_json::{Map, json};

    use crate::repository::MentionMemberRow;

    use crate::{
        models::MessageQuery,
        service::{
            GROUP_CREATED_MESSAGE_TYPE, build_group_invitation_content, build_preview,
            normalize_history_query, normalize_mentions_for_members, validate_file_extra,
            validate_group_invitation_extra, validate_image_extra, validate_video_extra,
        },
    };

    #[test]
    fn group_invitation_content_uses_one_message_for_single_or_multiple_invitees() {
        assert_eq!(
            build_group_invitation_content("系统助手", &["花青".to_string()]),
            "系统助手 邀请 花青 进群"
        );
        assert_eq!(
            build_group_invitation_content("系统助手", &["花青".to_string(), "湖绿".to_string()]),
            "系统助手 邀请 花青、湖绿等进群"
        );
    }

    #[test]
    fn history_query_defaults_and_clamps_limit() {
        let (before_seq, limit) = normalize_history_query(MessageQuery {
            before_seq: None,
            limit: Some(300),
        })
        .expect("query should be valid");

        assert_eq!(before_seq, i64::MAX);
        assert_eq!(limit, 100);
    }

    #[test]
    fn history_query_rejects_invalid_values() {
        assert!(
            normalize_history_query(MessageQuery {
                before_seq: Some(0),
                limit: Some(20),
            })
            .is_err()
        );
        assert!(
            normalize_history_query(MessageQuery {
                before_seq: Some(10),
                limit: Some(0),
            })
            .is_err()
        );
    }

    #[test]
    fn build_preview_uses_media_placeholders() {
        assert_eq!(build_preview(1, "hello"), "[图片]");
        assert_eq!(build_preview(2, "hello"), "[视频]");
        assert_eq!(build_preview(3, "hello"), "[文件]");
        assert_eq!(build_preview(4, "hello"), "[群聊邀请]");
        assert_eq!(
            build_preview(GROUP_CREATED_MESSAGE_TYPE, "小雨 创建了群聊"),
            "小雨 创建了群聊"
        );
        assert_eq!(build_preview(0, "hello"), "hello");
    }

    #[test]
    fn media_extra_validation_rejects_missing_fields() {
        assert!(validate_image_extra(&Some(json!({"width": 1}))).is_err());
        assert!(validate_video_extra(&Some(json!({"thumbnail_url": "x"}))).is_err());
        assert!(validate_file_extra(&Some(json!({"file_name": "x"}))).is_err());
    }

    #[test]
    fn media_extra_validation_accepts_expected_shapes() {
        assert!(
            validate_image_extra(&Some(json!({
                "width": 1,
                "height": 1,
                "thumbnail_url": "/uploads/thumb/test.webp"
            })))
            .is_ok()
        );
        assert!(
            validate_video_extra(&Some(json!({
                "thumbnail_url": "/uploads/thumb/test.jpg",
                "duration_ms": 1000
            })))
            .is_ok()
        );
        assert!(
            validate_file_extra(&Some(json!({
                "file_name": "a.pdf",
                "file_url": "/uploads/file/a.pdf",
                "file_type": "pdf"
            })))
            .is_ok()
        );
        assert!(
            validate_group_invitation_extra(&Some(json!({
                "invitation_id": "invitation-id",
                "group_id": "group-id",
                "group_name": "测试群",
                "inviter_name": "小雨"
            })))
            .is_ok()
        );
    }

    #[test]
    fn mentions_validate_targets_and_mention_all_permission() {
        let members = vec![
            MentionMemberRow {
                user_id: 1,
                nickname: Some("群主".to_string()),
                is_owner: true,
                is_admin: false,
            },
            MentionMemberRow {
                user_id: 2,
                nickname: Some("阿青".to_string()),
                is_owner: false,
                is_admin: false,
            },
            MentionMemberRow {
                user_id: 3,
                nickname: Some("管理员".to_string()),
                is_owner: false,
                is_admin: true,
            },
        ];
        let targeted = normalize_mentions_for_members(
            Map::from_iter([("mention_user_ids".to_string(), json!(["2"]))]),
            1,
            &members,
        )
        .unwrap();
        assert_eq!(targeted["mentions"][0]["nickname"], "阿青");
        assert_eq!(targeted["mention_all"], false);

        let all = normalize_mentions_for_members(
            Map::from_iter([("mention_all".to_string(), json!(true))]),
            3,
            &members,
        )
        .unwrap();
        assert_eq!(all["mention_all"], true);

        assert!(
            normalize_mentions_for_members(
                Map::from_iter([("mention_all".to_string(), json!(true))]),
                2,
                &members,
            )
            .is_err()
        );
    }
}
