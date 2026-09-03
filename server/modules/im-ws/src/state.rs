use std::{
    collections::HashMap,
    sync::{Arc, Mutex, OnceLock},
};

use tokio::sync::mpsc;
use uuid::Uuid;

pub type OutboundSender = mpsc::UnboundedSender<Vec<u8>>;
pub type OutboundReceiver = mpsc::UnboundedReceiver<Vec<u8>>;

pub struct Registration {
    pub receiver: OutboundReceiver,
    pub is_first_connection: bool,
}

#[derive(Clone, Default)]
pub struct WsState {
    inner: Arc<Mutex<HashMap<i64, HashMap<Uuid, OutboundSender>>>>,
}

static SHARED_WS_STATE: OnceLock<WsState> = OnceLock::new();

pub fn shared_ws_state() -> WsState {
    SHARED_WS_STATE.get_or_init(WsState::default).clone()
}

impl WsState {
    pub fn register(&self, account_id: i64, connection_id: Uuid) -> Registration {
        let (sender, receiver) = mpsc::unbounded_channel();
        let mut connections = self.inner.lock().expect("ws state mutex poisoned");
        let user_connections = connections.entry(account_id).or_default();
        let is_first_connection = user_connections.is_empty();
        user_connections.insert(connection_id, sender);
        Registration {
            receiver,
            is_first_connection,
        }
    }

    pub fn unregister(&self, account_id: i64, connection_id: Uuid) -> bool {
        let mut connections = self.inner.lock().expect("ws state mutex poisoned");
        let Some(user_connections) = connections.get_mut(&account_id) else {
            return false;
        };

        if user_connections.remove(&connection_id).is_none() {
            return false;
        }
        if user_connections.is_empty() {
            connections.remove(&account_id);
            return true;
        }
        false
    }

    pub fn is_online(&self, account_id: i64) -> bool {
        self.inner
            .lock()
            .expect("ws state mutex poisoned")
            .contains_key(&account_id)
    }

    pub fn online_subset(&self, account_ids: &[i64]) -> Vec<i64> {
        let connections = self.inner.lock().expect("ws state mutex poisoned");
        account_ids
            .iter()
            .copied()
            .filter(|account_id| connections.contains_key(account_id))
            .collect()
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
            let _ = self.unregister(account_id, connection_id);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::WsState;
    use uuid::Uuid;

    #[test]
    fn only_first_connection_and_last_disconnect_change_presence() {
        let state = WsState::default();
        let account_id = 7;
        let first_id = Uuid::new_v4();
        let second_id = Uuid::new_v4();

        let first = state.register(account_id, first_id);
        let second = state.register(account_id, second_id);
        assert!(first.is_first_connection);
        assert!(!second.is_first_connection);
        assert!(state.is_online(account_id));
        assert!(!state.unregister(account_id, first_id));
        assert!(state.is_online(account_id));
        assert!(state.unregister(account_id, second_id));
        assert!(!state.is_online(account_id));
    }

    #[test]
    fn online_subset_keeps_requested_order() {
        let state = WsState::default();
        let _second = state.register(2, Uuid::new_v4());
        let _fourth = state.register(4, Uuid::new_v4());

        assert_eq!(state.online_subset(&[4, 3, 2]), vec![4, 2]);
    }
}
