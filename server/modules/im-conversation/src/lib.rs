mod models;
mod repository;
mod routes;
mod service;

use axum::Router;
use flash_core::SharedContext;

pub fn router() -> Router<SharedContext> {
    routes::router()
}
