use axum::extract::ws::{Message, WebSocket};
use futures_util::{SinkExt, StreamExt};
use std::time::{SystemTime, UNIX_EPOCH};
use tokio::sync::mpsc;

use crate::{
    models::{
        chat::{ChatRoomClientEvent, ChatRoomServerEvent},
        user::UserRecord,
    },
    state::{AppState, SharedState},
    store::memory::ChatRoomConnection,
};

pub(crate) async fn handle_chat_room_socket(
    socket: WebSocket,
    connection_id: usize,
    state: SharedState,
    user: UserRecord,
) {
    println!(
        "chat_room ws connected: connection_id={connection_id}, account_id={}",
        user.account_id
    );

    let (mut ws_sender, mut ws_receiver) = socket.split();
    let (outgoing_tx, mut outgoing_rx) = mpsc::unbounded_channel::<String>();

    state
        .chat_room_store
        .insert_chat_connection(
            connection_id,
            ChatRoomConnection {
                sender: outgoing_tx.clone(),
            },
        )
        .await;

    let write_task = tokio::spawn(async move {
        while let Some(payload) = outgoing_rx.recv().await {
            if ws_sender.send(Message::Text(payload.into())).await.is_err() {
                break;
            }
        }
    });

    send_to_connection(
        &outgoing_tx,
        ChatRoomServerEvent::AuthReady {
            user_id: user.account_id as u64,
            nickname: user.nickname.clone(),
            avatar: user.avatar.clone(),
        },
    );

    while let Some(result) = ws_receiver.next().await {
        match result {
            Ok(Message::Text(text)) => match serde_json::from_str::<ChatRoomClientEvent>(&text) {
                Ok(ChatRoomClientEvent::Ping) => {
                    send_to_connection(
                        &outgoing_tx,
                        ChatRoomServerEvent::Pong {
                            sent_at: unix_timestamp(),
                        },
                    );
                }
                Ok(ChatRoomClientEvent::Chat { text }) => {
                    let content = text.trim().to_string();
                    if content.is_empty() {
                        send_to_connection(
                            &outgoing_tx,
                            ChatRoomServerEvent::Error {
                                message: "chat message is empty".to_string(),
                            },
                        );
                        continue;
                    }

                    broadcast_chat_room_message(state.as_ref(), &user, content).await;
                }
                Err(_) => {
                    send_to_connection(
                        &outgoing_tx,
                        ChatRoomServerEvent::Error {
                            message: "unsupported message payload".to_string(),
                        },
                    );
                }
            },
            Ok(Message::Close(_)) => break,
            Ok(_) => {}
            Err(error) => {
                println!(
                    "chat_room ws receive failed: connection_id={connection_id}, user_id={}, error={error}",
                    user.account_id
                );
                break;
            }
        }
    }

    state
        .chat_room_store
        .remove_chat_connection(connection_id)
        .await;
    write_task.abort();

    println!(
        "chat_room ws disconnected: connection_id={connection_id}, account_id={}",
        user.account_id
    );
}

async fn broadcast_chat_room_message(state: &AppState, user: &UserRecord, text: String) {
    let message_id = state.chat_room_store.next_chat_message_id();
    let payload = serialize_chat_room_event(ChatRoomServerEvent::Chat {
        message_id,
        user_id: user.account_id as u64,
        nickname: user.nickname.clone(),
        avatar: user.avatar.clone(),
        text,
        sent_at: unix_timestamp(),
    });

    broadcast_chat_payload(state, payload, None).await;
}

async fn broadcast_chat_payload(state: &AppState, payload: String, exclude: Option<usize>) {
    let connections = state.chat_room_store.chat_connections().await;
    let mut stale_connections = Vec::new();

    for (connection_id, connection) in connections {
        if exclude == Some(connection_id) {
            continue;
        }

        if connection.sender.send(payload.clone()).is_err() {
            stale_connections.push(connection_id);
        }
    }

    if !stale_connections.is_empty() {
        for connection_id in stale_connections {
            state
                .chat_room_store
                .remove_chat_connection(connection_id)
                .await;
        }
    }
}

fn send_to_connection(sender: &mpsc::UnboundedSender<String>, event: ChatRoomServerEvent) {
    let _ = sender.send(serialize_chat_room_event(event));
}

fn serialize_chat_room_event(event: ChatRoomServerEvent) -> String {
    serde_json::to_string(&event).expect("chat_room event should serialize")
}

fn unix_timestamp() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}
