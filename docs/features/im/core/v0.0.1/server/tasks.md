# im-core v0.0.1 — 服务端任务清单

基于 [design.md](./design.md) 设计，拆分 `server/` 侧 IM Core 接入步骤。目标是在 `server/modules/im-ws` 中实现 Protobuf WebSocket 认证、PING/PONG 心跳响应和帧分发骨架，并在宿主服务注册 `GET /ws/im`。

全局约束：
- 本清单只覆盖服务端 IM Core 最小连接能力：AUTH 帧认证、PING/PONG、dispatcher 骨架、`/ws/im` 路由接入。
- 不实现在线用户表 `WsState`，不做定向推送、消息转发、离线同步、上下线广播。
- 不从数据库查询用户资料；认证只从 JWT 中提取 `account_id`。
- 继续保留现有 `/ws` 与 `/chat_room/ws` 原型路由，本版本不删除旧聊天代码，避免破坏当前测试和 playground。
- `im-ws` 复用 `flash_core::jwt::extract_user_id` / `SharedContext`，不重复实现 JWT 校验。
- 当前仓库没有设计中提到的 `AppState db/chat_tx` 和 `server/src/ws/` 目录；实际接入点是 `server/src/routes/mod.rs` 和 `server/src/lib.rs` 测试。
- `im-ws` package 名是 `im-ws`，Rust import 名是 `im_ws`。

---

## 执行顺序

1. ✅ 任务 1 — `server/modules/im-ws/Cargo.toml` 扩展业务依赖（无依赖）
   - ✅ 1.1 添加 `axum` ws 依赖
   - ✅ 1.2 添加 `tokio` / `futures-util` / `uuid`
   - ✅ 1.3 添加 `flash_core` path 依赖
2. ✅ 任务 2 — `server/modules/im-ws/src/frame.rs` 新增帧编解码辅助（依赖任务 1）
   - ✅ 2.1 定义 `FrameDecodeError`
   - ✅ 2.2 实现 `encode_frame`
   - ✅ 2.3 实现 `decode_frame`
   - ✅ 2.4 实现 `auth_result_frame` / `pong_frame`
3. ✅ 任务 3 — `server/modules/im-ws/src/dispatcher.rs` 新增帧分发器（依赖任务 2）
   - ✅ 3.1 定义 `DispatchOutcome`
   - ✅ 3.2 处理 `PING -> PONG`
   - ✅ 3.3 对暂未实现帧返回忽略或关闭策略
4. ✅ 任务 4 — `server/modules/im-ws/src/handler.rs` 实现 `/ws/im` 连接生命周期（依赖任务 2、3）
   - ✅ 4.1 定义 10 秒认证超时常量
   - ✅ 4.2 实现 AUTH 帧读取与 token 解析
   - ✅ 4.3 认证成功后回复 `AUTH_RESULT(success=true)`
   - ✅ 4.4 认证失败或超时回复失败结果并关闭
   - ✅ 4.5 认证后消息循环调用 dispatcher
5. ✅ 任务 5 — `server/modules/im-ws/src/lib.rs` 暴露业务模块与 `router()`（依赖任务 4）
   - ✅ 5.1 导出 `dispatcher` / `frame` / `handler` / `proto`
   - ✅ 5.2 暴露 `pub fn router() -> Router<SharedContext>`
   - ✅ 5.3 注册 `GET /ws/im`
6. ✅ 任务 6 — `server/Cargo.toml` 接入 `im-ws` 宿主依赖（依赖任务 5）
   - ✅ 6.1 在 `[dependencies]` 新增 `im-ws = { path = "modules/im-ws" }`
   - ✅ 6.2 保持 workspace member 不变
7. ✅ 任务 7 — `server/src/routes/mod.rs` 合并 `im_ws::router()`（依赖任务 6）
   - ✅ 7.1 引入 `im_ws::router as build_im_ws_router`
   - ✅ 7.2 在 `build_router` 中 merge 新 router
   - ✅ 7.3 保留旧 `/ws` 与 `/chat_room/ws`
8. ✅ 任务 8 — `server/src/lib.rs` 新增 `/ws/im` 集成测试（依赖任务 7）
   - ✅ 8.1 无 AUTH 帧超时或无效 token 返回失败结果
   - ✅ 8.2 有效 AUTH 帧返回成功结果
   - ✅ 8.3 认证后 PING 返回 PONG
