use axum::{
    Json, Router,
    extract::{
        Query, State,
        ws::{Message, WebSocket, WebSocketUpgrade},
    },
    http::{HeaderMap, StatusCode, header},
    response::IntoResponse,
    routing::{get, post},
};
use futures_util::{SinkExt, StreamExt};
use jsonwebtoken::{DecodingKey, EncodingKey, Header, Validation, decode, encode};
use local_ip_address::local_ip;
use rand::Rng;
use serde::{Deserialize, Serialize};
use std::{
    collections::HashMap,
    net::SocketAddr,
    sync::{
        Arc,
        atomic::{AtomicU64, AtomicUsize, Ordering},
    },
    time::{Duration, SystemTime, UNIX_EPOCH},
};
use tokio::{
    net::TcpListener,
    sync::{RwLock, mpsc},
};

const HOST: &str = "0.0.0.0";
const PORT: u16 = 9600;
const JWT_TTL: Duration = Duration::from_secs(24 * 60 * 60);

static NEXT_CONNECTION_ID: AtomicUsize = AtomicUsize::new(1);

type SharedState = Arc<AppState>;

#[derive(Clone)]
struct AppState {
    sms_codes: Arc<RwLock<HashMap<String, String>>>,
    users_by_id: Arc<RwLock<HashMap<u64, UserRecord>>>,
    user_ids_by_phone: Arc<RwLock<HashMap<String, u64>>>,
    chat_connections: Arc<RwLock<HashMap<usize, ChatRoomConnection>>>,
    next_user_id: Arc<AtomicU64>,
    next_chat_message_id: Arc<AtomicU64>,
    jwt_secret: Arc<String>,
}

#[derive(Clone, Serialize, Deserialize)]
struct UserRecord {
    user_id: u64,
    nickname: String,
    avatar: String,
    phone: String,
}

#[derive(Clone)]
struct ChatRoomConnection {
    sender: mpsc::UnboundedSender<String>,
}

#[derive(Serialize)]
struct VersionResponse {
    name: &'static str,
    version: &'static str,
}

#[derive(Serialize)]
struct ConversationResponse {
    title: &'static str,
    #[serde(rename = "lastMsg")]
    last_msg: &'static str,
    time: &'static str,
}

#[derive(Deserialize)]
struct SmsRequest {
    phone: String,
}

#[derive(Serialize, Deserialize)]
struct SmsResponse {
    phone: String,
    code: String,
}

#[derive(Deserialize)]
struct LoginRequest {
    phone: String,
    code: String,
}

#[derive(Serialize, Deserialize)]
struct LoginResponse {
    token: String,
    user_id: u64,
}

#[derive(Serialize, Deserialize)]
struct ProfileResponse {
    user_id: u64,
    nickname: String,
    avatar: String,
    phone: String,
}

#[derive(Serialize)]
struct ErrorResponse {
    message: &'static str,
}

#[derive(Clone, Serialize, Deserialize)]
struct AuthClaims {
    user_id: u64,
    exp: usize,
}

#[derive(Deserialize)]
struct ChatRoomWsQuery {
    token: Option<String>,
}

#[derive(Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum ChatRoomClientEvent {
    Ping,
    Chat { text: String },
}

#[derive(Serialize, Clone)]
#[serde(tag = "type", rename_all = "snake_case")]
enum ChatRoomServerEvent {
    AuthReady {
        user_id: u64,
        nickname: String,
        avatar: String,
    },
    Chat {
        message_id: u64,
        user_id: u64,
        nickname: String,
        avatar: String,
        text: String,
        sent_at: u64,
    },
    Pong {
        sent_at: u64,
    },
    Error {
        message: String,
    },
}

