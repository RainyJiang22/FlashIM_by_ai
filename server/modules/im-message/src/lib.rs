pub mod broadcast;
pub mod models;
pub mod repository;
pub mod routes;
pub mod seq;
pub mod service;

use axum::Router;
use flash_core::SharedContext;

pub fn router() -> Router<SharedContext> {
    routes::router()
}