9. ✅ 最后 — 格式化、编译、静态检查与测试验证（依赖任务 1-8）
   - ✅ 9.1 `cd server && cargo fmt --check`
   - ✅ 9.2 `cd server && cargo build -p im-ws`
   - ✅ 9.3 `cd server && cargo test -p im-ws`
   - ✅ 9.4 `cd server && cargo test`

---

## 任务 1：`server/modules/im-ws/Cargo.toml` — 扩展业务依赖 `✅ 已完成`

文件：`server/modules/im-ws/Cargo.toml`

改动类型：`配置修改`

### 1.1 添加 axum ws 依赖 `✅`

关键配置骨架：

```toml
[dependencies]
axum = { version = "0.8.9", features = ["ws"] }
prost = "0.14"
```

### 1.2 添加异步与连接 ID 依赖 `✅`

关键配置骨架：

```toml
futures-util = "0.3.31"
tokio = { version = "1.52.3", features = ["time"] }
uuid = { version = "1", features = ["v4"] }
```

说明：
- `tokio::time::timeout` 用于 10 秒认证窗口。
- `uuid` 用于生成连接 ID，当前只用于日志和连接生命周期追踪，不落在线表。

### 1.3 添加 flash_core path 依赖 `✅`

关键配置骨架：

```toml
flash_core = { path = "../flash_core" }
```

说明：
- 复用 `SharedContext` 与 `jwt::extract_user_id`。

---

## 任务 2：`server/modules/im-ws/src/frame.rs` — 新增帧编解码辅助 `✅ 已完成`

文件：`server/modules/im-ws/src/frame.rs`

改动类型：`新建`

### 2.1 定义帧解码错误 `✅`

关键代码骨架：

```rust
use prost::Message as ProstMessage;

use crate::proto::{AuthResult, WsFrame, WsFrameType};

#[derive(Debug)]
pub enum FrameDecodeError {
    InvalidProtobuf(prost::DecodeError),
    UnknownFrameType(i32),
}
```

### 2.2 实现 encode_frame `✅`

关键函数骨架：

```rust
pub fn encode_frame(frame_type: WsFrameType, payload: Vec<u8>) -> Vec<u8> {
    let frame = WsFrame {
        r#type: frame_type as i32,
        payload,
    };
    frame.encode_to_vec()
}
```

说明：
- prost 生成的 enum 字段通常是 `i32`，使用 `as i32` 写入。

### 2.3 实现 decode_frame `✅`

关键函数骨架：

```rust
pub fn decode_frame(bytes: &[u8]) -> Result<(WsFrameType, Vec<u8>), FrameDecodeError> {
    let frame = WsFrame::decode(bytes).map_err(FrameDecodeError::InvalidProtobuf)?;
    let frame_type = WsFrameType::try_from(frame.r#type)
        .map_err(|_| FrameDecodeError::UnknownFrameType(frame.r#type))?;
    Ok((frame_type, frame.payload))
}
```

### 2.4 实现认证结果和 PONG 帧辅助 `✅`

关键函数骨架：

```rust
pub fn auth_result_frame(success: bool, message: impl Into<String>) -> Vec<u8> {
    let payload = AuthResult {
        success,
        message: message.into(),
    }
    .encode_to_vec();
    encode_frame(WsFrameType::AuthResult, payload)
}

pub fn pong_frame() -> Vec<u8> {
    encode_frame(WsFrameType::Pong, Vec::new())
}
```

说明：
- 具体 enum variant 名以 `prost` 生成结果为准；实现时检查 `server/target/.../out/im.rs` 或 IDE 补全。

---

## 任务 3：`server/modules/im-ws/src/dispatcher.rs` — 新增帧分发器 `✅ 已完成`

文件：`server/modules/im-ws/src/dispatcher.rs`

改动类型：`新建`

### 3.1 定义分发结果 `✅`

关键代码骨架：

```rust
use crate::proto::WsFrameType;

pub enum DispatchOutcome {
    Reply(Vec<u8>),
    Ignore,
}
```

### 3.2 处理 PING `✅`

关键函数骨架：

```rust
pub fn dispatch_frame(frame_type: WsFrameType, payload: Vec<u8>) -> DispatchOutcome {
    match frame_type {
        WsFrameType::Ping => DispatchOutcome::Reply(crate::frame::pong_frame()),
        // ...
    }
}
```

### 3.3 预留未实现分支 `✅`

关键逻辑骨架：

