use axum::{
    Router,
    routing::{get, post},
};
use flash_core::SharedContext;

use crate::handler;

pub fn register_user_routes(router: Router<SharedContext>) -> Router<SharedContext> {
    router
        .route(
            "/user/profile",
            get(handler::profile).put(handler::update_profile),
        )
        .route(
            "/user/password",
            post(handler::set_password).put(handler::change_password),
        )
}
