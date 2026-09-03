use std::{error::Error, fmt};

use prost::Message as ProstMessage;

use crate::proto::{
    AuthRequest, AuthResult, ChatMessage, ConversationUpdate, FriendAcceptedEvent,
    FriendRemovedEvent, FriendRequestEvent, GroupInfoUpdateNotification,
    GroupJoinRequestNotification, MessageAck, OnlineUserList, ReadReceipt, UserPresenceEvent,
    WsFrame, WsFrameType,
};

#[derive(Debug)]
pub enum FrameDecodeError {
    InvalidProtobuf(prost::DecodeError),
    UnknownFrameType(i32),
}

impl fmt::Display for FrameDecodeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidProtobuf(error) => write!(f, "invalid protobuf frame: {error}"),
            Self::UnknownFrameType(frame_type) => write!(f, "unknown frame type: {frame_type}"),
        }
    }
}

impl Error for FrameDecodeError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            Self::InvalidProtobuf(error) => Some(error),
            Self::UnknownFrameType(_) => None,
        }
    }
}

pub fn encode_frame(frame_type: WsFrameType, payload: Vec<u8>) -> Vec<u8> {
    let frame = WsFrame {
        r#type: frame_type as i32,
        payload,
    };
    frame.encode_to_vec()
}

pub fn decode_frame(bytes: &[u8]) -> Result<(WsFrameType, Vec<u8>), FrameDecodeError> {
    let frame = WsFrame::decode(bytes).map_err(FrameDecodeError::InvalidProtobuf)?;
    let frame_type = WsFrameType::try_from(frame.r#type)
        .map_err(|_| FrameDecodeError::UnknownFrameType(frame.r#type))?;

    Ok((frame_type, frame.payload))
}

pub fn auth_request_frame(token: impl Into<String>) -> Vec<u8> {
    let payload = AuthRequest {
        token: token.into(),
    }
    .encode_to_vec();
    encode_frame(WsFrameType::Auth, payload)
}

pub fn auth_result_frame(success: bool, message: impl Into<String>) -> Vec<u8> {
    let payload = AuthResult {
        success,
        message: message.into(),
    }
    .encode_to_vec();
    encode_frame(WsFrameType::AuthResult, payload)
}

pub fn decode_auth_result_payload(payload: &[u8]) -> Result<AuthResult, prost::DecodeError> {
    AuthResult::decode(payload)
}

pub fn ping_frame() -> Vec<u8> {
    encode_frame(WsFrameType::Ping, Vec::new())
}

pub fn pong_frame() -> Vec<u8> {
    encode_frame(WsFrameType::Pong, Vec::new())
}

pub fn chat_message_frame(message: ChatMessage) -> Vec<u8> {
    encode_frame(WsFrameType::ChatMessage, message.encode_to_vec())
}

pub fn message_ack_frame(ack: MessageAck) -> Vec<u8> {
    encode_frame(WsFrameType::MessageAck, ack.encode_to_vec())
}

pub fn conversation_update_frame(update: ConversationUpdate) -> Vec<u8> {
    encode_frame(WsFrameType::ConversationUpdate, update.encode_to_vec())
}

pub fn friend_request_frame(event: FriendRequestEvent) -> Vec<u8> {
    encode_frame(WsFrameType::FriendRequest, event.encode_to_vec())
}

pub fn friend_accepted_frame(event: FriendAcceptedEvent) -> Vec<u8> {
    encode_frame(WsFrameType::FriendAccepted, event.encode_to_vec())
}

pub fn friend_removed_frame(event: FriendRemovedEvent) -> Vec<u8> {
    encode_frame(WsFrameType::FriendRemoved, event.encode_to_vec())
}

pub fn group_join_request_frame(event: GroupJoinRequestNotification) -> Vec<u8> {
    encode_frame(WsFrameType::GroupJoinRequest, event.encode_to_vec())
}

pub fn group_info_update_frame(event: GroupInfoUpdateNotification) -> Vec<u8> {
    encode_frame(WsFrameType::GroupInfoUpdate, event.encode_to_vec())
}

pub fn user_online_frame(event: UserPresenceEvent) -> Vec<u8> {
    encode_frame(WsFrameType::UserOnline, event.encode_to_vec())
}

pub fn user_offline_frame(event: UserPresenceEvent) -> Vec<u8> {
    encode_frame(WsFrameType::UserOffline, event.encode_to_vec())
}

pub fn online_list_frame(list: OnlineUserList) -> Vec<u8> {
    encode_frame(WsFrameType::OnlineList, list.encode_to_vec())
}

pub fn read_receipt_frame(receipt: ReadReceipt) -> Vec<u8> {
    encode_frame(WsFrameType::ReadReceipt, receipt.encode_to_vec())
}

#[cfg(test)]
mod tests {
    use prost::Message as ProstMessage;

    use super::{decode_frame, group_info_update_frame, online_list_frame, read_receipt_frame};
    use crate::proto::{GroupInfoUpdateNotification, OnlineUserList, ReadReceipt, WsFrameType};

    #[test]
    fn group_info_update_uses_type_eleven_and_keeps_recipient_state() {
        let bytes = group_info_update_frame(GroupInfoUpdateNotification {
            conversation_id: "group-id".to_string(),
            name: "测试群".to_string(),
            avatar: "grid:a".to_string(),
            owner_id: 1,
            member_count: 2,
            announcement: "公告".to_string(),
            announcement_updated_at: "2026-08-31T00:00:00Z".to_string(),
            announcement_updated_by: 1,
            is_dissolved: false,
            membership_active: true,
            current_user_role: "member".to_string(),
            change_type: "announcement_updated".to_string(),
        });

        let (frame_type, payload) = decode_frame(&bytes).unwrap();
        assert_eq!(frame_type, WsFrameType::GroupInfoUpdate);
        let event = GroupInfoUpdateNotification::decode(payload.as_slice()).unwrap();
        assert!(event.membership_active);
        assert_eq!(event.change_type, "announcement_updated");
    }

    #[test]
    fn online_list_uses_presence_frame_type() {
        let bytes = online_list_frame(OnlineUserList {
            user_ids: vec![2, 3],
        });
        let (frame_type, payload) = decode_frame(&bytes).unwrap();
        assert_eq!(frame_type, WsFrameType::OnlineList);
        assert_eq!(
            OnlineUserList::decode(payload.as_slice()).unwrap().user_ids,
            vec![2, 3]
        );
    }

    #[test]
    fn read_receipt_keeps_monotonic_interval() {
        let bytes = read_receipt_frame(ReadReceipt {
            conversation_id: "conversation-id".to_string(),
            reader_id: 2,
            previous_read_seq: 4,
            read_seq: 8,
        });
        let (frame_type, payload) = decode_frame(&bytes).unwrap();
        assert_eq!(frame_type, WsFrameType::ReadReceipt);
        let receipt = ReadReceipt::decode(payload.as_slice()).unwrap();
        assert_eq!((receipt.previous_read_seq, receipt.read_seq), (4, 8));
    }
}
