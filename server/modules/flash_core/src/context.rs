use crate::{
    config::AppConfig,
    runtime::{chat_room::ChatRoomStore, postgres::PostgresRuntime},
};
use std::{error::Error, fmt, sync::Arc, time::Duration};

#[derive(Clone)]
pub struct AppContext {
    pub postgres: Arc<PostgresRuntime>,
    pub chat_room_store: Arc<ChatRoomStore>,
    pub jwt_secret: Arc<String>,
    pub jwt_ttl: Duration,
    pub sms_code_ttl: Duration,
    pub expose_debug_sms_code: bool,
}

pub type SharedContext = Arc<AppContext>;

impl AppContext {
    pub async fn from_config(config: AppConfig) -> Result<Self, ContextInitError> {
        let postgres = PostgresRuntime::connect(&config.database_url)
            .await
            .map_err(ContextInitError::DatabaseConnect)?;
        postgres
            .run_migrations()
            .await
            .map_err(ContextInitError::DatabaseMigrate)?;

        Ok(Self {
            postgres: Arc::new(postgres),
            chat_room_store: Arc::new(ChatRoomStore::default()),
            jwt_secret: Arc::new(config.jwt_secret),
            jwt_ttl: config.jwt_ttl,
            sms_code_ttl: config.sms_code_ttl,
            expose_debug_sms_code: config.expose_debug_sms_code,
        })
    }

    pub fn new_for_tests(jwt_secret: impl Into<String>) -> Self {
        let config = AppConfig::for_tests(jwt_secret);
        let postgres = PostgresRuntime::new_lazy(&config.database_url)
            .expect("test postgres runtime should initialize lazily");

        Self {
            postgres: Arc::new(postgres),
            chat_room_store: Arc::new(ChatRoomStore::default()),
            jwt_secret: Arc::new(config.jwt_secret),
            jwt_ttl: config.jwt_ttl,
            sms_code_ttl: config.sms_code_ttl,
            expose_debug_sms_code: config.expose_debug_sms_code,
        }
    }
}

#[derive(Debug)]
pub enum ContextInitError {
    DatabaseConnect(sqlx::Error),
    DatabaseMigrate(sqlx::migrate::MigrateError),
}

impl fmt::Display for ContextInitError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::DatabaseConnect(error) => write!(f, "failed to connect database: {error}"),
            Self::DatabaseMigrate(error) => write!(f, "failed to run migrations: {error}"),
        }
    }
}

impl Error for ContextInitError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            Self::DatabaseConnect(error) => Some(error),
            Self::DatabaseMigrate(error) => Some(error),
        }
    }
}
