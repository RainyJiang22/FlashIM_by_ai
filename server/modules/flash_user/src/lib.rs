pub mod handler;
pub mod model;
pub mod routes;

use axum::Router;
use flash_core::SharedContext;

pub use routes::register_user_routes;

pub fn router() -> Router<SharedContext> {
    register_user_routes(Router::new())
}
