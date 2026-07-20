use app_storage::router as build_storage_router;
use axum::{Router, routing::get};
use flash_auth::{SharedAuthStore, register_auth_routes};
use flash_core::SharedContext;
use flash_user::router as build_user_router;
use im_conversation::router as build_im_conversation_router;
use im_friend::router_with_broadcaster as build_im_friend_router;
use im_message::router as build_im_message_router;
use im_ws::router as build_im_ws_router;
use im_ws::{broadcaster::WsBroadcaster, state::shared_ws_state};
use std::sync::Arc;

pub mod conversation;
pub mod health;
pub mod ws;

pub fn build_router(state: SharedContext, auth_store: SharedAuthStore) -> Router {
    let friend_broadcaster = Arc::new(WsBroadcaster::new(
        shared_ws_state(),
        state.postgres.pool().clone(),
    ));
    let router = Router::new()
        .route("/v", get(health::version))
        .route("/conversation", get(conversation::conversations))
        .route("/ws", get(ws::websocket_handler))
        .route("/chat_room/ws", get(ws::chat_room_websocket_handler))
        .merge(build_storage_router())
        .merge(build_user_router())
        .merge(build_im_ws_router())
        .merge(build_im_message_router())
        .merge(build_im_conversation_router())
        .merge(build_im_friend_router(friend_broadcaster));

    register_auth_routes(router)
        .layer(axum::Extension(auth_store))
        .with_state(state)
}
