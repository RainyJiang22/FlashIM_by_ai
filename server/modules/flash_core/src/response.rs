use axum::{
    Json,
    http::{HeaderValue, header},
    response::{IntoResponse, Response},
};

pub fn utf8_json<T>(json: Json<T>) -> Response
where
    Json<T>: IntoResponse,
{
    let mut response = json.into_response();
    response.headers_mut().insert(
        header::CONTENT_TYPE,
        HeaderValue::from_static("application/json; charset=utf-8"),
    );
    response
}
