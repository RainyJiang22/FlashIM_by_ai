use axum::{Router, routing::get};
use flash_auth::{SharedAuthStore, register_auth_routes};
use flash_core::SharedContext;

pub mod conversation;
pub mod health;
pub mod user;
pub mod ws;

pub fn build_router(state: SharedContext, auth_store: SharedAuthStore) -> Router {
    register_auth_routes(
        Router::new()
            .route("/v", get(health::version))
            .route("/conversation", get(conversation::conversations))
            .route("/user/profile", get(user::user_profile))
            .route("/ws", get(ws::websocket_handler))
            .route("/chat_room/ws", get(ws::chat_room_websocket_handler)),
    )
    .layer(axum::Extension(auth_store))
    .with_state(state)
}
