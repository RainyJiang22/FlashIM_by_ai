use std::{
    collections::HashMap,
    sync::{Arc, Mutex, OnceLock},
};

use tokio::sync::mpsc;
use uuid::Uuid;

pub type OutboundSender = mpsc::UnboundedSender<Vec<u8>>;
pub type OutboundReceiver = mpsc::UnboundedReceiver<Vec<u8>>;

#[derive(Clone, Default)]
pub struct WsState {
    inner: Arc<Mutex<HashMap<i64, HashMap<Uuid, OutboundSender>>>>,
}

static SHARED_WS_STATE: OnceLock<WsState> = OnceLock::new();

pub fn shared_ws_state() -> WsState {
    SHARED_WS_STATE.get_or_init(WsState::default).clone()
}

impl WsState {
    pub fn register(&self, account_id: i64, connection_id: Uuid) -> OutboundReceiver {
        let (sender, receiver) = mpsc::unbounded_channel();
        let mut connections = self.inner.lock().expect("ws state mutex poisoned");
        connections
            .entry(account_id)
            .or_default()
            .insert(connection_id, sender);
        receiver
    }

    pub fn unregister(&self, account_id: i64, connection_id: Uuid) {
        let mut connections = self.inner.lock().expect("ws state mutex poisoned");
        let Some(user_connections) = connections.get_mut(&account_id) else {
            return;
        };

        user_connections.remove(&connection_id);
        if user_connections.is_empty() {
            connections.remove(&account_id);
        }
    }

    pub fn send_to_user(&self, account_id: i64, frame: Vec<u8>) {
        let mut stale_connections = Vec::new();
        {
            let connections = self.inner.lock().expect("ws state mutex poisoned");
            let Some(user_connections) = connections.get(&account_id) else {
                return;
            };

            for (connection_id, sender) in user_connections {
                if sender.send(frame.clone()).is_err() {
                    stale_connections.push(*connection_id);
                }
            }
        }

        for connection_id in stale_connections {
            self.unregister(account_id, connection_id);
        }
    }
}
