pub mod models;
pub mod routes;
pub mod services;

use axum::Router;
use flash_auth::SharedAuthStore;
use flash_core::SharedContext;
use tower_http::services::ServeDir;

pub fn build_app(state: SharedContext, auth_store: SharedAuthStore) -> Router {
    routes::build_router(state, auth_store).nest_service("/uploads", ServeDir::new("uploads"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::{
        body::{Body, to_bytes},
        http::{Request, StatusCode, header},
    };
    use futures_util::{SinkExt, StreamExt};
    use im_ws::{
        frame,
        proto::{AuthResult, ConversationUpdate, MessageAck, WsFrameType},
    };
    use std::{net::SocketAddr, path::PathBuf, sync::Arc, time::Duration};
    use tokio::{net::TcpListener, task::JoinHandle};
    use tokio_tungstenite::{connect_async, tungstenite::Message as TungsteniteMessage};
    use tower::ServiceExt;

    use flash_auth::{
        InMemoryStore,
        jwt::sign_token,
        models::auth::{LoginResponse, SmsResponse},
        services::user_service::find_or_create_account_by_phone,
    };
    use flash_core::AppContext;
    use flash_user::model::{MessageResponse, UserProfileResponse};

    const TEST_PNG: &[u8] = &[
        137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6,
        0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84, 120, 156, 99, 248, 207, 192, 240,
        31, 0, 5, 0, 1, 255, 137, 153, 61, 29, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
    ];

    fn build_test_app() -> (SharedContext, SharedAuthStore, Router) {
        let context = Arc::new(AppContext::new_for_tests("test-secret"));
        let auth_store: SharedAuthStore = Arc::new(InMemoryStore::new());
        let app = build_app(context.clone(), auth_store.clone());
        (context, auth_store, app)
    }

    #[tokio::test]
    async fn auth_flow_returns_profile_for_valid_token() {
        let (_, _, app) = build_test_app();

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
        let profile: UserProfileResponse = serde_json::from_slice(&profile_body).unwrap();
        assert_eq!(profile.account_id, login.account_id);
        assert_eq!(profile.nickname, "13800138000");
        assert_eq!(profile.phone, "13800138000");
        assert_eq!(profile.signature, "");
        assert!(!profile.has_password);
        assert_eq!(profile.avatar, format!("identicon:{}", login.account_id));

        let set_password_request = Request::builder()
            .method("POST")
            .uri("/user/password")
            .header(header::AUTHORIZATION, format!("Bearer {}", login.token))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(r#"{"new_password":"new-password"}"#))
            .unwrap();
        let set_password_response = app.clone().oneshot(set_password_request).await.unwrap();
        assert_eq!(set_password_response.status(), StatusCode::OK);

        let set_password_body = to_bytes(set_password_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let set_password: MessageResponse = serde_json::from_slice(&set_password_body).unwrap();
        assert_eq!(set_password.message, "password set successfully");

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
        let profile: UserProfileResponse = serde_json::from_slice(&profile_body).unwrap();
        assert!(profile.has_password);

        let change_password_request = Request::builder()
            .method("PUT")
            .uri("/user/password")
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
        let change_password: MessageResponse =
            serde_json::from_slice(&change_password_body).unwrap();
        assert_eq!(change_password.message, "password changed successfully");

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
        let (_, _, app) = build_test_app();

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
    async fn conversations_route_requires_authentication() {
        let (_, _, app) = build_test_app();

        let request = Request::builder()
            .method("GET")
            .uri("/conversations?limit=20&offset=0")
            .body(Body::empty())
            .unwrap();
        let response = app.oneshot(request).await.unwrap();

        assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
    }

    #[tokio::test]
    async fn conversation_messages_route_requires_authentication() {
        let (_, _, app) = build_test_app();

        let request = Request::builder()
            .method("GET")
            .uri("/conversations/00000000-0000-0000-0000-000000000001/messages")
            .body(Body::empty())
            .unwrap();
        let response = app.oneshot(request).await.unwrap();

        assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
    }

    #[tokio::test]
    async fn conversation_detail_route_requires_authentication() {
        let (_, _, app) = build_test_app();

        let request = Request::builder()
            .method("GET")
            .uri("/conversations/00000000-0000-0000-0000-000000000001")
            .body(Body::empty())
            .unwrap();
        let response = app.oneshot(request).await.unwrap();

        assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
    }

    #[tokio::test]
    async fn conversation_read_route_requires_authentication() {
        let (_, _, app) = build_test_app();

        let request = Request::builder()
            .method("POST")
            .uri("/conversations/00000000-0000-0000-0000-000000000001/read")
            .body(Body::empty())
            .unwrap();
        let response = app.oneshot(request).await.unwrap();

        assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
    }

    #[tokio::test]
    async fn upload_image_route_returns_urls_and_static_files_are_accessible() {
        let (_, _, app) = build_test_app();
        let boundary = "----flash-im-boundary-image";
        let body = multipart_body(
            boundary,
            &[multipart_file_part(
                "file",
                "test.png",
                "image/png",
                TEST_PNG,
            )],
        );

        let request = Request::builder()
            .method("POST")
            .uri("/api/upload/image")
            .header(
                header::CONTENT_TYPE,
                format!("multipart/form-data; boundary={boundary}"),
            )
            .body(Body::from(body))
            .unwrap();
        let response = app.clone().oneshot(request).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
        let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
        let original_url = json["original_url"].as_str().unwrap();
        let thumbnail_url = json["thumbnail_url"].as_str().unwrap();

        for url in [original_url, thumbnail_url] {
            let request = Request::builder()
                .method("GET")
                .uri(url)
                .body(Body::empty())
                .unwrap();
            let response = app.clone().oneshot(request).await.unwrap();
            assert_eq!(response.status(), StatusCode::OK);
            cleanup_upload_url(url).await;
        }
    }

    #[tokio::test]
    async fn upload_image_route_rejects_unsupported_content_type() {
        let (_, _, app) = build_test_app();
        let boundary = "----flash-im-boundary-image-invalid-type";
        let body = multipart_body(
            boundary,
            &[multipart_file_part(
                "file",
                "test.png",
                "application/pdf",
                TEST_PNG,
            )],
        );

        let request = Request::builder()
            .method("POST")
            .uri("/api/upload/image")
            .header(
                header::CONTENT_TYPE,
                format!("multipart/form-data; boundary={boundary}"),
            )
            .body(Body::from(body))
            .unwrap();
        let response = app.oneshot(request).await.unwrap();

        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    }

    #[tokio::test]
    async fn upload_image_route_rejects_invalid_image_bytes() {
        let (_, _, app) = build_test_app();
        let boundary = "----flash-im-boundary-image-invalid-bytes";
        let body = multipart_body(
            boundary,
            &[multipart_file_part(
                "file",
                "test.png",
                "image/png",
                b"not-a-real-image",
            )],
        );

        let request = Request::builder()
            .method("POST")
            .uri("/api/upload/image")
            .header(
                header::CONTENT_TYPE,
                format!("multipart/form-data; boundary={boundary}"),
            )
            .body(Body::from(body))
            .unwrap();
        let response = app.oneshot(request).await.unwrap();

        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    }

    #[tokio::test]
    async fn upload_video_and_file_routes_return_expected_shapes() {
        let (_, _, app) = build_test_app();

        let boundary = "----flash-im-boundary-video";
        let body = multipart_body(
            boundary,
            &[
                multipart_file_part("video", "clip.mp4", "video/mp4", b"fake-video"),
                multipart_file_part("thumbnail", "thumb.jpg", "image/jpeg", b"fake-thumb"),
                multipart_text_part("duration_ms", "5000"),
                multipart_text_part("width", "1280"),
                multipart_text_part("height", "720"),
            ],
        );
        let request = Request::builder()
            .method("POST")
            .uri("/api/upload/video")
            .header(
                header::CONTENT_TYPE,
                format!("multipart/form-data; boundary={boundary}"),
            )
            .body(Body::from(body))
            .unwrap();
        let response = app.clone().oneshot(request).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);
        let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
        let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
        let video_url = json["video_url"].as_str().unwrap();
        let thumb_url = json["thumbnail_url"].as_str().unwrap();
        cleanup_upload_url(video_url).await;
        cleanup_upload_url(thumb_url).await;

        let boundary = "----flash-im-boundary-file";
        let body = multipart_body(
            boundary,
            &[multipart_file_part(
                "file",
                "report.pdf",
                "application/pdf",
                b"fake-pdf",
            )],
        );
        let request = Request::builder()
            .method("POST")
            .uri("/api/upload/file")
            .header(
                header::CONTENT_TYPE,
                format!("multipart/form-data; boundary={boundary}"),
            )
            .body(Body::from(body))
            .unwrap();
        let response = app.clone().oneshot(request).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);
        let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
        let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
        let file_url = json["file_url"].as_str().unwrap();
        cleanup_upload_url(file_url).await;
    }

    #[test]
    fn message_frame_types_round_trip() {
        let ack = MessageAck {
            message_id: "00000000-0000-0000-0000-000000000001".to_string(),
            seq: 7,
        };
        let ack_frame = frame::message_ack_frame(ack);
        let (frame_type, payload) = frame::decode_frame(&ack_frame).unwrap();
        assert_eq!(frame_type, WsFrameType::MessageAck);
        assert!(!payload.is_empty());

        let update = ConversationUpdate {
            conversation_id: "00000000-0000-0000-0000-000000000001".to_string(),
            last_message_preview: "hello".to_string(),
            last_message_at: "2026-03-30T00:00:00Z".to_string(),
            unread_count: 1,
            total_unread: 3,
        };
        let update_frame = frame::conversation_update_frame(update);
        let (frame_type, payload) = frame::decode_frame(&update_frame).unwrap();
        assert_eq!(frame_type, WsFrameType::ConversationUpdate);
        assert!(!payload.is_empty());
    }

    #[tokio::test]
    async fn set_password_rejects_duplicate_setup() {
        let (_, _, app) = build_test_app();

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
            .uri("/user/password")
            .header(header::AUTHORIZATION, format!("Bearer {}", login.token))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(r#"{"new_password":"new-password"}"#))
            .unwrap();
        let set_password_response = app.clone().oneshot(set_password_request).await.unwrap();
        assert_eq!(set_password_response.status(), StatusCode::OK);

        let duplicate_request = Request::builder()
            .method("POST")
            .uri("/user/password")
            .header(header::AUTHORIZATION, format!("Bearer {}", login.token))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(r#"{"new_password":"another-password"}"#))
            .unwrap();
        let duplicate_response = app.oneshot(duplicate_request).await.unwrap();
        assert_eq!(duplicate_response.status(), StatusCode::CONFLICT);
    }

    #[tokio::test]
    async fn update_profile_returns_updated_user() {
        let (_, _, app) = build_test_app();

        let sms_request = Request::builder()
            .method("POST")
            .uri("/auth/sms")
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(r#"{"phone":"13800138111"}"#))
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
        let login_body = to_bytes(login_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let login: LoginResponse = serde_json::from_slice(&login_body).unwrap();

        let update_request = Request::builder()
            .method("PUT")
            .uri("/user/profile")
            .header(header::AUTHORIZATION, format!("Bearer {}", login.token))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(
                r#"{"nickname":"Alice","signature":"hello","avatar":"identicon:new-seed"}"#,
            ))
            .unwrap();
        let update_response = app.oneshot(update_request).await.unwrap();
        assert_eq!(update_response.status(), StatusCode::OK);

        let update_body = to_bytes(update_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let profile: UserProfileResponse = serde_json::from_slice(&update_body).unwrap();
        assert_eq!(profile.nickname, "Alice");
        assert_eq!(profile.signature, "hello");
        assert_eq!(profile.avatar, "identicon:new-seed");
        assert_eq!(profile.phone, "13800138111");
    }

    #[tokio::test]
    async fn change_password_rejects_wrong_old_password() {
        let (_, _, app) = build_test_app();

        let sms_request = Request::builder()
            .method("POST")
            .uri("/auth/sms")
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(r#"{"phone":"13800138112"}"#))
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
        let login_body = to_bytes(login_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let login: LoginResponse = serde_json::from_slice(&login_body).unwrap();

        let set_password_request = Request::builder()
            .method("POST")
            .uri("/user/password")
            .header(header::AUTHORIZATION, format!("Bearer {}", login.token))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(r#"{"new_password":"new-password"}"#))
            .unwrap();
        let set_password_response = app.clone().oneshot(set_password_request).await.unwrap();
        assert_eq!(set_password_response.status(), StatusCode::OK);

        let change_password_request = Request::builder()
            .method("PUT")
            .uri("/user/password")
            .header(header::AUTHORIZATION, format!("Bearer {}", login.token))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(
                r#"{"old_password":"wrong-password","new_password":"new-password-2"}"#,
            ))
            .unwrap();
        let change_password_response = app.oneshot(change_password_request).await.unwrap();
        assert_eq!(change_password_response.status(), StatusCode::UNAUTHORIZED);
    }

    #[tokio::test]
    async fn chat_room_websocket_requires_valid_token() {
        let (_, _, app) = build_test_app();
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
        let (context, auth_store, app) = build_test_app();
        let user = find_or_create_account_by_phone(auth_store.as_ref(), "13800138000")
            .await
            .unwrap();
        let token = sign_token(context.as_ref(), user.account_id).unwrap();

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

    fn multipart_file_part<'a>(
        name: &'a str,
        filename: &'a str,
        content_type: &'a str,
        bytes: &'a [u8],
    ) -> MultipartPart<'a> {
        MultipartPart::File {
            name,
            filename,
            content_type,
            bytes,
        }
    }

    fn multipart_text_part<'a>(name: &'a str, value: &'a str) -> MultipartPart<'a> {
        MultipartPart::Text { name, value }
    }

    fn multipart_body(boundary: &str, parts: &[MultipartPart<'_>]) -> Vec<u8> {
        let mut body = Vec::new();

        for part in parts {
            body.extend_from_slice(format!("--{boundary}\r\n").as_bytes());
            match part {
                MultipartPart::File {
                    name,
                    filename,
                    content_type,
                    bytes,
                } => {
                    body.extend_from_slice(
                        format!(
                            "Content-Disposition: form-data; name=\"{name}\"; filename=\"{filename}\"\r\n"
                        )
                        .as_bytes(),
                    );
                    body.extend_from_slice(
                        format!("Content-Type: {content_type}\r\n\r\n").as_bytes(),
                    );
                    body.extend_from_slice(bytes);
                    body.extend_from_slice(b"\r\n");
                }
                MultipartPart::Text { name, value } => {
                    body.extend_from_slice(
                        format!("Content-Disposition: form-data; name=\"{name}\"\r\n\r\n")
                            .as_bytes(),
                    );
                    body.extend_from_slice(value.as_bytes());
                    body.extend_from_slice(b"\r\n");
                }
            }
        }

        body.extend_from_slice(format!("--{boundary}--\r\n").as_bytes());
        body
    }

    async fn cleanup_upload_url(url: &str) {
        let local = PathBuf::from("uploads").join(url.trim_start_matches("/uploads/"));
        let _ = tokio::fs::remove_file(&local).await;

        let mut current = local.parent().map(PathBuf::from);
        while let Some(path) = current {
            if path == PathBuf::from("uploads") {
                let _ = tokio::fs::remove_dir(&path).await;
                break;
            }
            if tokio::fs::remove_dir(&path).await.is_err() {
                break;
            }
            current = path.parent().map(PathBuf::from);
        }
    }

    enum MultipartPart<'a> {
        File {
            name: &'a str,
            filename: &'a str,
            content_type: &'a str,
            bytes: &'a [u8],
        },
        Text {
            name: &'a str,
            value: &'a str,
        },
    }

    #[tokio::test]
    async fn im_websocket_rejects_invalid_auth_frame() {
        let (_, _, app) = build_test_app();
        let (address, server_task) = spawn_test_server(app).await;

        let url = format!("ws://{address}/ws/im");
        let (mut stream, _) = connect_async(url).await.unwrap();

        stream
            .send(TungsteniteMessage::Binary(
                frame::auth_request_frame("invalid-token").into(),
            ))
            .await
            .unwrap();

        let auth_result = next_auth_result(&mut stream).await;
        assert!(!auth_result.success);
        assert_eq!(auth_result.message, "invalid token");

        server_task.abort();
    }

    #[tokio::test]
    async fn im_websocket_accepts_valid_auth_frame() {
        let (context, auth_store, app) = build_test_app();
        let user = find_or_create_account_by_phone(auth_store.as_ref(), "13800138001")
            .await
            .unwrap();
        let token = sign_token(context.as_ref(), user.account_id).unwrap();
        let (address, server_task) = spawn_test_server(app).await;

        let url = format!("ws://{address}/ws/im");
        let (mut stream, _) = connect_async(url).await.unwrap();

        stream
            .send(TungsteniteMessage::Binary(
                frame::auth_request_frame(token).into(),
            ))
            .await
            .unwrap();

        let auth_result = next_auth_result(&mut stream).await;
        assert!(auth_result.success);
        assert_eq!(auth_result.message, "ok");

        server_task.abort();
    }

    #[tokio::test]
    async fn im_websocket_replies_pong_after_auth() {
        let (context, auth_store, app) = build_test_app();
        let user = find_or_create_account_by_phone(auth_store.as_ref(), "13800138002")
            .await
            .unwrap();
        let token = sign_token(context.as_ref(), user.account_id).unwrap();
        let (address, server_task) = spawn_test_server(app).await;

        let url = format!("ws://{address}/ws/im");
        let (mut stream, _) = connect_async(url).await.unwrap();

        stream
            .send(TungsteniteMessage::Binary(
                frame::auth_request_frame(token).into(),
            ))
            .await
            .unwrap();
        let auth_result = next_auth_result(&mut stream).await;
        assert!(auth_result.success);

        stream
            .send(TungsteniteMessage::Binary(frame::ping_frame().into()))
            .await
            .unwrap();

        let message = next_binary_message(&mut stream).await;
        let (frame_type, payload) = frame::decode_frame(&message).unwrap();
        assert_eq!(frame_type, WsFrameType::Pong);
        assert!(payload.is_empty());

        server_task.abort();
    }

    async fn spawn_test_server(app: Router) -> (SocketAddr, JoinHandle<()>) {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let address = listener.local_addr().unwrap();
        let server_task = tokio::spawn(async move {
            axum::serve(listener, app).await.unwrap();
        });

        (address, server_task)
    }

    async fn next_auth_result(
        stream: &mut tokio_tungstenite::WebSocketStream<
            tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>,
        >,
    ) -> AuthResult {
        let message = next_binary_message(stream).await;
        let (frame_type, payload) = frame::decode_frame(&message).unwrap();
        assert_eq!(frame_type, WsFrameType::AuthResult);
        frame::decode_auth_result_payload(&payload).unwrap()
    }

    async fn next_binary_message(
        stream: &mut tokio_tungstenite::WebSocketStream<
            tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>,
        >,
    ) -> Vec<u8> {
        let message = tokio::time::timeout(Duration::from_secs(3), stream.next())
            .await
            .expect("expected websocket message")
            .expect("stream should stay open")
            .expect("message should be ok");

        match message {
            TungsteniteMessage::Binary(bytes) => bytes.to_vec(),
            other => panic!("expected binary message, got {other:?}"),
        }
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
