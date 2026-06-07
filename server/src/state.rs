use std::sync::Arc;

use crate::store::memory::InMemoryStore;

#[derive(Clone)]
pub struct AppState {
    pub(crate) store: Arc<InMemoryStore>,
    pub(crate) jwt_secret: Arc<String>,
}

pub type SharedState = Arc<AppState>;

impl AppState {
    pub fn new(jwt_secret: impl Into<String>) -> Self {
        Self {
            store: Arc::new(InMemoryStore::new()),
            jwt_secret: Arc::new(jwt_secret.into()),
        }
    }
}
