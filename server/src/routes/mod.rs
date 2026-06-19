use axum::{Router, routing::get};
use flash_auth::{SharedAuthStore, register_auth_routes};
use flash_core::SharedContext;
use flash_user::router as build_user_router;

pub mod conversation;
pub mod health;
pub mod ws;

pub fn build_router(state: SharedContext, auth_store: SharedAuthStore) -> Router {
    let router = Router::new()
        .route("/v", get(health::version))
        .route("/conversation", get(conversation::conversations))
        .route("/ws", get(ws::websocket_handler))
        .route("/chat_room/ws", get(ws::chat_room_websocket_handler))
        .merge(build_user_router());

    register_auth_routes(router)
        .layer(axum::Extension(auth_store))
        .with_state(state)
}
