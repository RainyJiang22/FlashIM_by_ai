use std::{fmt, time::Duration};

use axum::{
    extract::{
        State,
        ws::{Message, WebSocket, WebSocketUpgrade},
    },
    http::{HeaderMap, HeaderValue, header},
    response::IntoResponse,
};
use flash_core::{AppResult, SharedContext, jwt::extract_user_id};
use futures_util::SinkExt;
use im_message::service::MessageService;
use prost::Message as ProstMessage;
use std::sync::Arc;
use tokio::time::timeout;
use uuid::Uuid;

use crate::{
    broadcaster::WsBroadcaster,
    dispatcher::{DispatchOutcome, dispatch_frame},
    frame::{auth_result_frame, decode_frame},
    proto::{AuthRequest, WsFrameType},
    state::WsState,
};

const AUTH_TIMEOUT: Duration = Duration::from_secs(10);

pub async fn ws_handler(
    State(context): State<SharedContext>,
    websocket: WebSocketUpgrade,
) -> AppResult<impl IntoResponse> {
    let connection_id = Uuid::new_v4();
    let ws_state = crate::state::shared_ws_state();
    Ok(websocket.on_upgrade(move |socket| handle_socket(socket, context, ws_state, connection_id)))
}

async fn handle_socket(
    mut socket: WebSocket,
    context: SharedContext,
    ws_state: WsState,
    connection_id: Uuid,
) {
    match authenticate_socket(&mut socket, &context).await {
        Ok(account_id) => {
            println!("im ws authenticated: connection_id={connection_id}, account_id={account_id}");
            if socket
                .send(Message::Binary(auth_result_frame(true, "ok").into()))
                .await
                .is_err()
            {
                return;
            }
            handle_authenticated_socket(socket, context, ws_state, connection_id, account_id).await;
        }
        Err(error) => {
            println!("im ws auth failed: connection_id={connection_id}, error={error}");
            let _ = socket
                .send(Message::Binary(
                    auth_result_frame(false, error.message()).into(),
                ))
                .await;
            let _ = socket.close().await;
        }
    }
}

async fn authenticate_socket(
    socket: &mut WebSocket,
    context: &SharedContext,
) -> Result<i64, AuthFailure> {
    let message = match timeout(AUTH_TIMEOUT, socket.recv()).await {
        Ok(Some(Ok(message))) => message,
        Ok(Some(Err(error))) => return Err(AuthFailure::Receive(error.to_string())),
        Ok(None) => return Err(AuthFailure::Closed),
        Err(_) => return Err(AuthFailure::Timeout),
    };

    let Message::Binary(bytes) = message else {
        return Err(AuthFailure::ExpectedBinaryFrame);
    };

    let (frame_type, payload) =
        decode_frame(&bytes).map_err(|error| AuthFailure::InvalidFrame(error.to_string()))?;
    if frame_type != WsFrameType::Auth {
        return Err(AuthFailure::ExpectedAuthFrame);
    }

    let auth_request = AuthRequest::decode(payload.as_slice())
        .map_err(|error| AuthFailure::InvalidAuthPayload(error.to_string()))?;
    let token = auth_request.token.trim();
    if token.is_empty() {
        return Err(AuthFailure::MissingToken);
    }

    let authorization =
        HeaderValue::from_str(&format!("Bearer {token}")).map_err(|_| AuthFailure::InvalidToken)?;
    let mut headers = HeaderMap::new();
    headers.insert(header::AUTHORIZATION, authorization);

    extract_user_id(context.as_ref(), &headers).map_err(|_| AuthFailure::InvalidToken)
}

async fn handle_authenticated_socket(
    mut socket: WebSocket,
    context: SharedContext,
    ws_state: WsState,
    connection_id: Uuid,
    account_id: i64,
) {
    let mut outbound = ws_state.register(account_id, connection_id);
    let service = MessageService::new(Arc::new(WsBroadcaster::new(
        ws_state.clone(),
        context.postgres.pool().clone(),
    )));

    loop {
        tokio::select! {
            result = socket.recv() => {
                let Some(result) = result else {
                    break;
                };
                let message = match result {
                    Ok(message) => message,
                    Err(error) => {
                        println!(
                            "im ws receive failed: connection_id={connection_id}, account_id={account_id}, error={error}"
                        );
                        break;
                    }
                };

                if !handle_client_message(&mut socket, &context, account_id, &service, connection_id, message).await {
                    break;
                }
            }
            Some(frame) = outbound.recv() => {
                if socket.send(Message::Binary(frame.into())).await.is_err() {
                    break;
                }
            }
        }
    }

    ws_state.unregister(account_id, connection_id);
    println!("im ws disconnected: connection_id={connection_id}, account_id={account_id}");
}

async fn handle_client_message(
    socket: &mut WebSocket,
    context: &SharedContext,
    account_id: i64,
    service: &MessageService<WsBroadcaster>,
    connection_id: Uuid,
    message: Message,
) -> bool {
    match message {
        Message::Binary(bytes) => {
            let Ok((frame_type, payload)) = decode_frame(&bytes) else {
                return false;
            };

            match dispatch_frame(context, account_id, service, frame_type, payload).await {
                Ok(DispatchOutcome::Reply(reply)) => {
                    socket.send(Message::Binary(reply.into())).await.is_ok()
                }
                Ok(DispatchOutcome::Ignore) => true,
                Err(error) => {
                    println!(
                        "im ws dispatch failed: connection_id={connection_id}, account_id={account_id}, error={}",
                        error.message()
                    );
                    true
                }
            }
        }
        Message::Close(_) => false,
        _ => true,
    }
}

#[derive(Debug)]
enum AuthFailure {
    Timeout,
    Closed,
    ExpectedBinaryFrame,
    ExpectedAuthFrame,
    InvalidFrame(String),
    InvalidAuthPayload(String),
    Receive(String),
    MissingToken,
    InvalidToken,
}

impl AuthFailure {
    fn message(&self) -> &str {
        match self {
            Self::Timeout => "auth timeout",
            Self::Closed => "connection closed before auth",
            Self::ExpectedBinaryFrame => "expected binary auth frame",
            Self::ExpectedAuthFrame => "expected auth frame",
            Self::InvalidFrame(_) => "invalid frame",
            Self::InvalidAuthPayload(_) => "invalid auth payload",
            Self::Receive(_) => "receive failed",
            Self::MissingToken => "missing token",
            Self::InvalidToken => "invalid token",
        }
    }
}

impl fmt::Display for AuthFailure {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidFrame(error) | Self::InvalidAuthPayload(error) | Self::Receive(error) => {
                write!(f, "{}: {error}", self.message())
            }
            _ => f.write_str(self.message()),
        }
    }
}
