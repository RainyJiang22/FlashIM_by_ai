use axum::http::{HeaderMap, header};
use jsonwebtoken::{DecodingKey, EncodingKey, Header, Validation, decode, encode};
use std::time::{SystemTime, UNIX_EPOCH};

use crate::{config::JWT_TTL, models::auth::AuthClaims, state::AppState};

pub(crate) fn sign_token(
    state: &AppState,
    user_id: u64,
) -> Result<String, jsonwebtoken::errors::Error> {
    let claims = AuthClaims {
        user_id,
        exp: (unix_timestamp() + JWT_TTL.as_secs()) as usize,
    };

    encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(state.jwt_secret.as_bytes()),
    )
}

pub(crate) fn decode_token(
    state: &AppState,
    token: &str,
) -> Result<AuthClaims, jsonwebtoken::errors::Error> {
    decode::<AuthClaims>(
        token,
        &DecodingKey::from_secret(state.jwt_secret.as_bytes()),
        &Validation::default(),
    )
    .map(|data| data.claims)
}

pub fn extract_token(headers: &HeaderMap) -> Option<&str> {
    headers
        .get(header::AUTHORIZATION)
        .and_then(|value| value.to_str().ok())
        .and_then(|value| value.strip_prefix("Bearer ").or(Some(value)))
        .or_else(|| headers.get("token").and_then(|value| value.to_str().ok()))
}

fn unix_timestamp() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}
