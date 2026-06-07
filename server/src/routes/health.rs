use axum::{Json, response::IntoResponse};

use crate::{models::common::VersionResponse, response::utf8_json};

pub async fn version() -> impl IntoResponse {
    utf8_json(Json(VersionResponse {
        name: env!("CARGO_PKG_NAME"),
        version: env!("CARGO_PKG_VERSION"),
    }))
}
