use std::{
    collections::HashMap,
    sync::atomic::{AtomicU64, Ordering},
};
use tokio::sync::{RwLock, mpsc};

#[derive(Clone)]
pub struct ChatRoomConnection {
    pub sender: mpsc::UnboundedSender<String>,
}

#[derive(Default)]
pub struct ChatRoomStore {
    chat_connections: RwLock<HashMap<usize, ChatRoomConnection>>,
    next_chat_message_id: AtomicU64,
}

impl ChatRoomStore {
    pub async fn insert_chat_connection(
        &self,
        connection_id: usize,
        connection: ChatRoomConnection,
    ) {
        self.chat_connections
            .write()
            .await
            .insert(connection_id, connection);
    }

    pub async fn remove_chat_connection(&self, connection_id: usize) {
        self.chat_connections.write().await.remove(&connection_id);
    }

    pub async fn chat_connections(&self) -> Vec<(usize, ChatRoomConnection)> {
        self.chat_connections
            .read()
            .await
            .iter()
            .map(|(connection_id, connection)| (*connection_id, connection.clone()))
            .collect()
    }

    pub fn next_chat_message_id(&self) -> u64 {
        self.next_chat_message_id.fetch_add(1, Ordering::Relaxed) + 1
    }
}
