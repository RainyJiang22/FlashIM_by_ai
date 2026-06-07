use axum::{
    extract::{
        Query, State,
        ws::{Message, WebSocket, WebSocketUpgrade},
    },
    response::IntoResponse,
};
use futures_util::StreamExt;
use std::sync::atomic::{AtomicUsize, Ordering};

use crate::{
    error::{AppError, AppResult},
    models::chat::ChatRoomWsQuery,
    services::{auth_service, chat_room_service},
    state::SharedState,
};

static NEXT_CONNECTION_ID: AtomicUsize = AtomicUsize::new(1);

pub async fn websocket_handler(websocket: WebSocketUpgrade) -> impl IntoResponse {
    let connection_id = next_connection_id();
    websocket.on_upgrade(move |socket| handle_websocket(socket, connection_id))
}

pub async fn chat_room_websocket_handler(
    State(state): State<SharedState>,
    Query(query): Query<ChatRoomWsQuery>,
    websocket: WebSocketUpgrade,
) -> AppResult<impl IntoResponse> {
    let token = query
        .token
        .as_deref()
        .filter(|token| !token.trim().is_empty())
        .ok_or(AppError::unauthorized("missing token"))?;
    let user = auth_service::authenticate_user(state.as_ref(), token).await?;
    let connection_id = next_connection_id();

    Ok(websocket.on_upgrade(move |socket| {
        chat_room_service::handle_chat_room_socket(socket, connection_id, state, user)
    }))
}

async fn handle_websocket(mut socket: WebSocket, connection_id: usize) {
    println!("ws connected: connection_id={connection_id}");

    if let Err(error) = socket
        .send(Message::Text("welcome to flash_im websocket".into()))
        .await
    {
        println!("ws send failed on connect: connection_id={connection_id}, error={error}");
        return;
    }

    while let Some(result) = socket.next().await {
        match result {
            Ok(Message::Text(text)) => {
                let reply = format!("echo: {text}");
                if let Err(error) = socket.send(Message::Text(reply.into())).await {
                    println!("ws send failed: connection_id={connection_id}, error={error}");
                    break;
                }
            }
            Ok(Message::Close(_)) => break,
            Ok(_) => {}
            Err(error) => {
                println!("ws receive failed: connection_id={connection_id}, error={error}");
                break;
            }
        }
    }

    println!("ws disconnected: connection_id={connection_id}");
}

fn next_connection_id() -> usize {
    NEXT_CONNECTION_ID.fetch_add(1, Ordering::Relaxed)
}
