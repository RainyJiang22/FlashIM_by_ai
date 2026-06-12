use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
};

#[derive(Clone, Copy, Debug)]
pub struct AppError {
    status: StatusCode,
    message: &'static str,
}

pub type AppResult<T> = Result<T, AppError>;

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
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        crate::response::json_error(self.status, self.message)
    }
}
