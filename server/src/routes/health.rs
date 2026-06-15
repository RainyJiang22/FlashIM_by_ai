use axum::{Json, response::IntoResponse};
use flash_core::response::utf8_json;

use crate::models::common::VersionResponse;

pub async fn version() -> impl IntoResponse {
    utf8_json(Json(VersionResponse {
        name: env!("CARGO_PKG_NAME"),
        version: env!("CARGO_PKG_VERSION"),
    }))
}