impl AppState {
    fn new(jwt_secret: impl Into<String>) -> Self {
        Self {
            sms_codes: Arc::new(RwLock::new(HashMap::new())),
            users_by_id: Arc::new(RwLock::new(HashMap::new())),
            user_ids_by_phone: Arc::new(RwLock::new(HashMap::new())),
            chat_connections: Arc::new(RwLock::new(HashMap::new())),
            next_user_id: Arc::new(AtomicU64::new(1)),
            next_chat_message_id: Arc::new(AtomicU64::new(1)),
            jwt_secret: Arc::new(jwt_secret.into()),
        }
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let state = Arc::new(AppState::new("flash-im-playground-secret"));
    let app = app(state);
    let addr: SocketAddr = format!("{HOST}:{PORT}").parse()?;
    let listener = TcpListener::bind(addr).await?;

    print_access_urls(PORT);

    axum::serve(listener, app).await?;
    Ok(())
}

fn app(state: SharedState) -> Router {
    Router::new()
        .route("/v", get(version))
        .route("/conversation", get(conversations))
        .route("/ws", get(websocket_handler))
        .route("/chat_room/ws", get(chat_room_websocket_handler))
        .route("/auth/sms", post(send_sms_code))
        .route("/auth/login", post(login))
        .route("/user/profile", get(user_profile))
        .with_state(state)
}

async fn version() -> impl IntoResponse {
    utf8_json(Json(VersionResponse {
        name: env!("CARGO_PKG_NAME"),
        version: env!("CARGO_PKG_VERSION"),
    }))
}

async fn conversations() -> impl IntoResponse {
    utf8_json(Json(vec![
        ConversationResponse {
            title: "产品讨论群",
            last_msg: "今晚先把登录流程对齐一下。",
            time: "09:12",
        },
        ConversationResponse {
            title: "Rust 后端小组",
            last_msg: "Axum 的路由已经跑通了。",
            time: "09:25",
        },
        ConversationResponse {
            title: "Flutter 客户端",
            last_msg: "会话列表页面我来接接口。",
            time: "09:41",
        },
        ConversationResponse {
            title: "设计评审",
            last_msg: "头像和气泡样式需要再收敛一点。",
            time: "10:03",
        },
        ConversationResponse {
            title: "测试反馈",
            last_msg: "弱网重连的用例已经补上。",
            time: "10:18",
        },
        ConversationResponse {
            title: "运维通知",
            last_msg: "今晚 23 点有一次数据库备份演练。",
            time: "10:36",
        },
        ConversationResponse {
            title: "AI 助手",
            last_msg: "已生成今日待办摘要。",
            time: "10:52",
        },
        ConversationResponse {
            title: "张雨",
            last_msg: "接口返回字段我看到了，没问题。",
            time: "11:06",
        },
        ConversationResponse {
            title: "李明",
            last_msg: "下午三点同步一下进度。",
            time: "11:20",
        },
        ConversationResponse {
            title: "王晓",
            last_msg: "我把截图发到群里了。",
            time: "11:45",
        },
        ConversationResponse {
            title: "项目周会",
            last_msg: "本周重点是消息链路和会话列表。",
            time: "12:10",
        },
        ConversationResponse {
            title: "后端告警",
            last_msg: "本地服务已恢复正常。",
            time: "12:28",
        },
        ConversationResponse {
            title: "接口联调",
            last_msg: "先用假数据把 UI 跑起来。",
            time: "13:02",
        },
        ConversationResponse {
            title: "素材同步",
            last_msg: "默认头像资源已经上传。",
            time: "13:17",
        },
        ConversationResponse {
            title: "安全审核",
            last_msg: "后续登录态要加过期校验。",
            time: "13:40",
        },
        ConversationResponse {
            title: "群聊 Demo",
            last_msg: "20 条模拟会话足够先展示。",
            time: "14:05",
        },
        ConversationResponse {
            title: "小程序适配",
            last_msg: "先不处理，等核心链路稳定。",
            time: "14:22",
        },
        ConversationResponse {
            title: "数据建模",
            last_msg: "conversation 表需要单独设计。",
            time: "14:48",
        },
        ConversationResponse {
            title: "发布准备",
            last_msg: "提交前跑一下 clippy。",
            time: "15:11",
        },
        ConversationResponse {
            title: "系统消息",
            last_msg: "欢迎使用 flash_im。",
            time: "15:30",
        },
    ]))
}

async fn send_sms_code(
    State(state): State<SharedState>,
    Json(request): Json<SmsRequest>,
) -> impl IntoResponse {
    let phone = request.phone.trim().to_string();
    if phone.is_empty() {
        return json_error(StatusCode::BAD_REQUEST, "phone is required");
    }

    let code = random_sms_code();
    state
        .sms_codes
        .write()
        .await
        .insert(phone.clone(), code.clone());

    utf8_json(Json(SmsResponse { phone, code })).into_response()
}

async fn login(
    State(state): State<SharedState>,
    Json(request): Json<LoginRequest>,
) -> impl IntoResponse {
    let phone = request.phone.trim().to_string();
    let code = request.code.trim().to_string();

    if phone.is_empty() || code.is_empty() {
        return json_error(StatusCode::BAD_REQUEST, "phone and code are required");
    }

    let stored_code = state.sms_codes.read().await.get(&phone).cloned();
    if stored_code.as_deref() != Some(code.as_str()) {
        return json_error(StatusCode::UNAUTHORIZED, "invalid or expired code");
    }

    state.sms_codes.write().await.remove(&phone);

    let user = find_or_create_user(state.as_ref(), &phone).await;
    match sign_token(state.as_ref(), user.user_id) {
        Ok(token) => utf8_json(Json(LoginResponse {
            token,
            user_id: user.user_id,
        }))
        .into_response(),
        Err(error) => {
            println!("jwt sign failed: user_id={}, error={error}", user.user_id);
            json_error(StatusCode::INTERNAL_SERVER_ERROR, "failed to sign token")
        }
    }
}

async fn user_profile(State(state): State<SharedState>, headers: HeaderMap) -> impl IntoResponse {
    let token = match extract_token(&headers) {
        Some(token) => token,
        None => return json_error(StatusCode::UNAUTHORIZED, "missing token"),
    };

    let claims = match decode_token(state.as_ref(), token) {
        Ok(claims) => claims,
        Err(_) => return json_error(StatusCode::UNAUTHORIZED, "invalid token"),
    };

    let user = match state.users_by_id.read().await.get(&claims.user_id).cloned() {
        Some(user) => user,
        None => return json_error(StatusCode::UNAUTHORIZED, "invalid token"),
    };

    utf8_json(Json(ProfileResponse {
        user_id: user.user_id,
        nickname: user.nickname,
        avatar: user.avatar,
        phone: user.phone,
    }))
    .into_response()
}

async fn websocket_handler(websocket: WebSocketUpgrade) -> impl IntoResponse {
    let connection_id = NEXT_CONNECTION_ID.fetch_add(1, Ordering::Relaxed);

    websocket.on_upgrade(move |socket| handle_websocket(socket, connection_id))
}

async fn handle_websocket(mut socket: WebSocket, connection_id: usize) {
    println!("ws connected: connection_id={connection_id}");

    if let Err(error) = socket
        .send(Message::Text("welcome to flash_im websocket".into()))
        .await
    {
        println!("ws send failed on connect: connection_id={connection_id}, error={error}");
        return;
    }

    while let Some(result) = socket.next().await {
        match result {
            Ok(Message::Text(text)) => {
                let reply = format!("echo: {text}");
                if let Err(error) = socket.send(Message::Text(reply.into())).await {
                    println!("ws send failed: connection_id={connection_id}, error={error}");
                    break;
                }
            }
            Ok(Message::Close(_)) => break,
            Ok(_) => {}
            Err(error) => {
                println!("ws receive failed: connection_id={connection_id}, error={error}");
                break;
            }
        }
    }

    println!("ws disconnected: connection_id={connection_id}");
}

async fn chat_room_websocket_handler(
    State(state): State<SharedState>,
    Query(query): Query<ChatRoomWsQuery>,
    websocket: WebSocketUpgrade,
) -> impl IntoResponse {
    let token = match query.token {
        Some(token) if !token.trim().is_empty() => token,
        _ => return json_error(StatusCode::UNAUTHORIZED, "missing token"),
    };

    let claims = match decode_token(state.as_ref(), &token) {
        Ok(claims) => claims,
        Err(_) => return json_error(StatusCode::UNAUTHORIZED, "invalid token"),
    };

    let user = match state.users_by_id.read().await.get(&claims.user_id).cloned() {
        Some(user) => user,
        None => return json_error(StatusCode::UNAUTHORIZED, "invalid token"),
    };

    let connection_id = NEXT_CONNECTION_ID.fetch_add(1, Ordering::Relaxed);
    websocket.on_upgrade(move |socket| handle_chat_room_socket(socket, connection_id, state, user))
}

async fn handle_chat_room_socket(
    socket: WebSocket,
    connection_id: usize,
    state: SharedState,
    user: UserRecord,
) {
    println!(
        "chat_room ws connected: connection_id={connection_id}, user_id={}",
        user.user_id
    );

    let (mut ws_sender, mut ws_receiver) = socket.split();
    let (outgoing_tx, mut outgoing_rx) = mpsc::unbounded_channel::<String>();

    state.chat_connections.write().await.insert(
        connection_id,
        ChatRoomConnection {
            sender: outgoing_tx.clone(),
        },
    );

    let write_task = tokio::spawn(async move {
        while let Some(payload) = outgoing_rx.recv().await {
            if ws_sender.send(Message::Text(payload.into())).await.is_err() {
                break;
            }
        }
    });

    send_to_connection(
        &outgoing_tx,
        ChatRoomServerEvent::AuthReady {
            user_id: user.user_id,
            nickname: user.nickname.clone(),
            avatar: user.avatar.clone(),
        },
    );

    while let Some(result) = ws_receiver.next().await {
        match result {
            Ok(Message::Text(text)) => match serde_json::from_str::<ChatRoomClientEvent>(&text) {
                Ok(ChatRoomClientEvent::Ping) => {
                    send_to_connection(
                        &outgoing_tx,
                        ChatRoomServerEvent::Pong {
                            sent_at: unix_timestamp(),
                        },
                    );
                }
                Ok(ChatRoomClientEvent::Chat { text }) => {
                    let content = text.trim().to_string();
                    if content.is_empty() {
                        send_to_connection(
                            &outgoing_tx,
                            ChatRoomServerEvent::Error {
                                message: "chat message is empty".to_string(),
                            },
                        );
                        continue;
                    }

                    broadcast_chat_room_message(state.as_ref(), &user, content).await;
                }
                Err(_) => {
                    send_to_connection(
                        &outgoing_tx,
                        ChatRoomServerEvent::Error {
                            message: "unsupported message payload".to_string(),
                        },
                    );
                }
            },
            Ok(Message::Close(_)) => break,
            Ok(_) => {}
            Err(error) => {
                println!(
                    "chat_room ws receive failed: connection_id={connection_id}, user_id={}, error={error}",
                    user.user_id
                );
                break;
            }
        }
    }

    state.chat_connections.write().await.remove(&connection_id);

    write_task.abort();

    println!(
        "chat_room ws disconnected: connection_id={connection_id}, user_id={}",
        user.user_id
    );
}

async fn broadcast_chat_room_message(state: &AppState, user: &UserRecord, text: String) {
    let message_id = state.next_chat_message_id.fetch_add(1, Ordering::Relaxed);
    let payload = serialize_chat_room_event(ChatRoomServerEvent::Chat {
        message_id,
        user_id: user.user_id,
        nickname: user.nickname.clone(),
        avatar: user.avatar.clone(),
        text,
        sent_at: unix_timestamp(),
    });

    broadcast_chat_payload(state, payload, None).await;
}

async fn broadcast_chat_payload(state: &AppState, payload: String, exclude: Option<usize>) {
    let connections: Vec<(usize, ChatRoomConnection)> = state
        .chat_connections
        .read()
        .await
        .iter()
        .map(|(connection_id, connection)| (*connection_id, connection.clone()))
        .collect();

    let mut stale_connections = Vec::new();
    for (connection_id, connection) in connections {
        if exclude == Some(connection_id) {
            continue;
        }

        if connection.sender.send(payload.clone()).is_err() {
            stale_connections.push(connection_id);
        }
    }

    if !stale_connections.is_empty() {
        let mut guard = state.chat_connections.write().await;
        for connection_id in stale_connections {
            guard.remove(&connection_id);
        }
    }
}

fn send_to_connection(sender: &mpsc::UnboundedSender<String>, event: ChatRoomServerEvent) {
    let _ = sender.send(serialize_chat_room_event(event));
}

fn serialize_chat_room_event(event: ChatRoomServerEvent) -> String {
    serde_json::to_string(&event).expect("chat_room event should serialize")
}

fn utf8_json<T>(json: Json<T>) -> impl IntoResponse
where
    Json<T>: IntoResponse,
{
    (
        [(header::CONTENT_TYPE, "application/json; charset=utf-8")],
        json,
    )
}

fn json_error(status: StatusCode, message: &'static str) -> axum::response::Response {
    (status, utf8_json(Json(ErrorResponse { message }))).into_response()
}

fn random_sms_code() -> String {
    let mut rng = rand::rng();
    format!("{:06}", rng.random_range(0..1_000_000))
}

fn random_avatar_url() -> String {
    let mut rng = rand::rng();
    let seed = rng.random::<u64>();
    format!("https://picsum.photos/seed/{seed}/120/120")
}

async fn find_or_create_user(state: &AppState, phone: &str) -> UserRecord {
    {
        let existing_user_id = state.user_ids_by_phone.read().await.get(phone).copied();
        if let Some(user_id) = existing_user_id
            && let Some(user) = state.users_by_id.read().await.get(&user_id).cloned()
        {
            return user;
        }
    }

    let mut user_ids_by_phone = state.user_ids_by_phone.write().await;
    if let Some(user_id) = user_ids_by_phone.get(phone).copied()
        && let Some(user) = state.users_by_id.read().await.get(&user_id).cloned()
    {
        return user;
    }

    let user_id = state.next_user_id.fetch_add(1, Ordering::Relaxed);
    let user = UserRecord {
        user_id,
        nickname: phone.to_string(),
        avatar: random_avatar_url(),
        phone: phone.to_string(),
    };

    user_ids_by_phone.insert(phone.to_string(), user_id);
    state
        .users_by_id
        .write()
        .await
        .insert(user_id, user.clone());

    user
}

fn sign_token(state: &AppState, user_id: u64) -> Result<String, jsonwebtoken::errors::Error> {
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

fn decode_token(state: &AppState, token: &str) -> Result<AuthClaims, jsonwebtoken::errors::Error> {
    decode::<AuthClaims>(
        token,
        &DecodingKey::from_secret(state.jwt_secret.as_bytes()),
        &Validation::default(),
    )
    .map(|data| data.claims)
}

fn unix_timestamp() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

fn extract_token(headers: &HeaderMap) -> Option<&str> {
    headers
        .get(header::AUTHORIZATION)
        .and_then(|value| value.to_str().ok())
        .and_then(|value| value.strip_prefix("Bearer ").or(Some(value)))
        .or_else(|| headers.get("token").and_then(|value| value.to_str().ok()))
}

fn print_access_urls(port: u16) {
    println!("server started");
    println!("local:   http://127.0.0.1:{port}/v");

    match local_ip() {
        Ok(ip) => println!("network: http://{ip}:{port}/v"),
        Err(error) => println!("network: unable to detect local ip: {error}"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::{
        body::{Body, to_bytes},
        http::{Request, StatusCode},
    };
    use tokio_tungstenite::{connect_async, tungstenite::Message as TungsteniteMessage};
    use tower::ServiceExt;

    #[tokio::test]
    async fn auth_flow_returns_profile_for_valid_token() {
        let state = Arc::new(AppState::new("test-secret"));
        let app = app(state);

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
        assert_eq!(login.user_id, 1);

        let profile_request = Request::builder()
            .method("GET")
            .uri("/user/profile")
            .header(header::AUTHORIZATION, format!("Bearer {}", login.token))
            .body(Body::empty())
            .unwrap();
        let profile_response = app.oneshot(profile_request).await.unwrap();
        assert_eq!(profile_response.status(), StatusCode::OK);

        let profile_body = to_bytes(profile_response.into_body(), usize::MAX)
            .await
            .unwrap();
        let profile: ProfileResponse = serde_json::from_slice(&profile_body).unwrap();
        assert_eq!(profile.user_id, 1);
        assert_eq!(profile.nickname, "13800138000");
        assert_eq!(profile.phone, "13800138000");
        assert!(profile.avatar.starts_with("https://picsum.photos/seed/"));
        assert!(profile.avatar.ends_with("/120/120"));
    }

    #[tokio::test]
    async fn missing_or_invalid_token_returns_401() {
        let state = Arc::new(AppState::new("test-secret"));
        let app = app(state);

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
    async fn chat_room_websocket_requires_valid_token() {
        let state = Arc::new(AppState::new("test-secret"));
        let app = app(state);
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
        let state = Arc::new(AppState::new("test-secret"));
        let user = find_or_create_user(state.as_ref(), "13800138000").await;
        let token = sign_token(state.as_ref(), user.user_id).unwrap();
        let app = app(state.clone());

        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let address = listener.local_addr().unwrap();
        let server_task = tokio::spawn(async move {
            axum::serve(listener, app).await.unwrap();
        });

        let url = format!("ws://{address}/chat_room/ws?token={token}");
        let (mut stream, _) = connect_async(url).await.unwrap();

        let auth_ready = next_text_message(&mut stream).await;
        assert!(auth_ready.contains("\"type\":\"auth_ready\""));
        assert!(auth_ready.contains("\"user_id\":1"));

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
        assert!(user_chat.contains("\"user_id\":1"));

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
