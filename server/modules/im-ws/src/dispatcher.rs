use crate::{frame::pong_frame, proto::WsFrameType};

pub enum DispatchOutcome {
    Reply(Vec<u8>),
    Ignore,
}

pub fn dispatch_frame(frame_type: WsFrameType, _payload: Vec<u8>) -> DispatchOutcome {
    match frame_type {
        WsFrameType::Ping => DispatchOutcome::Reply(pong_frame()),
        WsFrameType::Pong | WsFrameType::Auth | WsFrameType::AuthResult => DispatchOutcome::Ignore,
    }
}
