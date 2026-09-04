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
    use async_trait::async_trait;
    use axum::{
        body::{Body, to_bytes},
        http::{Request, StatusCode, header},
    };
    use futures_util::{SinkExt, StreamExt};
    use im_message::{
        broadcast::MessageBroadcaster,
        service::{
            ConversationUpdate as DomainConversationUpdate, MessagePayload, MessageService,
            SendMessageInput,
        },
    };
    use im_ws::{
        frame,
        proto::{
            AuthResult, ConversationUpdate, FriendRequestEvent, FriendUser,
            GroupJoinRequestNotification, MessageAck, WsFrameType,
        },
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
    use flash_core::{AppContext, AppError, AppResult};
    use flash_user::model::{MessageResponse, UserProfileResponse};

    const TEST_PNG: &[u8] = &[
        137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6,
        0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84, 120, 156, 99, 248, 207, 192, 240,
        31, 0, 5, 0, 1, 255, 137, 153, 61, 29, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
    ];

    #[derive(Clone)]
    struct FailingBroadcaster;

    #[async_trait]
    impl MessageBroadcaster for FailingBroadcaster {
        async fn broadcast_message(
            &self,
            _message: MessagePayload,
            _member_ids: &[i64],
            _exclude_sender: Option<i64>,
        ) -> AppResult<()> {
            Err(AppError::internal_server_error("test broadcast failure"))
        }

        async fn broadcast_conversation_updates(
            &self,
            _updates: Vec<DomainConversationUpdate>,
            _member_ids: &[i64],
        ) -> AppResult<()> {
            Err(AppError::internal_server_error("test broadcast failure"))
        }
    }

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
    async fn create_group_conversation_route_requires_authentication() {
        let (_, _, app) = build_test_app();

        let request = Request::builder()
            .method("POST")
            .uri("/conversations")
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(
                r#"{"type":"group","name":"测试群","member_ids":[10002,10003]}"#,
            ))
            .unwrap();
        let response = app.oneshot(request).await.unwrap();

        assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
    }

    #[tokio::test]
    async fn group_conversation_routes_round_trip_against_configured_database() {
        let Ok(config) = flash_core::AppConfig::from_env() else {
            return;
        };
        let context = Arc::new(
            AppContext::from_config(config)
                .await
                .expect("configured test database should connect"),
        );
        let pool = context.postgres.pool();
        let marker = format!("{:016x}", rand::random::<u64>());
        let mut user_ids = Vec::new();
        for index in 0..5 {
            let account_id = sqlx::query_scalar::<_, i64>(
                r#"
                INSERT INTO accounts (primary_identifier)
                VALUES ($1)
                RETURNING id
                "#,
            )
            .bind(format!("group-route-test-{marker}-{index}"))
            .fetch_one(pool)
            .await
            .expect("test account should be inserted");
            sqlx::query(
                r#"
                INSERT INTO user_profiles (account_id, nickname, avatar_url)
                VALUES ($1, $2, $3)
                "#,
            )
            .bind(account_id)
            .bind(format!("群成员{index}"))
            .bind(format!("identicon:{account_id}"))
            .execute(pool)
            .await
            .expect("test profile should be inserted");
            user_ids.push(account_id);
        }

        let owner_id = user_ids[0];
        for friend_id in &user_ids[1..3] {
            sqlx::query(
                r#"
                INSERT INTO friend_relations (user_id, friend_user_id)
                VALUES ($1, $2)
                "#,
            )
            .bind(owner_id)
            .bind(friend_id)
            .execute(pool)
            .await
            .expect("test friendship should be inserted");
        }

        let token = sign_token(context.as_ref(), owner_id).expect("test token should sign");
        let auth_store: SharedAuthStore = Arc::new(InMemoryStore::new());
        let app = build_app(context.clone(), auth_store);
        let create_request = Request::builder()
            .method("POST")
            .uri("/conversations")
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(
                serde_json::json!({
                    "type": "group",
                    "name": "数据库路由测试群",
                    "member_ids": [user_ids[1], user_ids[2]],
                })
                .to_string(),
            ))
            .unwrap();
        let create_response = app.clone().oneshot(create_request).await.unwrap();
        assert_eq!(create_response.status(), StatusCode::OK);
        let create_body = to_bytes(create_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let created: serde_json::Value = serde_json::from_slice(&create_body).unwrap();
        assert_eq!(created["type"], 1);
        assert_eq!(created["owner_id"], owner_id.to_string());
        assert_eq!(
            created["avatar"],
            format!(
                "grid:identicon:{},identicon:{},identicon:{}",
                user_ids[0], user_ids[1], user_ids[2]
            )
        );
        assert_eq!(created["member_avatars"].as_array().unwrap().len(), 3);
        let conversation_id = created["id"].as_str().unwrap();

        let history_request = Request::builder()
            .method("GET")
            .uri(format!("/conversations/{conversation_id}/messages"))
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .body(Body::empty())
            .unwrap();
        let history_response = app.clone().oneshot(history_request).await.unwrap();
        assert_eq!(history_response.status(), StatusCode::OK);
        let history_body = to_bytes(history_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let messages: Vec<serde_json::Value> = serde_json::from_slice(&history_body).unwrap();
        assert_eq!(messages.len(), 1);
        assert_eq!(messages[0]["seq"], 1);
        assert_eq!(messages[0]["msg_type"], 5);
        assert_eq!(messages[0]["sender_id"], owner_id.to_string());
        assert_eq!(messages[0]["content"], "群成员0 创建了群聊");
        assert_eq!(messages[0]["extra"]["system_event"], "group_created");

        let unread_counts = sqlx::query_as::<_, (i64, i32)>(
            r#"
            SELECT user_id, unread_count
            FROM conversation_members
            WHERE conversation_id = $1
            ORDER BY user_id
            "#,
        )
        .bind(conversation_id.parse::<sqlx::types::Uuid>().unwrap())
        .fetch_all(pool)
        .await
        .expect("group unread counts should load");
        assert_eq!(
            unread_counts
                .iter()
                .find(|(user_id, _)| *user_id == owner_id)
                .map(|(_, count)| *count),
            Some(0)
        );
        for member_id in &user_ids[1..3] {
            assert_eq!(
                unread_counts
                    .iter()
                    .find(|(user_id, _)| user_id == member_id)
                    .map(|(_, count)| *count),
                Some(1)
            );
        }

        let list_request = Request::builder()
            .method("GET")
            .uri("/conversations?type=1&limit=100&offset=0")
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .body(Body::empty())
            .unwrap();
        let list_response = app.clone().oneshot(list_request).await.unwrap();
        assert_eq!(list_response.status(), StatusCode::OK);
        let list_body = to_bytes(list_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let groups: Vec<serde_json::Value> = serde_json::from_slice(&list_body).unwrap();
        let created_group = groups
            .iter()
            .find(|item| item["id"] == conversation_id)
            .expect("created group should be listed");
        assert_eq!(created_group["last_message_preview"], "群成员0 创建了群聊");

        let detail_request = Request::builder()
            .method("GET")
            .uri(format!("/conversations/{conversation_id}"))
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .body(Body::empty())
            .unwrap();
        let detail_response = app.clone().oneshot(detail_request).await.unwrap();
        assert_eq!(detail_response.status(), StatusCode::OK);

        let invalid_request = Request::builder()
            .method("POST")
            .uri("/conversations")
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(
                serde_json::json!({
                    "type": "group",
                    "name": "包含非好友",
                    "member_ids": [user_ids[1], user_ids[3]],
                })
                .to_string(),
            ))
            .unwrap();
        let invalid_response = app.clone().oneshot(invalid_request).await.unwrap();
        assert_eq!(invalid_response.status(), StatusCode::BAD_REQUEST);

        let group_detail_request = Request::builder()
            .method("GET")
            .uri(format!("/groups/{conversation_id}"))
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .body(Body::empty())
            .unwrap();
        let group_detail_response = app.clone().oneshot(group_detail_request).await.unwrap();
        assert_eq!(group_detail_response.status(), StatusCode::OK);
        let group_detail_body = to_bytes(group_detail_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let group_detail: serde_json::Value = serde_json::from_slice(&group_detail_body).unwrap();
        assert_eq!(group_detail["member_count"], 3);
        assert_eq!(group_detail["current_user_role"], "owner");
        assert_eq!(group_detail["current_user_nickname"], "群成员0");
        assert_eq!(group_detail["avatar"], created["avatar"]);

        let nickname_request = Request::builder()
            .method("PATCH")
            .uri(format!("/groups/{conversation_id}/nickname"))
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(r#"{"nickname":"  项目负责人  "}"#))
            .unwrap();
        let nickname_response = app.clone().oneshot(nickname_request).await.unwrap();
        assert_eq!(nickname_response.status(), StatusCode::OK);
        let nickname_body = to_bytes(nickname_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let nickname_detail: serde_json::Value = serde_json::from_slice(&nickname_body).unwrap();
        assert_eq!(nickname_detail["current_user_nickname"], "项目负责人");
        let owner_member = nickname_detail["members"]
            .as_array()
            .unwrap()
            .iter()
            .find(|member| member["account_id"] == owner_id.to_string())
            .unwrap();
        assert_eq!(owner_member["nickname"], "项目负责人");

        let renamed_history_request = Request::builder()
            .method("GET")
            .uri(format!("/conversations/{conversation_id}/messages"))
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .body(Body::empty())
            .unwrap();
        let renamed_history_response = app.clone().oneshot(renamed_history_request).await.unwrap();
        assert_eq!(renamed_history_response.status(), StatusCode::OK);
        let renamed_history_body = to_bytes(renamed_history_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let renamed_messages: Vec<serde_json::Value> =
            serde_json::from_slice(&renamed_history_body).unwrap();
        assert_eq!(renamed_messages[0]["sender_name"], "项目负责人");

        let broadcast_failure_output = MessageService::new(Arc::new(FailingBroadcaster))
            .send(
                &context,
                SendMessageInput {
                    conversation_id: conversation_id.parse::<sqlx::types::Uuid>().unwrap(),
                    sender_id: owner_id,
                    msg_type: 0,
                    content: "广播失败不回滚消息".to_string(),
                    extra: None,
                },
            )
            .await
            .expect("committed message should not fail when broadcast fails");
        assert_eq!(
            broadcast_failure_output.message.content,
            "广播失败不回滚消息"
        );

        let rename_request = Request::builder()
            .method("PATCH")
            .uri(format!("/groups/{conversation_id}/name"))
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(r#"{"name":"路由管理测试群"}"#))
            .unwrap();
        let rename_response = app.clone().oneshot(rename_request).await.unwrap();
        assert_eq!(rename_response.status(), StatusCode::OK);

        let announcement_request = Request::builder()
            .method("PATCH")
            .uri(format!("/groups/{conversation_id}/announcement"))
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(r#"{"announcement":"  周五发布  "}"#))
            .unwrap();
        let announcement_response = app.clone().oneshot(announcement_request).await.unwrap();
        assert_eq!(announcement_response.status(), StatusCode::OK);
        let announcement_body = to_bytes(announcement_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let announcement: serde_json::Value = serde_json::from_slice(&announcement_body).unwrap();
        assert_eq!(announcement["announcement"], "周五发布");
        assert_eq!(
            announcement["announcement_updated_by"],
            owner_id.to_string()
        );

        let settings_request = Request::builder()
            .method("PATCH")
            .uri(format!("/groups/{conversation_id}/settings"))
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(r#"{"join_approval_required":true}"#))
            .unwrap();
        let settings_response = app.clone().oneshot(settings_request).await.unwrap();
        assert_eq!(settings_response.status(), StatusCode::OK);

        sqlx::query(
            r#"
            INSERT INTO friend_relations (user_id, friend_user_id)
            SELECT $1, friend_id
            FROM UNNEST($2::BIGINT[]) AS friend_id
            "#,
        )
        .bind(user_ids[1])
        .bind(&user_ids[3..5])
        .execute(pool)
        .await
        .expect("member friendship should be inserted");
        let member_token =
            sign_token(context.as_ref(), user_ids[1]).expect("member token should sign");
        let invitee_token =
            sign_token(context.as_ref(), user_ids[3]).expect("invitee token should sign");

        let transfer_request = Request::builder()
            .method("PATCH")
            .uri(format!("/groups/{conversation_id}/owner"))
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(
                serde_json::json!({"owner_id": user_ids[1]}).to_string(),
            ))
            .unwrap();
        let transfer_response = app.clone().oneshot(transfer_request).await.unwrap();
        assert_eq!(transfer_response.status(), StatusCode::OK);

        let former_owner_rename_request = Request::builder()
            .method("PATCH")
            .uri(format!("/groups/{conversation_id}/name"))
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(r#"{"name":"不应成功"}"#))
            .unwrap();
        let former_owner_rename_response = app
            .clone()
            .oneshot(former_owner_rename_request)
            .await
            .unwrap();
        assert_eq!(former_owner_rename_response.status(), StatusCode::FORBIDDEN);

        let transfer_back_request = Request::builder()
            .method("PATCH")
            .uri(format!("/groups/{conversation_id}/owner"))
            .header(header::AUTHORIZATION, format!("Bearer {member_token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(
                serde_json::json!({"owner_id": owner_id}).to_string(),
            ))
            .unwrap();
        let transfer_back_response = app.clone().oneshot(transfer_back_request).await.unwrap();
        assert_eq!(transfer_back_response.status(), StatusCode::OK);

        let owner_leave_request = Request::builder()
            .method("POST")
            .uri(format!("/groups/{conversation_id}/leave"))
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .body(Body::empty())
            .unwrap();
        let owner_leave_response = app.clone().oneshot(owner_leave_request).await.unwrap();
        assert_eq!(owner_leave_response.status(), StatusCode::BAD_REQUEST);

        let direct_add_request = Request::builder()
            .method("POST")
            .uri(format!("/groups/{conversation_id}/members"))
            .header(header::AUTHORIZATION, format!("Bearer {member_token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(
                serde_json::json!({"member_ids": [user_ids[3]]}).to_string(),
            ))
            .unwrap();
        let direct_add_response = app.clone().oneshot(direct_add_request).await.unwrap();
        assert_eq!(direct_add_response.status(), StatusCode::FORBIDDEN);

        let invalid_batch_request = Request::builder()
            .method("POST")
            .uri(format!("/groups/{conversation_id}/invitations"))
            .header(header::AUTHORIZATION, format!("Bearer {member_token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(
                serde_json::json!({"member_ids": [user_ids[3], user_ids[2]]}).to_string(),
            ))
            .unwrap();
        let invalid_batch_response = app.clone().oneshot(invalid_batch_request).await.unwrap();
        assert_eq!(invalid_batch_response.status(), StatusCode::BAD_REQUEST);
        let pending_after_invalid = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(*) FROM group_invitations WHERE conversation_id = $1 AND invitee_id = $2 AND status = 0",
        )
        .bind(conversation_id.parse::<sqlx::types::Uuid>().unwrap())
        .bind(user_ids[3])
        .fetch_one(pool)
        .await
        .expect("pending invitation count should load");
        assert_eq!(pending_after_invalid, 0);

        let delivery_trigger = format!("group_invitation_delivery_failure_{marker}");
        let delivery_function = format!("group_invitation_delivery_failure_fn_{marker}");
        sqlx::query(&format!(
            r#"
            CREATE FUNCTION {delivery_function}() RETURNS trigger AS $function$
            BEGIN
                IF NEW.type = 4 AND EXISTS(
                    SELECT 1 FROM conversation_members
                    WHERE conversation_id = NEW.conversation_id
                      AND user_id = {}
                ) THEN
                    RAISE EXCEPTION 'forced invitation delivery failure';
                END IF;
                RETURN NEW;
            END;
            $function$ LANGUAGE plpgsql
            "#,
            user_ids[4]
        ))
        .execute(pool)
        .await
        .expect("delivery failure function should be installed");
        sqlx::query(&format!(
            "CREATE TRIGGER {delivery_trigger} BEFORE INSERT ON messages FOR EACH ROW EXECUTE FUNCTION {delivery_function}()"
        ))
        .execute(pool)
        .await
        .expect("delivery failure trigger should be installed");

        let invite_request = Request::builder()
            .method("POST")
            .uri(format!("/groups/{conversation_id}/invitations"))
            .header(header::AUTHORIZATION, format!("Bearer {member_token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(
                serde_json::json!({"member_ids": [user_ids[3], user_ids[4]]}).to_string(),
            ))
            .unwrap();
        let invite_response = app.clone().oneshot(invite_request).await.unwrap();
        sqlx::query(&format!("DROP TRIGGER {delivery_trigger} ON messages"))
            .execute(pool)
            .await
            .expect("delivery failure trigger should be removed");
        sqlx::query(&format!("DROP FUNCTION {delivery_function}()"))
            .execute(pool)
            .await
            .expect("delivery failure function should be removed");
        assert_eq!(invite_response.status(), StatusCode::OK);
        let invite_body = to_bytes(invite_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let invite: serde_json::Value = serde_json::from_slice(&invite_body).unwrap();
        let invitation_items = invite["invitations"].as_array().unwrap();
        let delivered_invitation = invitation_items
            .iter()
            .find(|item| item["invitee_id"] == user_ids[3].to_string())
            .unwrap();
        assert_eq!(delivered_invitation["status"], "pending");
        assert_eq!(delivered_invitation["delivered"], true);
        let invitation_id = delivered_invitation["id"].as_str().unwrap();
        let failed_invitation = invitation_items
            .iter()
            .find(|item| item["invitee_id"] == user_ids[4].to_string())
            .unwrap();
        assert!(failed_invitation["id"].is_null());
        assert_eq!(failed_invitation["status"], "failed");
        assert_eq!(failed_invitation["delivered"], false);
        let failed_pending_count = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(*) FROM group_invitations WHERE conversation_id = $1 AND invitee_id = $2 AND status = 0",
        )
        .bind(conversation_id.parse::<sqlx::types::Uuid>().unwrap())
        .bind(user_ids[4])
        .fetch_one(pool)
        .await
        .expect("failed invitation count should load");
        assert_eq!(failed_pending_count, 0);
        let persisted_card_count = sqlx::query_scalar::<_, i64>(
            r#"
            SELECT COUNT(*)
            FROM messages
            WHERE type = 4
              AND extra->>'invitation_id' = $1
            "#,
        )
        .bind(invitation_id)
        .fetch_one(pool)
        .await
        .expect("invitation card count should load");
        assert_eq!(persisted_card_count, 1);
        let membership_before_accept = sqlx::query_scalar::<_, bool>(
            r#"
            SELECT EXISTS(
                SELECT 1 FROM conversation_members
                WHERE conversation_id = $1 AND user_id = $2 AND is_deleted = FALSE
            )
            "#,
        )
        .bind(conversation_id.parse::<sqlx::types::Uuid>().unwrap())
        .bind(user_ids[3])
        .fetch_one(pool)
        .await
        .expect("membership should load");
        assert!(!membership_before_accept);

        let accept_request = Request::builder()
            .method("POST")
            .uri(format!("/group-invitations/{invitation_id}/accept"))
            .header(header::AUTHORIZATION, format!("Bearer {invitee_token}"))
            .body(Body::empty())
            .unwrap();
        let accept_response = app.clone().oneshot(accept_request).await.unwrap();
        assert_eq!(accept_response.status(), StatusCode::OK);
        let membership_after_accept = sqlx::query_scalar::<_, bool>(
            r#"
            SELECT EXISTS(
                SELECT 1 FROM conversation_members
                WHERE conversation_id = $1 AND user_id = $2 AND is_deleted = FALSE
            )
            "#,
        )
        .bind(conversation_id.parse::<sqlx::types::Uuid>().unwrap())
        .bind(user_ids[3])
        .fetch_one(pool)
        .await
        .expect("membership should load");
        assert!(membership_after_accept);

        let avatar_after_accept =
            sqlx::query_scalar::<_, String>("SELECT avatar FROM conversations WHERE id = $1")
                .bind(conversation_id.parse::<sqlx::types::Uuid>().unwrap())
                .fetch_one(pool)
                .await
                .expect("group avatar should load after accepting invitation");
        assert_eq!(
            avatar_after_accept,
            format!(
                "grid:identicon:{},identicon:{},identicon:{},identicon:{}",
                user_ids[0], user_ids[1], user_ids[2], user_ids[3]
            )
        );
        let invited_message = sqlx::query_as::<_, (String, String)>(
            r#"
            SELECT content, extra->>'system_event'
            FROM messages
            WHERE conversation_id = $1 AND type = 5
            ORDER BY seq DESC
            LIMIT 1
            "#,
        )
        .bind(conversation_id.parse::<sqlx::types::Uuid>().unwrap())
        .fetch_one(pool)
        .await
        .expect("member invitation system message should load");
        assert_eq!(invited_message.1, "member_invited");
        assert_eq!(invited_message.0, "群成员1 邀请 群成员3 进群",);

        let remove_request = Request::builder()
            .method("DELETE")
            .uri(format!("/groups/{conversation_id}/members/{}", user_ids[2]))
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .body(Body::empty())
            .unwrap();
        let remove_response = app.clone().oneshot(remove_request).await.unwrap();
        assert_eq!(remove_response.status(), StatusCode::OK);
        let avatar_after_remove =
            sqlx::query_scalar::<_, String>("SELECT avatar FROM conversations WHERE id = $1")
                .bind(conversation_id.parse::<sqlx::types::Uuid>().unwrap())
                .fetch_one(pool)
                .await
                .expect("group avatar should load after removing member");
        assert_eq!(
            avatar_after_remove,
            format!(
                "grid:identicon:{},identicon:{},identicon:{}",
                user_ids[0], user_ids[1], user_ids[3]
            )
        );

        let leave_request = Request::builder()
            .method("POST")
            .uri(format!("/groups/{conversation_id}/leave"))
            .header(header::AUTHORIZATION, format!("Bearer {invitee_token}"))
            .body(Body::empty())
            .unwrap();
        let leave_response = app.clone().oneshot(leave_request).await.unwrap();
        assert_eq!(leave_response.status(), StatusCode::OK);

        let member_dissolve_request = Request::builder()
            .method("DELETE")
            .uri(format!("/groups/{conversation_id}"))
            .header(header::AUTHORIZATION, format!("Bearer {member_token}"))
            .body(Body::empty())
            .unwrap();
        let member_dissolve_response = app.clone().oneshot(member_dissolve_request).await.unwrap();
        assert_eq!(member_dissolve_response.status(), StatusCode::FORBIDDEN);

        let dissolve_request = Request::builder()
            .method("DELETE")
            .uri(format!("/groups/{conversation_id}"))
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .body(Body::empty())
            .unwrap();
        let dissolve_response = app.clone().oneshot(dissolve_request).await.unwrap();
        assert_eq!(dissolve_response.status(), StatusCode::OK);

        let dissolved_detail_request = Request::builder()
            .method("GET")
            .uri(format!("/groups/{conversation_id}"))
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .body(Body::empty())
            .unwrap();
        let dissolved_detail_response =
            app.clone().oneshot(dissolved_detail_request).await.unwrap();
        assert_eq!(dissolved_detail_response.status(), StatusCode::NOT_FOUND);

        let dissolved_conversation_request = Request::builder()
            .method("GET")
            .uri(format!("/conversations/{conversation_id}"))
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .body(Body::empty())
            .unwrap();
        let dissolved_conversation_response = app
            .clone()
            .oneshot(dissolved_conversation_request)
            .await
            .unwrap();
        assert_eq!(dissolved_conversation_response.status(), StatusCode::OK);
        let dissolved_conversation_body =
            to_bytes(dissolved_conversation_response.into_body(), usize::MAX)
                .await
                .unwrap();
        let dissolved_conversation: serde_json::Value =
            serde_json::from_slice(&dissolved_conversation_body).unwrap();
        assert_eq!(dissolved_conversation["is_dissolved"], true);

        let dissolved_main_list_request = Request::builder()
            .method("GET")
            .uri("/conversations?limit=100&offset=0")
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .body(Body::empty())
            .unwrap();
        let dissolved_main_list_response = app
            .clone()
            .oneshot(dissolved_main_list_request)
            .await
            .unwrap();
        let dissolved_main_list_body =
            to_bytes(dissolved_main_list_response.into_body(), usize::MAX)
                .await
                .unwrap();
        let dissolved_main_list: Vec<serde_json::Value> =
            serde_json::from_slice(&dissolved_main_list_body).unwrap();
        assert!(dissolved_main_list.iter().any(|conversation| {
            conversation["id"] == conversation_id && conversation["is_dissolved"] == true
        }));

        let dissolved_group_list_request = Request::builder()
            .method("GET")
            .uri("/conversations?type=1&limit=100&offset=0")
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .body(Body::empty())
            .unwrap();
        let dissolved_group_list_response = app
            .clone()
            .oneshot(dissolved_group_list_request)
            .await
            .unwrap();
        let dissolved_group_list_body =
            to_bytes(dissolved_group_list_response.into_body(), usize::MAX)
                .await
                .unwrap();
        let dissolved_group_list: Vec<serde_json::Value> =
            serde_json::from_slice(&dissolved_group_list_body).unwrap();
        assert!(
            dissolved_group_list
                .iter()
                .all(|conversation| conversation["id"] != conversation_id)
        );

        let dissolved_history_request = Request::builder()
            .method("GET")
            .uri(format!("/conversations/{conversation_id}/messages"))
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .body(Body::empty())
            .unwrap();
        let dissolved_history_response = app
            .clone()
            .oneshot(dissolved_history_request)
            .await
            .unwrap();
        assert_eq!(dissolved_history_response.status(), StatusCode::OK);
        let dissolved_history_body = to_bytes(dissolved_history_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let dissolved_messages: Vec<serde_json::Value> =
            serde_json::from_slice(&dissolved_history_body).unwrap();
        assert!(dissolved_messages.iter().any(|message| {
            message["extra"]["system_event"] == "group_dissolved"
                && message["content"] == "群聊已解散"
        }));

        let dissolved_send = MessageService::new(Arc::new(FailingBroadcaster))
            .send(
                &context,
                SendMessageInput {
                    conversation_id: conversation_id.parse().unwrap(),
                    sender_id: owner_id,
                    msg_type: 0,
                    content: "不应发送".to_string(),
                    extra: None,
                },
            )
            .await;
        assert!(dissolved_send.is_err());

        let active_after_dissolve = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(*) FROM conversation_members WHERE conversation_id = $1 AND is_deleted = FALSE",
        )
        .bind(conversation_id.parse::<sqlx::types::Uuid>().unwrap())
        .fetch_one(pool)
        .await
        .expect("dissolved membership should remain readable");
        assert_eq!(active_after_dissolve, 2);

        let concurrent_group_request = Request::builder()
            .method("POST")
            .uri("/conversations")
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(
                serde_json::json!({
                    "type": "group",
                    "name": "并发解散测试群",
                    "member_ids": [user_ids[1], user_ids[2]],
                })
                .to_string(),
            ))
            .unwrap();
        let concurrent_group_response =
            app.clone().oneshot(concurrent_group_request).await.unwrap();
        assert_eq!(concurrent_group_response.status(), StatusCode::OK);
        let concurrent_group_body = to_bytes(concurrent_group_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let concurrent_group: serde_json::Value =
            serde_json::from_slice(&concurrent_group_body).unwrap();
        let concurrent_group_id = concurrent_group["id"].as_str().unwrap();

        let concurrent_settings_request = Request::builder()
            .method("PATCH")
            .uri(format!("/groups/{concurrent_group_id}/settings"))
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(r#"{"join_approval_required":true}"#))
            .unwrap();
        let concurrent_settings_response = app
            .clone()
            .oneshot(concurrent_settings_request)
            .await
            .unwrap();
        assert_eq!(concurrent_settings_response.status(), StatusCode::OK);

        let concurrent_invite_request = Request::builder()
            .method("POST")
            .uri(format!("/groups/{concurrent_group_id}/invitations"))
            .header(header::AUTHORIZATION, format!("Bearer {member_token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(
                serde_json::json!({"member_ids": [user_ids[3]]}).to_string(),
            ))
            .unwrap();
        let concurrent_invite_response = app
            .clone()
            .oneshot(concurrent_invite_request)
            .await
            .unwrap();
        assert_eq!(concurrent_invite_response.status(), StatusCode::OK);
        let concurrent_invite_body = to_bytes(concurrent_invite_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let concurrent_invite: serde_json::Value =
            serde_json::from_slice(&concurrent_invite_body).unwrap();
        let concurrent_invitation_id = concurrent_invite["invitations"][0]["id"].as_str().unwrap();

        let concurrent_accept_request = Request::builder()
            .method("POST")
            .uri(format!(
                "/group-invitations/{concurrent_invitation_id}/accept"
            ))
            .header(header::AUTHORIZATION, format!("Bearer {invitee_token}"))
            .body(Body::empty())
            .unwrap();
        let concurrent_dissolve_request = Request::builder()
            .method("DELETE")
            .uri(format!("/groups/{concurrent_group_id}"))
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .body(Body::empty())
            .unwrap();
        let (concurrent_accept_response, concurrent_dissolve_response) = tokio::join!(
            app.clone().oneshot(concurrent_accept_request),
            app.clone().oneshot(concurrent_dissolve_request),
        );
        let concurrent_accept_status = concurrent_accept_response.unwrap().status();
        assert!(matches!(
            concurrent_accept_status,
            StatusCode::OK | StatusCode::NOT_FOUND
        ));
        assert_eq!(
            concurrent_dissolve_response.unwrap().status(),
            StatusCode::OK
        );
        let concurrent_group_uuid = concurrent_group_id.parse::<sqlx::types::Uuid>().unwrap();
        let active_after_concurrent_dissolve = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(*) FROM conversation_members WHERE conversation_id = $1 AND is_deleted = FALSE",
        )
        .bind(concurrent_group_uuid)
        .fetch_one(pool)
        .await
        .expect("active member count should load");
        assert!(active_after_concurrent_dissolve >= 3);

        let capacity_invitee_a = user_ids[3];
        let capacity_invitee_b = user_ids[4];
        let capacity_member_ids = sqlx::query_scalar::<_, i64>(
            r#"
            INSERT INTO accounts (primary_identifier)
            SELECT $1 || '-' || value::TEXT
            FROM generate_series(1, 198) AS value
            RETURNING id
            "#,
        )
        .bind(format!("group-capacity-test-{marker}"))
        .fetch_all(pool)
        .await
        .expect("capacity accounts should be inserted");
        let capacity_group_id = sqlx::query_scalar::<_, sqlx::types::Uuid>(
            r#"
            INSERT INTO conversations (type, name, owner_id, join_approval_required)
            VALUES (1, '并发满员测试群', $1, TRUE)
            RETURNING id
            "#,
        )
        .bind(owner_id)
        .fetch_one(pool)
        .await
        .expect("capacity group should be inserted");
        let mut initial_capacity_members = Vec::with_capacity(199);
        initial_capacity_members.push(owner_id);
        initial_capacity_members.extend_from_slice(&capacity_member_ids);
        sqlx::query(
            r#"
            INSERT INTO conversation_members (conversation_id, user_id, is_deleted)
            SELECT $1, member_id, FALSE
            FROM UNNEST($2::BIGINT[]) AS member_id
            "#,
        )
        .bind(capacity_group_id)
        .bind(&initial_capacity_members)
        .execute(pool)
        .await
        .expect("capacity members should be inserted");
        let capacity_invitations = sqlx::query_as::<_, (sqlx::types::Uuid, i64)>(
            r#"
            INSERT INTO group_invitations (conversation_id, inviter_id, invitee_id)
            SELECT $1, $2, invitee_id
            FROM UNNEST($3::BIGINT[]) AS invitee_id
            RETURNING id, invitee_id
            "#,
        )
        .bind(capacity_group_id)
        .bind(owner_id)
        .bind(&[capacity_invitee_a, capacity_invitee_b])
        .fetch_all(pool)
        .await
        .expect("capacity invitations should be inserted");
        let capacity_invitation_a = capacity_invitations
            .iter()
            .find(|(_, invitee_id)| *invitee_id == capacity_invitee_a)
            .unwrap()
            .0;
        let capacity_invitation_b = capacity_invitations
            .iter()
            .find(|(_, invitee_id)| *invitee_id == capacity_invitee_b)
            .unwrap()
            .0;
        let (accept_a, accept_b) = tokio::join!(
            im_group::repository::accept_group_invitation(
                pool,
                capacity_invitation_a,
                capacity_invitee_a,
            ),
            im_group::repository::accept_group_invitation(
                pool,
                capacity_invitation_b,
                capacity_invitee_b,
            ),
        );
        assert_eq!(
            usize::from(accept_a.is_ok()) + usize::from(accept_b.is_ok()),
            1,
            "exactly one concurrent invitation may fill the final group slot"
        );
        let final_capacity_count = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(*) FROM conversation_members WHERE conversation_id = $1 AND is_deleted = FALSE",
        )
        .bind(capacity_group_id)
        .fetch_one(pool)
        .await
        .expect("final capacity count should load");
        assert_eq!(final_capacity_count, 200);
        sqlx::query("DELETE FROM conversations WHERE id = $1")
            .bind(capacity_group_id)
            .execute(pool)
            .await
            .expect("capacity group should be cleaned up");
        user_ids.extend(capacity_member_ids);

        sqlx::query("DELETE FROM accounts WHERE id = ANY($1)")
            .bind(&user_ids)
            .execute(pool)
            .await
            .expect("test accounts should be cleaned up");
    }

    #[tokio::test]
    async fn group_join_routes_round_trip_against_configured_database() {
        let Ok(config) = flash_core::AppConfig::from_env() else {
            return;
        };
        let context = Arc::new(
            AppContext::from_config(config)
                .await
                .expect("configured test database should connect"),
        );
        let pool = context.postgres.pool();
        let marker = format!("{:016x}", rand::random::<u64>());
        let mut user_ids = Vec::new();
        for index in 0..4 {
            let account_id = sqlx::query_scalar::<_, i64>(
                "INSERT INTO accounts (primary_identifier) VALUES ($1) RETURNING id",
            )
            .bind(format!("group-join-route-test-{marker}-{index}"))
            .fetch_one(pool)
            .await
            .expect("join test account should be inserted");
            sqlx::query(
                "INSERT INTO user_profiles (account_id, nickname, avatar_url) VALUES ($1, $2, $3)",
            )
            .bind(account_id)
            .bind(format!("入群用户{index}"))
            .bind(format!("identicon:{account_id}"))
            .execute(pool)
            .await
            .expect("join test profile should be inserted");
            user_ids.push(account_id);
        }

        let owner_id = user_ids[0];
        let group_name = format!("join-search-{marker}");
        let group_id = sqlx::query_scalar::<_, sqlx::types::Uuid>(
            r#"
            INSERT INTO conversations (type, name, avatar, owner_id, join_approval_required)
            VALUES (1, $1, $2, $3, FALSE)
            RETURNING id
            "#,
        )
        .bind(&group_name)
        .bind(format!("grid:identicon:{owner_id}"))
        .bind(owner_id)
        .fetch_one(pool)
        .await
        .expect("join test group should be inserted");
        sqlx::query(
            "INSERT INTO conversation_members (conversation_id, user_id, is_deleted) VALUES ($1, $2, FALSE)",
        )
        .bind(group_id)
        .bind(owner_id)
        .execute(pool)
        .await
        .expect("join test owner membership should be inserted");

        let owner_token = sign_token(context.as_ref(), owner_id).expect("owner token should sign");
        let applicant_a_token =
            sign_token(context.as_ref(), user_ids[1]).expect("applicant token should sign");
        let applicant_b_token =
            sign_token(context.as_ref(), user_ids[2]).expect("applicant token should sign");
        let applicant_c_token =
            sign_token(context.as_ref(), user_ids[3]).expect("applicant token should sign");
        let auth_store: SharedAuthStore = Arc::new(InMemoryStore::new());
        let app = build_app(context.clone(), auth_store);

        let search_request = Request::builder()
            .method("GET")
            .uri(format!("/groups/search?keyword={group_name}"))
            .header(header::AUTHORIZATION, format!("Bearer {applicant_a_token}"))
            .body(Body::empty())
            .unwrap();
        let search_response = app.clone().oneshot(search_request).await.unwrap();
        assert_eq!(search_response.status(), StatusCode::OK);
        let search_body = to_bytes(search_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let search: serde_json::Value = serde_json::from_slice(&search_body).unwrap();
        let search_item = &search["groups"][0];
        assert_eq!(search_item["conversation_id"], group_id.to_string());
        assert_eq!(search_item["is_member"], false);
        assert_eq!(search_item["has_pending_request"], false);
        assert_eq!(search_item["join_approval_required"], false);

        let direct_join_request = Request::builder()
            .method("POST")
            .uri(format!("/groups/{group_id}/join"))
            .header(header::AUTHORIZATION, format!("Bearer {applicant_a_token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from("{}"))
            .unwrap();
        let direct_join_response = app.clone().oneshot(direct_join_request).await.unwrap();
        assert_eq!(direct_join_response.status(), StatusCode::OK);
        let direct_join_body = to_bytes(direct_join_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let direct_join: serde_json::Value = serde_json::from_slice(&direct_join_body).unwrap();
        assert_eq!(direct_join["auto_approved"], true);
        assert_eq!(direct_join["conversation"]["id"], group_id.to_string());

        let settings_request = Request::builder()
            .method("PATCH")
            .uri(format!("/groups/{group_id}/settings"))
            .header(header::AUTHORIZATION, format!("Bearer {owner_token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(r#"{"join_approval_required":true}"#))
            .unwrap();
        let settings_response = app.clone().oneshot(settings_request).await.unwrap();
        assert_eq!(settings_response.status(), StatusCode::OK);

        let pending_join_request = Request::builder()
            .method("POST")
            .uri(format!("/groups/{group_id}/join"))
            .header(header::AUTHORIZATION, format!("Bearer {applicant_b_token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(r#"{"message":"请通过"}"#))
            .unwrap();
        let pending_join_response = app.clone().oneshot(pending_join_request).await.unwrap();
        assert_eq!(pending_join_response.status(), StatusCode::OK);
        let pending_join_body = to_bytes(pending_join_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let pending_join: serde_json::Value = serde_json::from_slice(&pending_join_body).unwrap();
        assert_eq!(pending_join["auto_approved"], false);
        let request_id = pending_join["request_id"].as_str().unwrap();

        let duplicate_request = Request::builder()
            .method("POST")
            .uri(format!("/groups/{group_id}/join"))
            .header(header::AUTHORIZATION, format!("Bearer {applicant_b_token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from("{}"))
            .unwrap();
        let duplicate_response = app.clone().oneshot(duplicate_request).await.unwrap();
        assert_eq!(duplicate_response.status(), StatusCode::CONFLICT);

        let list_request = Request::builder()
            .method("GET")
            .uri("/groups/join-requests")
            .header(header::AUTHORIZATION, format!("Bearer {owner_token}"))
            .body(Body::empty())
            .unwrap();
        let list_response = app.clone().oneshot(list_request).await.unwrap();
        assert_eq!(list_response.status(), StatusCode::OK);
        let list_body = to_bytes(list_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let list: serde_json::Value = serde_json::from_slice(&list_body).unwrap();
        assert_eq!(list["pending_count"], 1);
        assert!(
            list["requests"]
                .as_array()
                .unwrap()
                .iter()
                .any(|item| { item["id"] == request_id && item["message"] == "请通过" })
        );

        let forbidden_handle_request = Request::builder()
            .method("POST")
            .uri(format!(
                "/groups/{group_id}/join-requests/{request_id}/handle"
            ))
            .header(header::AUTHORIZATION, format!("Bearer {applicant_a_token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(r#"{"approved":true}"#))
            .unwrap();
        let forbidden_response = app.clone().oneshot(forbidden_handle_request).await.unwrap();
        assert_eq!(forbidden_response.status(), StatusCode::FORBIDDEN);

        let approve_request = Request::builder()
            .method("POST")
            .uri(format!(
                "/groups/{group_id}/join-requests/{request_id}/handle"
            ))
            .header(header::AUTHORIZATION, format!("Bearer {owner_token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(r#"{"approved":true}"#))
            .unwrap();
        let approve_response = app.clone().oneshot(approve_request).await.unwrap();
        assert_eq!(approve_response.status(), StatusCode::OK);
        let approve_body = to_bytes(approve_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let approved: serde_json::Value = serde_json::from_slice(&approve_body).unwrap();
        assert_eq!(approved["status"], "approved");

        let rejected_join_request = Request::builder()
            .method("POST")
            .uri(format!("/groups/{group_id}/join"))
            .header(header::AUTHORIZATION, format!("Bearer {applicant_c_token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(r#"{"message":"先拒绝"}"#))
            .unwrap();
        let rejected_join_response = app.clone().oneshot(rejected_join_request).await.unwrap();
        let rejected_join_body = to_bytes(rejected_join_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let rejected_join: serde_json::Value = serde_json::from_slice(&rejected_join_body).unwrap();
        let rejected_request_id = rejected_join["request_id"].as_str().unwrap();
        let reject_request = Request::builder()
            .method("POST")
            .uri(format!(
                "/groups/{group_id}/join-requests/{rejected_request_id}/handle"
            ))
            .header(header::AUTHORIZATION, format!("Bearer {owner_token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(r#"{"approved":false}"#))
            .unwrap();
        let reject_response = app.clone().oneshot(reject_request).await.unwrap();
        assert_eq!(reject_response.status(), StatusCode::OK);
        let reject_body = to_bytes(reject_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let rejected: serde_json::Value = serde_json::from_slice(&reject_body).unwrap();
        assert_eq!(rejected["status"], "rejected");

        let reapply_request = Request::builder()
            .method("POST")
            .uri(format!("/groups/{group_id}/join"))
            .header(header::AUTHORIZATION, format!("Bearer {applicant_c_token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from("{}"))
            .unwrap();
        let reapply_response = app.clone().oneshot(reapply_request).await.unwrap();
        assert_eq!(reapply_response.status(), StatusCode::OK);

        let joined_member_count = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(*) FROM conversation_members WHERE conversation_id = $1 AND is_deleted = FALSE",
        )
        .bind(group_id)
        .fetch_one(pool)
        .await
        .expect("joined member count should load");
        assert_eq!(joined_member_count, 3);
        let joined_message_count = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(*) FROM messages WHERE conversation_id = $1 AND type = 5 AND content LIKE '%加入了群聊'",
        )
        .bind(group_id)
        .fetch_one(pool)
        .await
        .expect("join system messages should load");
        assert_eq!(joined_message_count, 2);
        let joined_event_count = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(*) FROM messages WHERE conversation_id = $1 AND type = 5 AND extra->>'system_event' = 'member_joined'",
        )
        .bind(group_id)
        .fetch_one(pool)
        .await
        .expect("join system events should load");
        assert_eq!(joined_event_count, 2);

        sqlx::query("DELETE FROM conversations WHERE id = $1")
            .bind(group_id)
            .execute(pool)
            .await
            .expect("join test group should be cleaned up");
        sqlx::query("DELETE FROM accounts WHERE id = ANY($1)")
            .bind(&user_ids)
            .execute(pool)
            .await
            .expect("join test accounts should be cleaned up");
    }

    #[tokio::test]
    async fn search_routes_round_trip_against_configured_database() {
        let Ok(config) = flash_core::AppConfig::from_env() else {
            return;
        };
        let context = Arc::new(
            AppContext::from_config(config)
                .await
                .expect("configured search database should connect"),
        );
        let pool = context.postgres.pool();
        let marker = format!("{:016x}", rand::random::<u64>());
        let keyword = format!("search{marker}");
        let mut user_ids = Vec::new();
        for index in 0..3 {
            let account_id = sqlx::query_scalar::<_, i64>(
                "INSERT INTO accounts (primary_identifier) VALUES ($1) RETURNING id",
            )
            .bind(format!("search-route-test-{marker}-{index}"))
            .fetch_one(pool)
            .await
            .expect("search test account should be inserted");
            sqlx::query(
                "INSERT INTO user_profiles (account_id, nickname, avatar_url, flash_id) VALUES ($1, $2, $3, $4)",
            )
            .bind(account_id)
            .bind(if index == 1 {
                format!("friend-{keyword}")
            } else {
                format!("search-user-{index}")
            })
            .bind(format!("identicon:{account_id}"))
            .bind(format!("search_{marker}_{index}"))
            .execute(pool)
            .await
            .expect("search test profile should be inserted");
            user_ids.push(account_id);
        }
        let viewer_id = user_ids[0];
        let friend_id = user_ids[1];
        let outsider_id = user_ids[2];
        sqlx::query("INSERT INTO friend_relations (user_id, friend_user_id) VALUES ($1, $2)")
            .bind(viewer_id)
            .bind(friend_id)
            .execute(pool)
            .await
            .expect("search friendship should be inserted");

        let joined_group_id = sqlx::query_scalar::<_, sqlx::types::Uuid>(
            "INSERT INTO conversations (type, name, owner_id) VALUES (1, $1, $2) RETURNING id",
        )
        .bind(format!("joined-{keyword}"))
        .bind(viewer_id)
        .fetch_one(pool)
        .await
        .expect("joined search group should be inserted");
        let hidden_group_id = sqlx::query_scalar::<_, sqlx::types::Uuid>(
            "INSERT INTO conversations (type, name, owner_id) VALUES (1, $1, $2) RETURNING id",
        )
        .bind(format!("hidden-{keyword}"))
        .bind(outsider_id)
        .fetch_one(pool)
        .await
        .expect("hidden search group should be inserted");
        sqlx::query(
            r#"
            INSERT INTO conversation_members (conversation_id, user_id, is_deleted)
            VALUES ($1, $2, FALSE), ($1, $3, FALSE), ($4, $5, FALSE)
            "#,
        )
        .bind(joined_group_id)
        .bind(viewer_id)
        .bind(friend_id)
        .bind(hidden_group_id)
        .bind(outsider_id)
        .execute(pool)
        .await
        .expect("search memberships should be inserted");
        sqlx::query(
            r#"
            INSERT INTO messages (conversation_id, sender_id, seq, type, content)
            VALUES
                ($1, $2, 1, 0, $3),
                ($1, $2, 2, 5, $3),
                ($4, $5, 1, 0, $3)
            "#,
        )
        .bind(joined_group_id)
        .bind(friend_id)
        .bind(format!("message-{keyword}"))
        .bind(hidden_group_id)
        .bind(outsider_id)
        .execute(pool)
        .await
        .expect("search messages should be inserted");

        let token = sign_token(context.as_ref(), viewer_id).expect("search token should sign");
        let app = build_app(context.clone(), Arc::new(InMemoryStore::new()));
        let get = |uri: String| {
            Request::builder()
                .method("GET")
                .uri(uri)
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .body(Body::empty())
                .unwrap()
        };

        let friend_response = app
            .clone()
            .oneshot(get(format!("/api/friends/search?q={keyword}")))
            .await
            .unwrap();
        assert_eq!(friend_response.status(), StatusCode::OK);
        let friend_body = to_bytes(friend_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let friends: serde_json::Value = serde_json::from_slice(&friend_body).unwrap();
        assert_eq!(friends.as_array().unwrap().len(), 1);
        assert_eq!(friends[0]["account_id"], friend_id);

        let group_response = app
            .clone()
            .oneshot(get(format!(
                "/api/conversations/search-joined-groups?q={keyword}"
            )))
            .await
            .unwrap();
        assert_eq!(group_response.status(), StatusCode::OK);
        let group_body = to_bytes(group_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let groups: serde_json::Value = serde_json::from_slice(&group_body).unwrap();
        assert_eq!(groups.as_array().unwrap().len(), 1);
        assert_eq!(groups[0]["id"], joined_group_id.to_string());

        let global_response = app
            .clone()
            .oneshot(get(format!("/api/messages/search?q={keyword}")))
            .await
            .unwrap();
        assert_eq!(global_response.status(), StatusCode::OK);
        let global_body = to_bytes(global_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let global: serde_json::Value = serde_json::from_slice(&global_body).unwrap();
        assert_eq!(global.as_array().unwrap().len(), 1);
        assert_eq!(global[0]["conversation"]["id"], joined_group_id.to_string());
        assert_eq!(global[0]["match_count"], 1);
        assert_eq!(global[0]["messages"].as_array().unwrap().len(), 1);

        let conversation_response = app
            .clone()
            .oneshot(get(format!(
                "/conversations/{joined_group_id}/messages/search?q={keyword}"
            )))
            .await
            .unwrap();
        assert_eq!(conversation_response.status(), StatusCode::OK);
        let conversation_body = to_bytes(conversation_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let messages: serde_json::Value = serde_json::from_slice(&conversation_body).unwrap();
        assert_eq!(messages.as_array().unwrap().len(), 1);
        assert_eq!(messages[0]["msg_type"], 0);

        let hidden_response = app
            .clone()
            .oneshot(get(format!(
                "/conversations/{hidden_group_id}/messages/search?q={keyword}"
            )))
            .await
            .unwrap();
        assert_eq!(hidden_response.status(), StatusCode::NOT_FOUND);
        let invalid_response = app
            .clone()
            .oneshot(get("/api/messages/search?q=%20".to_string()))
            .await
            .unwrap();
        assert_eq!(invalid_response.status(), StatusCode::BAD_REQUEST);

        sqlx::query("DELETE FROM conversations WHERE id = ANY($1)")
            .bind(&[joined_group_id, hidden_group_id])
            .execute(pool)
            .await
            .expect("search conversations should be cleaned up");
        sqlx::query("DELETE FROM accounts WHERE id = ANY($1)")
            .bind(&user_ids)
            .execute(pool)
            .await
            .expect("search accounts should be cleaned up");
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
    async fn friend_routes_require_authentication() {
        let (_, _, app) = build_test_app();

        let requests = [
            Request::builder()
                .method("GET")
                .uri("/api/friends")
                .body(Body::empty())
                .unwrap(),
            Request::builder()
                .method("POST")
                .uri("/api/friends/requests")
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(r#"{"to_user_id":10002}"#))
                .unwrap(),
            Request::builder()
                .method("GET")
                .uri("/api/users/search?q=13800138000")
                .body(Body::empty())
                .unwrap(),
            Request::builder()
                .method("GET")
                .uri("/api/friends/search?q=test")
                .body(Body::empty())
                .unwrap(),
            Request::builder()
                .method("GET")
                .uri("/api/conversations/search-joined-groups?q=test")
                .body(Body::empty())
                .unwrap(),
            Request::builder()
                .method("GET")
                .uri("/api/messages/search?q=test")
                .body(Body::empty())
                .unwrap(),
            Request::builder()
                .method("GET")
                .uri("/conversations/00000000-0000-0000-0000-000000000001/messages/search?q=test")
                .body(Body::empty())
                .unwrap(),
        ];

        for request in requests {
            let response = app.clone().oneshot(request).await.unwrap();
            assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
        }
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

    #[test]
    fn friend_frame_types_round_trip() {
        let event = FriendRequestEvent {
            request_id: "00000000-0000-0000-0000-000000000001".to_string(),
            from_user: Some(FriendUser {
                account_id: 10001,
                nickname: "小雨".to_string(),
                avatar: "identicon:10001".to_string(),
                signature: String::new(),
                flash_id: "flash_10001".to_string(),
            }),
            message: "我是小雨".to_string(),
            created_at: "2026-07-20T09:00:00Z".to_string(),
        };
        let request_frame = frame::friend_request_frame(event);
        let (frame_type, payload) = frame::decode_frame(&request_frame).unwrap();

        assert_eq!(frame_type, WsFrameType::FriendRequest);
        assert!(!payload.is_empty());
    }

    #[test]
    fn group_join_request_frame_round_trip() {
        let event = GroupJoinRequestNotification {
            request_id: "00000000-0000-0000-0000-000000000001".to_string(),
            conversation_id: "00000000-0000-0000-0000-000000000002".to_string(),
            group_name: "测试群".to_string(),
            group_avatar: "grid:identicon:10001".to_string(),
            applicant_id: 10002,
            applicant_name: "小雨".to_string(),
            applicant_avatar: "identicon:10002".to_string(),
            message: "请求加入群聊".to_string(),
            status: 0,
            created_at: "2026-08-31T08:00:00Z".to_string(),
            handled_at: String::new(),
        };
        let request_frame = frame::group_join_request_frame(event);
        let (frame_type, payload) = frame::decode_frame(&request_frame).unwrap();

        assert_eq!(frame_type, WsFrameType::GroupJoinRequest);
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
