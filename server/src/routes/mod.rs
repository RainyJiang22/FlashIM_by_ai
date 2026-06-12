use axum::{
    Router,
    routing::{get, post},
};

use crate::state::SharedState;

pub mod auth;
pub mod conversation;
pub mod health;
pub mod user;
pub mod ws;

pub fn build_router(state: SharedState) -> Router {
    Router::new()
        .route("/v", get(health::version))
        .route("/conversation", get(conversation::conversations))
        .route("/ws", get(ws::websocket_handler))
        .route("/chat_room/ws", get(ws::chat_room_websocket_handler))
        .route("/auth/sms", post(auth::send_sms_code))
        .route("/auth/login", post(auth::login))
        .route("/auth/password/set", post(auth::set_password))
        .route("/auth/password/change", post(auth::change_password))
        .route("/user/profile", get(user::user_profile))
        .with_state(state)
}
