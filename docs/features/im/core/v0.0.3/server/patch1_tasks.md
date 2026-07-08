# IM Core v0.0.3 Patch 1 — 服务端任务清单

基于 [patch1_design.md](./patch1_design.md) 设计，拆分服务端补丁任务：实时消息补齐发送者资料、会话更新补齐总未读数、会话已读接口、单会话详情接口，以及对应测试脚本更新。

全局约束：
- 本清单只覆盖 `server` 侧补丁；`patch1_design.md` 中列出的客户端文件为后续联调依赖，不纳入本任务执行范围。
- 保持现有 v0.0.3 文本消息链路不变：`CHAT_MESSAGE` 入站、消息持久化、`MESSAGE_ACK`、对方广播、`CONVERSATION_UPDATE`、历史查询继续可用。
- Protobuf 只能追加字段，不能重排或复用已有字段编号，避免破坏已生成客户端。
- `WsBroadcaster` 按当前真实代码在 `server/modules/im-ws/src/handler.rs` 中构造，不按设计草案中的 `server/src/main.rs` 注入。
- HTTP 认证继续复用 `flash_core::jwt::extract_user_id`。
- `GET /conversations/:id` 返回结构必须与 `GET /conversations` 的单条 `ConversationListItem` 保持一致。
- `POST /conversations/:id/read` 只清零当前用户在当前会话的 `unread_count`，不实现已读回执、`last_read_seq` 更新或对端推送。
- 不实现本补丁范围外能力：图片/文件消息、消息撤回、per-user 消息删除、消息搜索、增量同步、客户端 Cubit/Repository 改造。
- 参考现有文件：`server/modules/im-conversation/src/repository.rs` 的列表 SQL、`server/modules/im-conversation/src/routes.rs` 的认证方式、`server/modules/im-ws/src/broadcaster.rs` 的帧编码方式、`docs/features/im/core/v0.0.3/test/ws_chat_test.py` 的端到端验证脚本。

---

## 执行顺序

1. ✅ 任务 1 — `proto/message.proto` 追加实时消息字段（无依赖）
   - ✅ 1.1 `ChatMessage` 追加 `sender_name = 10`
   - ✅ 1.2 `ChatMessage` 追加 `sender_avatar = 11`
   - ✅ 1.3 `ConversationUpdate` 追加 `total_unread = 5`
2. ✅ 任务 2 — `server/modules/im-ws/Cargo.toml` 补充广播器数据库依赖（依赖任务 1）
   - ✅ 2.1 添加 `sqlx` 依赖
3. ✅ 任务 3 — `server/modules/im-conversation/src/repository.rs` 新增单会话、已读和总未读 SQL（无依赖）
   - ✅ 3.1 新增 `get_conversation_by_id_sql`
   - ✅ 3.2 新增 `get_conversation_by_id`
   - ✅ 3.3 新增 `mark_read`
   - ✅ 3.4 新增 `get_total_unread_by_user`
   - ✅ 3.5 补 SQL 骨架测试
4. ✅ 任务 4 — `server/modules/im-conversation/src/service.rs` 暴露补丁服务方法（依赖任务 3）
   - ✅ 4.1 新增 `get_conversation_by_id`
   - ✅ 4.2 新增 `mark_read`
   - ✅ 4.3 在 `ConversationMessageService` 暴露 `get_total_unread_by_user`
5. ✅ 任务 5 — `server/modules/im-conversation/src/routes.rs` 注册补丁 HTTP 路由（依赖任务 4）
   - ✅ 5.1 新增 `GET /conversations/:id`
   - ✅ 5.2 新增 `POST /conversations/:id/read`
   - ✅ 5.3 保持原 `GET /conversations` 不变
6. ✅ 任务 6 — `server/modules/im-ws/src/broadcaster.rs` 补齐实时帧资料（依赖任务 1、2、4）
   - ✅ 6.1 `WsBroadcaster` 新增 `PgPool`
   - ✅ 6.2 广播 `ChatMessage` 前查询发送者资料
   - ✅ 6.3 推送 `ConversationUpdate` 前查询接收者总未读数
   - ✅ 6.4 补编码映射测试
