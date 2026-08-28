mod models;
pub mod notification;
mod repository;
mod routes;
pub mod service;

pub use models::ConversationListItem;

use axum::Router;
use flash_core::SharedContext;
use notification::{GroupCreationNotifier, NoopGroupCreationNotifier};
use std::sync::Arc;

pub fn router() -> Router<SharedContext> {
    router_with_notifier(Arc::new(NoopGroupCreationNotifier))
}

pub fn router_with_notifier<N>(notifier: Arc<N>) -> Router<SharedContext>
where
    N: GroupCreationNotifier + 'static,
{
    routes::router_with_notifier(notifier)
}
