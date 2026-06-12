use std::{error::Error, fmt, sync::Arc, time::Duration};

use crate::{
    config::AppConfig,
    store::{AuthStore, memory::ChatRoomStore, postgres::PostgresStore},
};

#[derive(Clone)]
pub struct AppState {
    pub(crate) auth_store: Arc<dyn AuthStore>,
    pub(crate) chat_room_store: Arc<ChatRoomStore>,
    pub(crate) jwt_secret: Arc<String>,
    pub(crate) jwt_ttl: Duration,
    pub(crate) sms_code_ttl: Duration,
    pub(crate) expose_debug_sms_code: bool,
}

pub type SharedState = Arc<AppState>;

impl AppState {
    pub async fn from_config(config: AppConfig) -> Result<Self, StateInitError> {
        let store = PostgresStore::connect(&config.database_url)
            .await
            .map_err(StateInitError::database)?;
        store
            .run_migrations()
            .await
            .map_err(StateInitError::migration)?;

        Ok(Self::from_auth_store(Arc::new(store), config))
    }

    #[cfg(test)]
    pub fn new_for_tests(jwt_secret: impl Into<String>) -> Self {
        Self::from_auth_store(
            Arc::new(crate::store::memory::InMemoryStore::new()),
            AppConfig::for_tests(jwt_secret),
        )
    }

    fn from_auth_store(auth_store: Arc<dyn AuthStore>, config: AppConfig) -> Self {
        Self {
            auth_store,
            chat_room_store: Arc::new(ChatRoomStore::new()),
            jwt_secret: Arc::new(config.jwt_secret),
            jwt_ttl: config.jwt_ttl,
            sms_code_ttl: config.sms_code_ttl,
            expose_debug_sms_code: config.expose_debug_sms_code,
        }
    }
}

#[derive(Debug)]
pub struct StateInitError {
    message: String,
}

impl StateInitError {
    fn database(error: sqlx::Error) -> Self {
        Self {
            message: format!("failed to connect database: {error}"),
        }
    }

    fn migration(error: sqlx::migrate::MigrateError) -> Self {
        Self {
            message: format!("failed to run migrations: {error}"),
        }
    }
}

impl fmt::Display for StateInitError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.message)
    }
}

impl Error for StateInitError {}
