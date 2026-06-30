use std::{error::Error, fmt};

use prost::Message as ProstMessage;

use crate::proto::{AuthRequest, AuthResult, WsFrame, WsFrameType};

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
