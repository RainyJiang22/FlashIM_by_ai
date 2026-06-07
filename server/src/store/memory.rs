use std::{
    collections::HashMap,
    sync::atomic::{AtomicU64, Ordering},
};

use tokio::sync::{RwLock, mpsc};

use crate::{
    auth::password::{PasswordAccountRecord, seeded_password_accounts},
    models::user::UserRecord,
};

#[derive(Clone)]
pub struct ChatRoomConnection {
    pub sender: mpsc::UnboundedSender<String>,
}

pub struct InMemoryStore {
    sms_codes: RwLock<HashMap<String, String>>,
    users_by_id: RwLock<HashMap<u64, UserRecord>>,
    user_ids_by_phone: RwLock<HashMap<String, u64>>,
    password_accounts: RwLock<HashMap<String, PasswordAccountRecord>>,
    chat_connections: RwLock<HashMap<usize, ChatRoomConnection>>,
    next_user_id: AtomicU64,
    next_chat_message_id: AtomicU64,
}

impl InMemoryStore {
    pub fn new() -> Self {
        let mut users_by_id = HashMap::new();
        let mut user_ids_by_phone = HashMap::new();
        let mut password_accounts = HashMap::new();
        let mut max_user_id = 0_u64;

        for (password_account, user) in seeded_password_accounts() {
            max_user_id = max_user_id.max(user.user_id);
            user_ids_by_phone.insert(user.phone.clone(), user.user_id);
            users_by_id.insert(user.user_id, user);
            password_accounts.insert(password_account.account.clone(), password_account);
        }

        Self {
            sms_codes: RwLock::new(HashMap::new()),
            users_by_id: RwLock::new(users_by_id),
            user_ids_by_phone: RwLock::new(user_ids_by_phone),
            password_accounts: RwLock::new(password_accounts),
            chat_connections: RwLock::new(HashMap::new()),
            next_user_id: AtomicU64::new(max_user_id + 1),
            next_chat_message_id: AtomicU64::new(1),
        }
    }

    pub async fn save_sms_code(&self, phone: String, code: String) {
        self.sms_codes.write().await.insert(phone, code);
    }

    pub async fn consume_sms_code(&self, phone: &str, code: &str) -> bool {
        let mut sms_codes = self.sms_codes.write().await;
        match sms_codes.get(phone) {
            Some(stored_code) if stored_code == code => {
                sms_codes.remove(phone);
                true
            }
            _ => false,
        }
    }

    pub async fn user_by_id(&self, user_id: u64) -> Option<UserRecord> {
        self.users_by_id.read().await.get(&user_id).cloned()
    }

    pub async fn user_by_phone(&self, phone: &str) -> Option<UserRecord> {
        let user_id = self.user_ids_by_phone.read().await.get(phone).copied();
        match user_id {
            Some(user_id) => self.user_by_id(user_id).await,
            None => None,
        }
    }

    pub async fn verify_password_account(
        &self,
        account: &str,
        password: &str,
    ) -> Option<UserRecord> {
        let user_id = self
            .password_accounts
            .read()
            .await
            .get(account)
            .filter(|record| record.password == password)
            .map(|record| record.user_id);

        match user_id {
            Some(user_id) => self.user_by_id(user_id).await,
            None => None,
        }
    }

    pub async fn find_or_create_user(&self, phone: &str, avatar: String) -> UserRecord {
        {
            if let Some(user) = self.user_by_phone(phone).await {
                return user;
            }
        }

        let mut user_ids_by_phone = self.user_ids_by_phone.write().await;
        if let Some(user_id) = user_ids_by_phone.get(phone).copied()
            && let Some(user) = self.users_by_id.read().await.get(&user_id).cloned()
        {
            return user;
        }

        let user_id = self.next_user_id.fetch_add(1, Ordering::Relaxed);
        let user = UserRecord {
            user_id,
            nickname: phone.to_string(),
            avatar,
            phone: phone.to_string(),
        };

        user_ids_by_phone.insert(phone.to_string(), user_id);
        self.users_by_id.write().await.insert(user_id, user.clone());
        user
    }

    pub fn next_chat_message_id(&self) -> u64 {
        self.next_chat_message_id.fetch_add(1, Ordering::Relaxed)
    }

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
}
