use axum::{Router, routing::get};
use flash_core::SharedContext;

pub mod dispatcher;
pub mod frame;
pub mod handler;
pub mod proto;

pub fn router() -> Router<SharedContext> {
    Router::new().route("/ws/im", get(handler::ws_handler))
}