7. ✅ 任务 7 — `server/modules/im-ws/src/handler.rs` 构造带数据库连接的广播器（依赖任务 6）
   - ✅ 7.1 调整 `WsBroadcaster::new` 调用
   - ✅ 7.2 保持在线状态注册和认证流程不变
8. ✅ 任务 8 — `server/src/lib.rs` 补服务端路由和帧字段测试（依赖任务 5、7）
   - ✅ 8.1 验证单会话接口缺 token 返回 401
   - ✅ 8.2 验证已读接口缺 token 返回 401
   - ✅ 8.3 验证新增 Protobuf 帧字段可编码
9. ✅ 任务 9 — `docs/features/im/core/v0.0.3/test/conversation_message.py` 扩展 HTTP 链路验证（依赖任务 5）
   - ✅ 9.1 验证 `GET /conversations/:id`
   - ✅ 9.2 验证 `POST /conversations/:id/read`
   - ✅ 9.3 验证再次拉取单会话时 `unread_count = 0`
10. ✅ 任务 10 — `docs/features/im/core/v0.0.3/test/ws_chat_test.py` 扩展 WS 链路验证（依赖任务 6、7）
    - ✅ 10.1 验证 `CHAT_MESSAGE.sender_name`
    - ✅ 10.2 验证 `CHAT_MESSAGE.sender_avatar`
    - ✅ 10.3 验证 `CONVERSATION_UPDATE.total_unread`
11. ✅ 最后 — 格式化、编译和链路验证（依赖任务 1-10）
    - ✅ 11.1 `cd server && cargo fmt --check`
    - ✅ 11.2 `cd server && cargo build`
    - ✅ 11.3 `cd server && cargo test -p im-conversation`
    - ✅ 11.4 `cd server && cargo test -p im-ws`
    - ✅ 11.5 `cd server && cargo test`
    - ✅ 11.6 `scripts/database/reset_sqlx_database.sh`
    - ✅ 11.7 `scripts/database/seed_im_conversations.sh`
    - ✅ 11.8 启动当前后端
    - ✅ 11.9 `python3 docs/features/im/core/v0.0.3/test/conversation_message.py`
    - ✅ 11.10 `python3 docs/features/im/core/v0.0.3/test/ws_chat_test.py`

---

## 任务 1：`proto/message.proto` — 追加实时消息和会话更新字段 `✅ 已完成`

文件：`proto/message.proto`

改动类型：`修改`

### 1.1 `ChatMessage` 追加发送者昵称 `✅`

关键 Protobuf 骨架：

```proto
message ChatMessage {
  string id = 1;
  string conversation_id = 2;
  int64 sender_id = 3;
  int64 seq = 4;
  int32 type = 5;
  string content = 6;
  string extra = 7;
  int32 status = 8;
  string created_at = 9;
  string sender_name = 10;
  string sender_avatar = 11;
}
```

说明：
- 只能追加字段，不能修改 `1-9` 的含义。
- `sender_name` 和 `sender_avatar` 与历史消息接口中的 `sender_name`、`sender_avatar` 语义一致。

### 1.2 `ConversationUpdate` 追加总未读数 `✅`

关键 Protobuf 骨架：

```proto
message ConversationUpdate {
  string conversation_id = 1;
  string last_message_preview = 2;
  string last_message_at = 3;
  int32 unread_count = 4;
  int32 total_unread = 5;
}
```

说明：
- `unread_count` 仍表示当前会话未读数。
- `total_unread` 表示当前接收者所有未删除会话的未读总数。

---

## 任务 2：`server/modules/im-ws/Cargo.toml` — 补充 SQLx 依赖 `✅ 已完成`

文件：`server/modules/im-ws/Cargo.toml`

改动类型：`配置修改`

### 2.1 添加 `sqlx` 依赖 `✅`

