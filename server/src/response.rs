use axum::{
    Json,
    http::{StatusCode, header},
    response::{IntoResponse, Response},
};

use crate::models::common::ErrorResponse;

pub fn utf8_json<T>(json: Json<T>) -> Response
where
    Json<T>: IntoResponse,
{
    (
        [(header::CONTENT_TYPE, "application/json; charset=utf-8")],
        json,
    )
        .into_response()
}

pub fn json_error(status: StatusCode, message: &'static str) -> Response {
    (status, utf8_json(Json(ErrorResponse { message }))).into_response()
}
