use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
};
use serde::Serialize;

pub type AppResult<T> = Result<T, AppError>;

#[derive(Clone, Copy, Debug)]
pub struct AppError {
    status: StatusCode,
    message: &'static str,
}

impl AppError {
    pub const fn bad_request(message: &'static str) -> Self {
        Self {
            status: StatusCode::BAD_REQUEST,
            message,
        }
    }

    pub const fn unauthorized(message: &'static str) -> Self {
        Self {
            status: StatusCode::UNAUTHORIZED,
            message,
        }
    }

    pub const fn not_found(message: &'static str) -> Self {
        Self {
            status: StatusCode::NOT_FOUND,
            message,
        }
    }

    pub const fn conflict(message: &'static str) -> Self {
        Self {
            status: StatusCode::CONFLICT,
            message,
        }
    }

    pub const fn internal_server_error(message: &'static str) -> Self {
        Self {
            status: StatusCode::INTERNAL_SERVER_ERROR,
            message,
        }
    }

    pub const fn status(&self) -> StatusCode {
        self.status
    }

    pub const fn message(&self) -> &'static str {
        self.message
    }
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let body = axum::Json(ErrorResponse {
            message: self.message,
        });
        (self.status, body).into_response()
    }
}

#[derive(Serialize)]
struct ErrorResponse {
    message: &'static str,
}