关键 TOML 骨架：

```toml
[dependencies]
sqlx = { version = "0.8.6", features = ["runtime-tokio-rustls", "postgres", "macros"] }
```

说明：
- `WsBroadcaster` 需要查询 `user_profiles` 和总未读数。
- 不引入 `im-message -> im-ws` 反向依赖，保持当前模块边界。

---

## 任务 3：`server/modules/im-conversation/src/repository.rs` — 新增单会话、已读和总未读 SQL `✅ 已完成`

文件：`server/modules/im-conversation/src/repository.rs`

改动类型：`修改`

### 3.1 新增 `get_conversation_by_id_sql` `✅`

关键 Rust/SQL 骨架：

```rust
pub fn get_conversation_by_id_sql() -> &'static str {
    r#"
    SELECT
        c.id,
        c.type,
        c.name,
        peer.account_id AS peer_user_id,
        peer.nickname AS peer_nickname,
        peer.avatar_url AS peer_avatar,
        c.last_message_at,
        c.last_message_preview,
        me.unread_count,
        c.created_at
    FROM conversation_members me
    JOIN conversations c ON c.id = me.conversation_id
    LEFT JOIN conversation_members peer_member
        ON peer_member.conversation_id = c.id
       AND peer_member.user_id <> me.user_id
       AND c.type = 0
    LEFT JOIN user_profiles peer
        ON peer.account_id = peer_member.user_id
    WHERE me.user_id = $1
      AND c.id = $2
      AND me.is_deleted = FALSE
    "#
}
```

说明：
- 字段顺序和别名要与 `ConversationListRow` 保持一致。
- 单聊对方资料逻辑复用列表接口的 `peer_member` 查询方式。

### 3.2 新增单会话查询方法 `✅`

关键函数签名：

```rust
pub async fn get_conversation_by_id(
    pool: &PgPool,
    user_id: i64,
    conversation_id: Uuid,
) -> AppResult<Option<ConversationListRow>>;
```

逻辑骨架：
1. 使用 `get_conversation_by_id_sql()`。
2. `fetch_optional(pool)`。
3. SQL 错误映射为 `failed to get conversation`。

### 3.3 新增已读清零方法 `✅`

关键函数签名与 SQL：

```rust
pub async fn mark_read(
    pool: &PgPool,
    user_id: i64,
    conversation_id: Uuid,
) -> AppResult<bool>;
```

```sql
UPDATE conversation_members
SET unread_count = 0
WHERE conversation_id = $1
  AND user_id = $2
  AND is_deleted = FALSE
```

说明：
- 返回 `rows_affected() > 0`，上层据此决定是否返回 404。
- 不更新 `last_read_seq`。

### 3.4 新增总未读查询方法 `✅`

关键函数签名与 SQL：

```rust
pub async fn get_total_unread_by_user(pool: &PgPool, user_id: i64) -> AppResult<i32>;
```

```sql
SELECT COALESCE(SUM(unread_count), 0)::INT
FROM conversation_members
WHERE user_id = $1
  AND is_deleted = FALSE
```

说明：
- 该方法可供 `ConversationMessageService` 或 `WsBroadcaster` 间接复用。

### 3.5 补 SQL 骨架测试 `✅`

关键测试骨架：

```rust
#[test]
fn get_by_id_sql_matches_list_shape() {
    let sql = get_conversation_by_id_sql();
    assert!(sql.contains("peer.nickname AS peer_nickname"));
    assert!(sql.contains("AND c.id = $2"));
    assert!(sql.contains("AND me.is_deleted = FALSE"));
}
```

---

## 任务 4：`server/modules/im-conversation/src/service.rs` — 暴露补丁服务方法 `✅ 已完成`

文件：`server/modules/im-conversation/src/service.rs`

改动类型：`修改`

### 4.1 新增 `get_conversation_by_id` `✅`

关键函数签名：

