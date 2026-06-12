pub mod auth;
pub mod config;
pub mod error;
pub mod models;
pub mod response;
pub mod routes;
pub mod services;
pub mod state;
pub mod store;

use axum::Router;
use state::SharedState;

pub fn build_app(state: SharedState) -> Router {
    routes::build_router(state)
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::{
        body::{Body, to_bytes},
        http::{Request, StatusCode, header},
    };
    use futures_util::{SinkExt, StreamExt};
    use std::{sync::Arc, time::Duration};
    use tokio::net::TcpListener;
    use tokio_tungstenite::{connect_async, tungstenite::Message as TungsteniteMessage};
    use tower::ServiceExt;

    use crate::{
        auth::jwt::sign_token,
        models::{
            auth::{LoginResponse, PasswordUpdatedResponse, SetPasswordResponse, SmsResponse},
            user::ProfileResponse,
        },
        services::user_service::find_or_create_account_by_phone,
    };

    #[tokio::test]
    async fn auth_flow_returns_profile_for_valid_token() {
        let state = Arc::new(state::AppState::new_for_tests("test-secret"));
        let app = build_app(state.clone());

        let sms_request = Request::builder()
            .method("POST")
            .uri("/auth/sms")
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(r#"{"phone":"13800138000"}"#))
            .unwrap();
        let sms_response = app.clone().oneshot(sms_request).await.unwrap();
        assert_eq!(sms_response.status(), StatusCode::OK);

        let sms_body = to_bytes(sms_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let sms: SmsResponse = serde_json::from_slice(&sms_body).unwrap();
        assert_eq!(sms.phone, "13800138000");
        assert_eq!(sms.code.len(), 6);

        let login_request = Request::builder()
            .method("POST")
            .uri("/auth/login")
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(
                serde_json::json!({
                    "login_type": "sms_code",
                    "phone": sms.phone,
                    "code": sms.code,
                })
                .to_string(),
            ))
            .unwrap();
        let login_response = app.clone().oneshot(login_request).await.unwrap();
        assert_eq!(login_response.status(), StatusCode::OK);

        let login_body = to_bytes(login_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let login: LoginResponse = serde_json::from_slice(&login_body).unwrap();
        assert!(!login.token.is_empty());
        assert!(login.account_id >= 10001);
        assert!(login.password_setup_required);

        let profile_request = Request::builder()
            .method("GET")
            .uri("/user/profile")
            .header(header::AUTHORIZATION, format!("Bearer {}", login.token))
            .body(Body::empty())
            .unwrap();
        let profile_response = app.clone().oneshot(profile_request).await.unwrap();
        assert_eq!(profile_response.status(), StatusCode::OK);

        let profile_body = to_bytes(profile_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let profile: ProfileResponse = serde_json::from_slice(&profile_body).unwrap();
        assert_eq!(profile.account_id, login.account_id);
        assert_eq!(profile.nickname, "13800138000");
        assert_eq!(profile.phone, "13800138000");
        assert!(!profile.has_password);
        assert!(profile.avatar.starts_with("https://picsum.photos/seed/"));
        assert!(profile.avatar.ends_with("/120/120"));

        let set_password_request = Request::builder()
            .method("POST")
            .uri("/auth/password/set")
            .header(header::AUTHORIZATION, format!("Bearer {}", login.token))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(r#"{"new_password":"new-password"}"#))
            .unwrap();
        let set_password_response = app.clone().oneshot(set_password_request).await.unwrap();
        assert_eq!(set_password_response.status(), StatusCode::OK);

        let set_password_body = to_bytes(set_password_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let set_password: SetPasswordResponse = serde_json::from_slice(&set_password_body).unwrap();
        assert!(!set_password.password_setup_required);

        let profile_request = Request::builder()
            .method("GET")
            .uri("/user/profile")
            .header(header::AUTHORIZATION, format!("Bearer {}", login.token))
            .body(Body::empty())
            .unwrap();
        let profile_response = app.clone().oneshot(profile_request).await.unwrap();
        assert_eq!(profile_response.status(), StatusCode::OK);

        let profile_body = to_bytes(profile_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let profile: ProfileResponse = serde_json::from_slice(&profile_body).unwrap();
        assert!(profile.has_password);

        let change_password_request = Request::builder()
            .method("POST")
            .uri("/auth/password/change")
            .header(header::AUTHORIZATION, format!("Bearer {}", login.token))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(
                r#"{"old_password":"new-password","new_password":"new-password-2"}"#,
            ))
            .unwrap();
        let change_password_response = app.clone().oneshot(change_password_request).await.unwrap();
        assert_eq!(change_password_response.status(), StatusCode::OK);

        let change_password_body = to_bytes(change_password_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let _: PasswordUpdatedResponse = serde_json::from_slice(&change_password_body).unwrap();

        let password_login_request = Request::builder()
            .method("POST")
            .uri("/auth/login")
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(
                serde_json::json!({
                    "login_type": "password",
                    "identifier": "13800138000",
                    "password": "new-password-2",
                })
                .to_string(),
            ))
            .unwrap();
        let password_login_response = app.oneshot(password_login_request).await.unwrap();
        assert_eq!(password_login_response.status(), StatusCode::OK);

        let password_login_body = to_bytes(password_login_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let password_login: LoginResponse = serde_json::from_slice(&password_login_body).unwrap();
        assert_eq!(password_login.account_id, login.account_id);
        assert!(!password_login.password_setup_required);
    }

    #[tokio::test]
    async fn missing_or_invalid_token_returns_401() {
        let state = Arc::new(state::AppState::new_for_tests("test-secret"));
        let app = build_app(state);

        let missing_token_request = Request::builder()
            .method("GET")
            .uri("/user/profile")
            .body(Body::empty())
            .unwrap();
        let missing_token_response = app.clone().oneshot(missing_token_request).await.unwrap();
        assert_eq!(missing_token_response.status(), StatusCode::UNAUTHORIZED);

        let invalid_token_request = Request::builder()
            .method("GET")
            .uri("/user/profile")
            .header(header::AUTHORIZATION, "Bearer invalid-token")
            .body(Body::empty())
            .unwrap();
        let invalid_token_response = app.oneshot(invalid_token_request).await.unwrap();
        assert_eq!(invalid_token_response.status(), StatusCode::UNAUTHORIZED);
    }

    #[tokio::test]
    async fn set_password_rejects_duplicate_setup() {
        let state = Arc::new(state::AppState::new_for_tests("test-secret"));
        let app = build_app(state);

        let sms_request = Request::builder()
            .method("POST")
            .uri("/auth/sms")
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(r#"{"phone":"13800138009"}"#))
            .unwrap();
        let sms_response = app.clone().oneshot(sms_request).await.unwrap();
        let sms_body = to_bytes(sms_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let sms: SmsResponse = serde_json::from_slice(&sms_body).unwrap();

        let login_request = Request::builder()
            .method("POST")
            .uri("/auth/login")
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(
                serde_json::json!({
                    "login_type": "sms_code",
                    "phone": sms.phone,
                    "code": sms.code,
                })
                .to_string(),
            ))
            .unwrap();
        let login_response = app.clone().oneshot(login_request).await.unwrap();
        assert_eq!(login_response.status(), StatusCode::OK);

        let login_body = to_bytes(login_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let login: LoginResponse = serde_json::from_slice(&login_body).unwrap();
        let set_password_request = Request::builder()
            .method("POST")
            .uri("/auth/password/set")
            .header(header::AUTHORIZATION, format!("Bearer {}", login.token))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(r#"{"new_password":"new-password"}"#))
            .unwrap();
        let set_password_response = app.clone().oneshot(set_password_request).await.unwrap();
        assert_eq!(set_password_response.status(), StatusCode::OK);

        let duplicate_request = Request::builder()
            .method("POST")
            .uri("/auth/password/set")
            .header(header::AUTHORIZATION, format!("Bearer {}", login.token))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(r#"{"new_password":"another-password"}"#))
            .unwrap();
        let duplicate_response = app.oneshot(duplicate_request).await.unwrap();
        assert_eq!(duplicate_response.status(), StatusCode::CONFLICT);
    }

    #[tokio::test]
    async fn chat_room_websocket_requires_valid_token() {
        let state = Arc::new(state::AppState::new_for_tests("test-secret"));
        let app = build_app(state);
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let address = listener.local_addr().unwrap();
        let server_task = tokio::spawn(async move {
            axum::serve(listener, app).await.unwrap();
        });

        let url = format!("ws://{address}/chat_room/ws?token=invalid-token");
        let error = connect_async(url).await.expect_err("handshake should fail");
        assert!(error.to_string().contains("401"));

        server_task.abort();
    }

    #[tokio::test]
    async fn chat_room_websocket_supports_auth_ping_and_chat() {
        let state = Arc::new(state::AppState::new_for_tests("test-secret"));
        let user = find_or_create_account_by_phone(state.as_ref(), "13800138000")
            .await
            .unwrap();
        let token = sign_token(state.as_ref(), user.account_id).unwrap();
        let app = build_app(state.clone());

        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let address = listener.local_addr().unwrap();
        let server_task = tokio::spawn(async move {
            axum::serve(listener, app).await.unwrap();
        });

        let url = format!("ws://{address}/chat_room/ws?token={token}");
        let (mut stream, _) = connect_async(url).await.unwrap();

        let auth_ready = next_text_message(&mut stream).await;
        assert!(auth_ready.contains("\"type\":\"auth_ready\""));
        assert!(auth_ready.contains(&format!("\"user_id\":{}", user.account_id)));

        stream
            .send(TungsteniteMessage::Text(
                serde_json::json!({ "type": "ping" }).to_string().into(),
            ))
            .await
            .unwrap();
        let pong_message = next_text_message(&mut stream).await;
        assert!(pong_message.contains("\"type\":\"pong\""));

        stream
            .send(TungsteniteMessage::Text(
                serde_json::json!({ "type": "chat", "text": "hello chat room" })
                    .to_string()
                    .into(),
            ))
            .await
            .unwrap();
        let user_chat = next_text_message(&mut stream).await;
        assert!(user_chat.contains("\"type\":\"chat\""));
        assert!(user_chat.contains("\"text\":\"hello chat room\""));
        assert!(user_chat.contains(&format!("\"user_id\":{}", user.account_id)));

        server_task.abort();
    }

    async fn next_text_message(
        stream: &mut tokio_tungstenite::WebSocketStream<
            tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>,
        >,
    ) -> String {
        let message = tokio::time::timeout(Duration::from_secs(3), stream.next())
            .await
            .expect("expected websocket message")
            .expect("stream should stay open")
            .expect("message should be ok");

        match message {
            TungsteniteMessage::Text(text) => text.to_string(),
            other => panic!("expected text message, got {other:?}"),
        }
    }
}
