mod models;
mod repository;
mod routes;
pub mod service;

pub use models::ConversationListItem;

use axum::Router;
use flash_core::SharedContext;

pub fn router() -> Router<SharedContext> {
    routes::router()
}