```rust
pub async fn get_conversation_by_id(
    context: &SharedContext,
    user_id: i64,
    conversation_id: Uuid,
) -> AppResult<ConversationListItem>;
```

逻辑骨架：
1. 调用 `repository::get_conversation_by_id(...)`。
2. `None` 映射为 `AppError::not_found("conversation not found")`。
3. `ConversationListRow` 转为 `ConversationListItem`。

### 4.2 新增 `mark_read` `✅`

关键函数签名：

```rust
pub async fn mark_read(
    context: &SharedContext,
    user_id: i64,
    conversation_id: Uuid,
) -> AppResult<()>;
```

逻辑骨架：
1. 调用 `repository::mark_read(...)`。
2. `false` 映射为 `AppError::not_found("conversation not found")`。
3. 成功返回空响应。

### 4.3 在 `ConversationMessageService` 暴露总未读查询 `✅`

关键方法签名：

```rust
impl<'a> ConversationMessageService<'a> {
    pub async fn get_total_unread_by_user(&self, user_id: i64) -> AppResult<i32>;
}
```

说明：
- 供 WS 推送 `ConversationUpdate.total_unread` 使用。

---

## 任务 5：`server/modules/im-conversation/src/routes.rs` — 注册补丁 HTTP 路由 `✅ 已完成`

文件：`server/modules/im-conversation/src/routes.rs`

改动类型：`修改`

### 5.1 新增单会话详情 handler `✅`

关键导入与函数签名：

```rust
use axum::extract::{Path, Query, State};
use uuid::Uuid;

pub async fn get_conversation(
    State(context): State<SharedContext>,
    headers: HeaderMap,
    Path(conversation_id): Path<Uuid>,
) -> AppResult<impl IntoResponse>;
```

逻辑骨架：
1. `extract_user_id(context.as_ref(), &headers)`。
2. 调用 `service::get_conversation_by_id(&context, user_id, conversation_id)`。
3. 使用 `utf8_json(Json(conversation))` 返回。

### 5.2 新增已读 handler `✅`

关键函数签名：

```rust
pub async fn mark_conversation_read(
    State(context): State<SharedContext>,
    headers: HeaderMap,
    Path(conversation_id): Path<Uuid>,
) -> AppResult<impl IntoResponse>;
```

响应骨架：

```rust
#[derive(serde::Serialize)]
struct MarkReadResponse {
    message: &'static str,
}
```

说明：
- 成功返回 `{ "message": "conversation marked as read" }`。
- 缺失或非法 token 继续返回 401。

### 5.3 注册路由 `✅`

关键路由骨架：

```rust
pub fn router() -> Router<SharedContext> {
    Router::new()
        .route("/conversations", get(list_conversations))
        .route("/conversations/{id}", get(get_conversation))
        .route("/conversations/{id}/read", post(mark_conversation_read))
}
```

说明：
- 不改变现有列表路由路径。
- 使用 Axum 当前项目已有的 `{id}` 路径写法。

---

## 任务 6：`server/modules/im-ws/src/broadcaster.rs` — 补齐实时帧资料 `✅ 已完成`

文件：`server/modules/im-ws/src/broadcaster.rs`

改动类型：`修改`

### 6.1 `WsBroadcaster` 新增数据库连接 `✅`

关键结构体骨架：

```rust
use sqlx::PgPool;

#[derive(Clone)]
pub struct WsBroadcaster {
    state: WsState,
    pool: PgPool,
}

impl WsBroadcaster {
    pub fn new(state: WsState, pool: PgPool) -> Self {
        Self { state, pool }
    }
}
```

说明：
- `PgPool` 可 clone，构造时从 `context.postgres.pool().clone()` 传入。

### 6.2 查询发送者资料并填充 `ChatMessage` `✅`

关键结构体和函数骨架：

```rust
#[derive(sqlx::FromRow)]
struct SenderProfile {
    nickname: Option<String>,
    avatar_url: Option<String>,
}

async fn load_sender_profile(pool: &PgPool, sender_id: i64) -> AppResult<SenderProfile>;

pub async fn to_proto_message(
    pool: &PgPool,
    message: MessagePayload,
) -> AppResult<ChatMessage>;
```

