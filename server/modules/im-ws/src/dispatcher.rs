use flash_core::{AppError, AppResult, SharedContext};
use im_message::service::{MessageService, SendMessageInput};
use prost::Message as ProstMessage;
use uuid::Uuid;

use crate::{
    broadcaster::WsBroadcaster,
    frame::{message_ack_frame, pong_frame},
    proto::{MessageAck, ReadReceipt, SendMessageRequest, WsFrameType},
};

pub enum DispatchOutcome {
    Reply(Vec<u8>),
    Ignore,
}

pub async fn dispatch_frame(
    context: &SharedContext,
    account_id: i64,
    service: &MessageService<WsBroadcaster>,
    frame_type: WsFrameType,
    payload: Vec<u8>,
) -> AppResult<DispatchOutcome> {
    match frame_type {
        WsFrameType::Ping => Ok(DispatchOutcome::Reply(pong_frame())),
        WsFrameType::ChatMessage => handle_chat_message(context, account_id, service, payload)
            .await
            .map(DispatchOutcome::Reply),
        WsFrameType::ReadReceipt => {
            handle_read_receipt(context, account_id, service, payload).await?;
            Ok(DispatchOutcome::Ignore)
        }
        WsFrameType::Pong
        | WsFrameType::Auth
        | WsFrameType::AuthResult
        | WsFrameType::MessageAck
        | WsFrameType::ConversationUpdate
        | WsFrameType::FriendRequest
        | WsFrameType::FriendAccepted
        | WsFrameType::FriendRemoved
        | WsFrameType::GroupJoinRequest
        | WsFrameType::GroupInfoUpdate
        | WsFrameType::UserOnline
        | WsFrameType::UserOffline
        | WsFrameType::OnlineList => Ok(DispatchOutcome::Ignore),
    }
}

async fn handle_read_receipt(
    context: &SharedContext,
    account_id: i64,
    service: &MessageService<WsBroadcaster>,
    payload: Vec<u8>,
) -> AppResult<()> {
    let request = ReadReceipt::decode(payload.as_slice())
        .map_err(|_| AppError::bad_request("invalid read receipt payload"))?;
    let conversation_id = Uuid::parse_str(request.conversation_id.trim())
        .map_err(|_| AppError::bad_request("invalid conversation id"))?;
    service
        .mark_read(context, account_id, conversation_id, request.read_seq)
        .await?;
    Ok(())
}

async fn handle_chat_message(
    context: &SharedContext,
    account_id: i64,
    service: &MessageService<WsBroadcaster>,
    payload: Vec<u8>,
) -> AppResult<Vec<u8>> {
    let request = SendMessageRequest::decode(payload.as_slice())
        .map_err(|_| AppError::bad_request("invalid chat message payload"))?;
    validate_client_message_type(request.r#type)?;
    let conversation_id = Uuid::parse_str(request.conversation_id.trim())
        .map_err(|_| AppError::bad_request("invalid conversation id"))?;
    let extra = parse_extra(request.extra.trim())?;

    let output = service
        .send(
            context,
            SendMessageInput {
                conversation_id,
                sender_id: account_id,
                msg_type: request.r#type as i16,
                content: request.content,
                extra,
            },
        )
        .await?;

    Ok(message_ack_frame(MessageAck {
        message_id: output.ack.message_id.to_string(),
        seq: output.ack.seq,
    }))
}

fn validate_client_message_type(message_type: i32) -> AppResult<()> {
    if !(0..=3).contains(&message_type) {
        return Err(AppError::bad_request("unsupported client message type"));
    }
    Ok(())
}

fn parse_extra(extra: &str) -> AppResult<Option<serde_json::Value>> {
    if extra.is_empty() {
        return Ok(None);
    }

    serde_json::from_str(extra)
        .map(Some)
        .map_err(|_| AppError::bad_request("invalid message extra"))
}

#[cfg(test)]
mod tests {
    use super::{parse_extra, validate_client_message_type};

    #[test]
    fn parse_extra_allows_empty_payload() {
        assert!(parse_extra("").expect("empty extra should parse").is_none());
    }

    #[test]
    fn parse_extra_rejects_invalid_json() {
        assert!(parse_extra("{").is_err());
    }

    #[test]
    fn client_cannot_forge_server_controlled_messages() {
        for message_type in 0..=3 {
            assert!(validate_client_message_type(message_type).is_ok());
        }
        assert!(validate_client_message_type(4).is_err());
        assert!(validate_client_message_type(5).is_err());
        assert!(validate_client_message_type(-1).is_err());
    }
}
