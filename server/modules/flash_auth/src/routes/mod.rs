use axum::{Router, routing::post};
use flash_core::SharedContext;

pub mod auth;

pub fn register_auth_routes(router: Router<SharedContext>) -> Router<SharedContext> {
    router
        .route("/auth/sms", post(auth::send_sms_code))
        .route("/auth/login", post(auth::login))
        .route("/auth/password/set", post(auth::set_password))
        .route("/auth/password/change", post(auth::change_password))
}