关键 SQL：

```sql
SELECT nickname, avatar_url
FROM user_profiles
WHERE account_id = $1
```

说明：
- 用户资料不存在时 `sender_name`、`sender_avatar` 使用空字符串。
- `broadcast_message` 需要先 `await to_proto_message(...)`，再编码为 `CHAT_MESSAGE` 帧。

### 6.3 查询总未读并填充 `ConversationUpdate` `✅`

关键函数骨架：

```rust
async fn load_total_unread(pool: &PgPool, user_id: i64) -> AppResult<i32>;

async fn to_proto_update(
    pool: &PgPool,
    update: DomainConversationUpdate,
) -> AppResult<ConversationUpdate>;
```

关键 SQL：

```sql
SELECT COALESCE(SUM(unread_count), 0)::INT
FROM conversation_members
WHERE user_id = $1
  AND is_deleted = FALSE
```

说明：
- `ConversationUpdate.unread_count` 仍来自当前会话。
- `ConversationUpdate.total_unread` 按接收者实时查询。

### 6.4 补编码映射测试 `✅`

关键测试骨架：

```rust
#[test]
fn proto_update_keeps_total_unread_field() {
    let update = ConversationUpdate {
        conversation_id: "...".to_string(),
        last_message_preview: "hello".to_string(),
        last_message_at: "...".to_string(),
        unread_count: 1,
        total_unread: 9,
    };
    assert_eq!(update.total_unread, 9);
}
```

说明：
- 纯字段映射测试即可，不要求单元测试连接数据库。

---

## 任务 7：`server/modules/im-ws/src/handler.rs` — 构造带数据库连接的广播器 `✅ 已完成`

文件：`server/modules/im-ws/src/handler.rs`

改动类型：`修改`

### 7.1 调整 `WsBroadcaster::new` 调用 `✅`

当前代码位置：`handle_authenticated_socket(...)`

关键代码骨架：

```rust
let service = MessageService::new(Arc::new(WsBroadcaster::new(
    ws_state.clone(),
    context.postgres.pool().clone(),
)));
```

说明：
- 不移动 `shared_ws_state()`。
- 不改变 `authenticate_socket` 的首帧认证流程。

### 7.2 保持连接循环行为不变 `✅`

检查点：
- `ws_state.register(account_id, connection_id)` 仍在认证成功后调用。
- `tokio::select!` 仍同时处理客户端输入和服务端输出。
- 断开时仍调用 `ws_state.unregister(account_id, connection_id)`。

---

## 任务 8：`server/src/lib.rs` — 补服务端路由和帧字段测试 `✅ 已完成`

文件：`server/src/lib.rs`

改动类型：`修改`

### 8.1 验证单会话接口缺 token 返回 401 `✅`

关键测试骨架：

```rust
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
```

### 8.2 验证已读接口缺 token 返回 401 `✅`

关键测试骨架：

```rust
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
```

### 8.3 验证新增 Protobuf 字段可编码 `✅`

关键测试骨架：

```rust
let update = ConversationUpdate {
    conversation_id: "...".to_string(),
    last_message_preview: "hello".to_string(),
    last_message_at: "2026-04-03T00:00:00Z".to_string(),
    unread_count: 1,
    total_unread: 3,
};
let update_frame = frame::conversation_update_frame(update);
let (frame_type, payload) = frame::decode_frame(&update_frame).unwrap();
assert_eq!(frame_type, WsFrameType::ConversationUpdate);
assert!(!payload.is_empty());
```

---

## 任务 9：`docs/features/im/core/v0.0.3/test/conversation_message.py` — 扩展 HTTP 链路验证 `✅ 已完成`

文件：`docs/features/im/core/v0.0.3/test/conversation_message.py`

改动类型：`修改`

### 9.1 验证单会话详情 `✅`

关键 Python 骨架：