```rust
match frame_type {
    WsFrameType::Auth => DispatchOutcome::Ignore,
    WsFrameType::AuthResult => DispatchOutcome::Ignore,
    _ => DispatchOutcome::Ignore,
}
```

说明：
- 本版本只处理认证后的 PING。消息、同步等未来帧不在本版本实现。

---

## 任务 4：`server/modules/im-ws/src/handler.rs` — 实现 `/ws/im` 连接生命周期 `✅ 已完成`

文件：`server/modules/im-ws/src/handler.rs`

改动类型：`新建`

### 4.1 定义认证超时常量 `✅`

关键代码骨架：

```rust
use std::time::Duration;

const AUTH_TIMEOUT: Duration = Duration::from_secs(10);
```

### 4.2 实现 handler 入口 `✅`

关键函数骨架：

```rust
use axum::{
    extract::{State, ws::{Message, WebSocket, WebSocketUpgrade}},
    response::IntoResponse,
};
use flash_core::{AppResult, SharedContext};

pub async fn ws_handler(
    State(context): State<SharedContext>,
    websocket: WebSocketUpgrade,
) -> AppResult<impl IntoResponse> {
    let connection_id = uuid::Uuid::new_v4();
    Ok(websocket.on_upgrade(move |socket| handle_socket(socket, context, connection_id)))
}
```

### 4.3 读取 AUTH 帧并验证 token `✅`

关键函数骨架：

```rust
async fn authenticate_socket(
    socket: &mut WebSocket,
    context: &SharedContext,
) -> Result<i64, AuthFailure> {
    // 1. timeout(AUTH_TIMEOUT, socket.recv()).await
    // 2. 只接受 Message::Binary
    // 3. decode_frame(bytes)，要求 frame type = Auth
    // 4. AuthRequest::decode(payload)
    // 5. 构造 HeaderMap 或新增 helper，复用 flash_core::jwt::extract_user_id
}
```

说明：
- 如果 `extract_user_id` 只接受 HeaderMap，实现时可把 token 包装成 `Authorization: Bearer <token>` HeaderMap 后调用，避免重复 JWT 逻辑。

### 4.4 回复认证结果并关闭失败连接 `✅`

关键流程骨架：

```rust
async fn handle_socket(mut socket: WebSocket, context: SharedContext, connection_id: Uuid) {
    match authenticate_socket(&mut socket, &context).await {
        Ok(account_id) => {
            let _ = socket.send(Message::Binary(auth_result_frame(true, "ok").into())).await;
            // enter message loop
        }
        Err(error) => {
            let _ = socket
                .send(Message::Binary(auth_result_frame(false, error.message()).into()))
                .await;
            let _ = socket.close().await;
        }
    }
}
```

### 4.5 认证后消息循环调用 dispatcher `✅`

关键逻辑骨架：

```rust
while let Some(result) = socket.recv().await {
    match result {
        Ok(Message::Binary(bytes)) => {
            let (frame_type, payload) = decode_frame(&bytes)?;
            match dispatch_frame(frame_type, payload) {
                DispatchOutcome::Reply(reply) => socket.send(Message::Binary(reply.into())).await?,
                DispatchOutcome::Ignore => {}
            }
        }
        Ok(Message::Close(_)) => break,
        Ok(_) => {}
        Err(_) => break,
    }
}
```

说明：
- 当前不维护在线连接表，`connection_id` / `account_id` 仅用于日志。

---

## 任务 5：`server/modules/im-ws/src/lib.rs` — 暴露业务模块与 router `✅ 已完成`

文件：`server/modules/im-ws/src/lib.rs`

改动类型：`修改`

### 5.1 导出模块 `✅`

关键代码骨架：

```rust
pub mod dispatcher;
pub mod frame;
pub mod handler;
pub mod proto;
```

### 5.2 暴露 router 函数 `✅`

关键代码骨架：

```rust
use axum::{Router, routing::get};
use flash_core::SharedContext;

pub fn router() -> Router<SharedContext> {
    Router::new().route("/ws/im", get(handler::ws_handler))
}
```

### 5.3 保持对外 API 最小 `✅`

说明：
- 本版本对宿主只暴露 `router()` 和 proto 类型模块，不暴露内部生命周期函数。

---

## 任务 6：`server/Cargo.toml` — 接入 `im-ws` 宿主依赖 `✅ 已完成`

文件：`server/Cargo.toml`

改动类型：`配置修改`

### 6.1 新增 path 依赖 `✅`

关键配置骨架：

