use axum::{response::{IntoResponse, Response}, http::StatusCode, Json};
use serde_json::json;

#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("Unauthorized")]
    Unauthorized,
    #[error("Not found: {0}")]
    NotFound(String),
    #[error("Bad request: {0}")]
    BadRequest(String),
    #[error("Database error: {0}")]
    Db(#[from] sqlx::Error),
    #[error("Internal error: {0}")]
    Internal(#[from] anyhow::Error),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, msg) = match &self {
            AppError::Unauthorized      => (StatusCode::UNAUTHORIZED, self.to_string()),
            AppError::NotFound(m)       => (StatusCode::NOT_FOUND, m.clone()),
            AppError::BadRequest(m)     => (StatusCode::BAD_REQUEST, m.clone()),
            AppError::Db(_)             => (StatusCode::INTERNAL_SERVER_ERROR, "DB error".into()),
            AppError::Internal(_)       => (StatusCode::INTERNAL_SERVER_ERROR, "Internal error".into()),
        };
        (status, Json(json!({ "error": msg }))).into_response()
    }
}