```python
conversation = request("GET", f"/conversations/{conversation_id}", token=token)
assert conversation["id"] == conversation_id
assert "peer_nickname" in conversation
assert "unread_count" in conversation
```

### 9.2 验证已读接口 `✅`

关键 Python 骨架：

```python
read_result = request("POST", f"/conversations/{conversation_id}/read", token=token)
assert read_result["message"] == "conversation marked as read"
```

### 9.3 验证 unread 清零 `✅`

关键 Python 骨架：

```python
after_read = request("GET", f"/conversations/{conversation_id}", token=token)
assert after_read["unread_count"] == 0
```

说明：
- 继续保留历史消息分页验证。
- 保持脚本只依赖 Python 标准库。

---

## 任务 10：`docs/features/im/core/v0.0.3/test/ws_chat_test.py` — 扩展 WS 链路验证 `✅ 已完成`

文件：`docs/features/im/core/v0.0.3/test/ws_chat_test.py`

改动类型：`修改`

### 10.1 验证 `CHAT_MESSAGE.sender_name` `✅`

当前脚本使用最小 Protobuf 解码，新增字段编号检查：

```python
sender_name = delivered.get(10, b"").decode("utf-8")
if not sender_name:
    raise AssertionError(f"missing sender_name: {delivered}")
```

### 10.2 验证 `CHAT_MESSAGE.sender_avatar` `✅`

关键 Python 骨架：

```python
sender_avatar = delivered.get(11, b"").decode("utf-8")
if not sender_avatar:
    raise AssertionError(f"missing sender_avatar: {delivered}")
```

### 10.3 验证 `CONVERSATION_UPDATE.total_unread` `✅`

关键 Python 骨架：

```python
total_unread = receiver_update.get(5)
if total_unread is None:
    raise AssertionError(f"missing total_unread: {receiver_update}")
```

说明：
- 保留现有 ACK、对端广播、双方会话更新、历史查询验证。
- 不引入第三方 Python 包。

---

## 最后：格式化、编译和链路验证 `✅ 已完成`

文件：`server/`、`docs/features/im/core/v0.0.3/test/`

改动类型：`验证`

### 11.1 Rust 格式化与编译 `✅`

执行命令：

```bash
cd server && cargo fmt --check
cd server && cargo build
```

### 11.2 Rust 测试 `✅`

执行命令：

```bash
cd server && cargo test -p im-conversation
cd server && cargo test -p im-ws
cd server && cargo test
```

### 11.3 数据库和测试数据 `✅`

执行命令：

```bash
scripts/database/reset_sqlx_database.sh
scripts/database/seed_im_conversations.sh
```

### 11.4 HTTP 与 WebSocket 链路验证 `✅`

执行命令：

```bash
scripts/server/start_backend.sh
python3 docs/features/im/core/v0.0.3/test/conversation_message.py
python3 docs/features/im/core/v0.0.3/test/ws_chat_test.py
```

验收结果记录：
- `cargo fmt --check`：通过
- `cargo build`：通过
- `cargo test -p im-conversation`：通过，6 个测试通过
- `cargo test -p im-ws`：通过，4 个测试通过
- `cargo test`：通过，15 个测试通过
- `scripts/database/reset_sqlx_database.sh`：通过，已应用 `20260708000100_im_messages.sql`
- `scripts/database/seed_im_conversations.sh`：通过，写入 53 个账号、51 个会话、102 条成员关系
- `python3 -m py_compile docs/features/im/core/v0.0.3/test/conversation_message.py docs/features/im/core/v0.0.3/test/ws_chat_test.py`：通过
- `python3 docs/features/im/core/v0.0.3/test/conversation_message.py`：通过，验证单会话详情、已读清零、历史消息分页；输出 `unread_after_read=0`
- `python3 docs/features/im/core/v0.0.3/test/ws_chat_test.py`：通过，验证 `sender_name=朱红`、`sender_avatar=identicon:2`、双方 `total_unread` 字段和消息历史闭环
