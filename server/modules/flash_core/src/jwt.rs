use crate::{AppContext, AppError, AppResult};
use axum::http::{HeaderMap, header};
use jsonwebtoken::{DecodingKey, Validation, decode};
use serde::Deserialize;

#[allow(dead_code)]
#[derive(Deserialize)]
struct AuthClaims {
    account_id: i64,
    exp: usize,
}

pub fn extract_token(headers: &HeaderMap) -> Option<&str> {
    headers
        .get(header::AUTHORIZATION)
        .and_then(|value| value.to_str().ok())
        .and_then(|value| value.strip_prefix("Bearer ").or(Some(value)))
        .or_else(|| headers.get("token").and_then(|value| value.to_str().ok()))
}

pub fn extract_user_id(context: &AppContext, headers: &HeaderMap) -> AppResult<i64> {
    let token = extract_token(headers).ok_or(AppError::unauthorized("missing token"))?;
    let claims = decode::<AuthClaims>(
        token,
        &DecodingKey::from_secret(context.jwt_secret.as_bytes()),
        &Validation::default(),
    )
    .map_err(|_| AppError::unauthorized("invalid token"))?;

    Ok(claims.claims.account_id)
}