```toml
[dependencies]
im-ws = { path = "modules/im-ws" }
```

说明：
- Rust import 名仍是 `im_ws`。

### 6.2 保持 workspace member 不变 `✅`

当前 workspace 已包含：

```toml
[workspace]
members = [".", "modules/flash_core", "modules/flash_auth", "modules/flash_user", "modules/im-ws"]
```

---

## 任务 7：`server/src/routes/mod.rs` — 合并 IM WebSocket router `✅ 已完成`

文件：`server/src/routes/mod.rs`

改动类型：`修改`

### 7.1 引入 im_ws router `✅`

关键代码骨架：

```rust
use im_ws::router as build_im_ws_router;
```

### 7.2 merge `/ws/im` router `✅`

关键代码骨架：

```rust
let router = Router::new()
    .route("/v", get(health::version))
    .route("/conversation", get(conversation::conversations))
    .route("/ws", get(ws::websocket_handler))
    .route("/chat_room/ws", get(ws::chat_room_websocket_handler))
    .merge(build_user_router())
    .merge(build_im_ws_router());
```

### 7.3 保留旧原型路由 `✅`

说明：
- 设计提到删除旧 `server/src/ws/`，但当前仓库没有这个目录，且已有测试覆盖 `/chat_room/ws`。本任务不删除 `server/src/routes/ws.rs`。

---

## 任务 8：`server/src/lib.rs` — 新增 `/ws/im` 集成测试 `✅ 已完成`

文件：`server/src/lib.rs`

改动类型：`修改`

### 8.1 增加测试辅助函数 `✅`

关键代码骨架：

```rust
fn encode_ws_frame(frame_type: im_ws::proto::WsFrameType, payload: Vec<u8>) -> Vec<u8> {
    im_ws::proto::WsFrame {
        r#type: frame_type as i32,
        payload,
    }
    .encode_to_vec()
}

fn decode_ws_frame(bytes: &[u8]) -> (im_ws::proto::WsFrameType, Vec<u8>) {
    // WsFrame::decode + WsFrameType::try_from
}
```

说明：
- 测试里需要引入 `prost::Message`。如果宿主 crate 当前没有直接依赖 `prost`，优先通过 `im_ws` 暴露的 frame helper 编解码，避免给宿主额外加依赖。

### 8.2 无效 token 返回认证失败 `✅`

关键测试骨架：

```rust
#[tokio::test]
async fn im_websocket_rejects_invalid_auth_frame() {
    let (_, _, app) = build_test_app();
    let address = spawn_test_server(app).await;
    let (mut ws, _) = connect_async(format!("ws://{address}/ws/im")).await.unwrap();

    // send AUTH frame with invalid token
    // expect AUTH_RESULT success=false
}
```

### 8.3 有效 AUTH 帧返回认证成功 `✅`

关键测试骨架：

```rust
#[tokio::test]
async fn im_websocket_accepts_valid_auth_frame() {
    let (context, auth_store, app) = build_test_app();
    let account = find_or_create_account_by_phone(context.as_ref(), auth_store.as_ref(), "13800138000").await.unwrap();
    let token = sign_token(account.account_id, context.jwt_secret.as_ref(), context.jwt_ttl).unwrap();

    // connect /ws/im
    // send AUTH frame with token
    // expect AUTH_RESULT success=true
}
```

### 8.4 认证后 PING 返回 PONG `✅`

关键测试骨架：

```rust
// after successful auth:
ws.send(TungsteniteMessage::Binary(encode_ws_frame(WsFrameType::Ping, Vec::new()).into())).await.unwrap();
let reply = ws.next().await.unwrap().unwrap();
// decode reply and assert WsFrameType::Pong
```

---

## 任务 9：格式化、编译、静态检查与测试验证 `✅ 已完成`

文件：无单一目标文件，验证 `server/` 与 `im-ws` 整体可用。

改动类型：`验证`

### 9.1 格式检查 `✅`

执行：

```bash
cd server && cargo fmt --check
```

### 9.2 im-ws 编译验证 `✅`

执行：

```bash
cd server && cargo build -p im-ws
```

### 9.3 im-ws 测试验证 `✅`

执行：

```bash
cd server && cargo test -p im-ws
```

### 9.4 宿主集成测试验证 `✅`

执行：

```bash
cd server && cargo test
```

说明：
- `cargo test` 需要覆盖现有 auth/session/chat_room 测试以及新增 `/ws/im` 测试。
