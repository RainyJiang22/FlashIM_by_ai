# 好友关系 v0.0.1 — 服务端任务清单

基于 [design.md](./design.md) 设计，拆分 `server/` 侧好友关系闭环：数据库迁移、`im-friend` crate、用户搜索、好友申请/关系 HTTP API、好友 WS 事件推送、接受申请后创建私聊会话并发送打招呼消息。

全局约束：
- 本清单只覆盖服务端能力，不实现客户端通讯录 UI、好友 Cubit、扫码页、二维码生成。
- 不实现设计文档“暂不实现”范围：好友备注、好友分组、黑名单、好友数量限制、共同好友、删除好友后清空聊天记录、群聊好友邀请。
- 新接口统一挂 `/api/friends...` 和 `/api/users...`，并复用 `flash_core::jwt::extract_user_id`、`SharedContext`、`AppResult`、`response::utf8_json`。
- `im-friend` 不直接依赖 WebSocket 连接状态；好友事件通过 `FriendBroadcaster` trait 注入，`im-ws` 负责把事件编码成 Protobuf 并发送给在线用户。
- 接受好友申请需要串联好友关系、私聊会话、打招呼消息；若无法把现有 `im-message` 完整纳入同一 SQLx 事务，必须先完成好友关系和会话创建，再调用消息服务，失败时返回错误并保持后续重试不会重复建关系。
- 好友删除只删除 `friend_relations` 双向关系，不删除 `conversations`、`conversation_members`、`messages`。
- 申请记录删除按当前用户视角软隐藏：发起方写 `from_deleted_at`，接收方写 `to_deleted_at`；pending 申请不允许隐藏。
- 参考现有正式链路：`server/modules/im-conversation/*`、`server/modules/im-message/*`、`server/modules/im-ws/src/broadcaster.rs`、`server/src/routes/mod.rs`。

---

## 执行顺序

1. ✅ 任务 1 — `server/migrations/20260720000100_im_friends.sql` 新增好友表迁移（无依赖）
   - ✅ 1.1 补充 `user_profiles.flash_id`
   - ✅ 1.2 创建 `friend_requests`
   - ✅ 1.3 创建 `friend_relations`
   - ✅ 1.4 创建搜索与列表索引
2. ✅ 任务 2 — `proto/friend.proto` 新增好友事件协议（依赖任务 1）
   - ✅ 2.1 定义 `FriendUser`
   - ✅ 2.2 定义 `FriendRequestEvent`
   - ✅ 2.3 定义 `FriendAcceptedEvent`
   - ✅ 2.4 定义 `FriendRemovedEvent`
3. ✅ 任务 3 — `proto/ws.proto` 扩展好友 WS 帧类型（依赖任务 2）
   - ✅ 3.1 新增 `FRIEND_REQUEST = 7`
   - ✅ 3.2 新增 `FRIEND_ACCEPTED = 8`
   - ✅ 3.3 新增 `FRIEND_REMOVED = 9`
4. ✅ 任务 4 — `server/modules/im-ws/build.rs` 编译 friend proto（依赖任务 2、3）
   - ✅ 4.1 监听 `proto/friend.proto`
   - ✅ 4.2 把 `friend.proto` 加入 prost 编译列表
5. ✅ 任务 5 — `server/modules/im-friend/Cargo.toml` 新增好友 crate 配置（依赖任务 1）
   - ✅ 5.1 配置 package
   - ✅ 5.2 添加 Axum/SQLx/serde/uuid/chrono 依赖
   - ✅ 5.3 添加 `flash_core`、`im-conversation`、`im-message` 依赖
6. ✅ 任务 6 — `server/modules/im-friend/src/models.rs` 新增好友领域模型（依赖任务 5）
   - ✅ 6.1 定义状态枚举和查询参数
   - ✅ 6.2 定义数据库行结构
   - ✅ 6.3 定义 HTTP 请求/响应 DTO
7. ✅ 任务 7 — `server/modules/im-friend/src/broadcast.rs` 新增好友广播抽象（依赖任务 6）
   - ✅ 7.1 定义 `FriendBroadcaster`
   - ✅ 7.2 定义好友事件 payload
   - ✅ 7.3 提供 `NoopFriendBroadcaster`
8. ✅ 任务 8 — `server/modules/im-friend/src/repository.rs` 新增好友仓储（依赖任务 6）
   - ✅ 8.1 实现用户搜索与资料查询 SQL
   - ✅ 8.2 实现好友申请 CRUD SQL
   - ✅ 8.3 实现好友关系双向写入/删除/列表 SQL
   - ✅ 8.4 实现 relation_status 计算 SQL
9. ✅ 任务 9 — `server/modules/im-conversation/src/repository.rs` 扩展私聊会话创建/复用（依赖任务 1）
   - ✅ 9.1 查询双方已有私聊会话
   - ✅ 9.2 创建 conversations 记录
   - ✅ 9.3 upsert 双方 conversation_members
10. ✅ 任务 10 — `server/modules/im-conversation/src/service.rs` 暴露私聊会话服务（依赖任务 9）
    - ✅ 10.1 新增 `create_or_get_private`
    - ✅ 10.2 保持消息侧现有 service 方法不变
11. ✅ 任务 11 — `server/modules/im-friend/src/service.rs` 新增好友业务流程（依赖任务 7、8、10）
    - ✅ 11.1 实现发送好友申请
    - ✅ 11.2 实现收到/发出的申请列表
    - ✅ 11.3 实现接受申请：状态、双向关系、私聊会话、打招呼消息、好友事件
    - ✅ 11.4 实现拒绝申请
    - ✅ 11.5 实现删除申请记录、好友列表、删除好友
    - ✅ 11.6 实现用户搜索和公开资料查询
12. ✅ 任务 12 — `server/modules/im-friend/src/routes.rs` 新增 HTTP 路由（依赖任务 11）
    - ✅ 12.1 注册 `/api/friends/requests`
    - ✅ 12.2 注册 `/api/friends`
    - ✅ 12.3 注册 `/api/users/search` 和 `/api/users/{account_id}`
13. ✅ 任务 13 — `server/modules/im-friend/src/lib.rs` 暴露模块入口（依赖任务 12）
    - ✅ 13.1 导出 models/repository/service/routes/broadcast
    - ✅ 13.2 暴露 `router()` 和 `router_with_broadcaster()`
14. ✅ 任务 14 — `server/modules/im-ws/src/frame.rs` 增加好友事件帧 helper（依赖任务 2、3、4）
    - ✅ 14.1 编码 `FRIEND_REQUEST`
    - ✅ 14.2 编码 `FRIEND_ACCEPTED`
    - ✅ 14.3 编码 `FRIEND_REMOVED`
15. ✅ 任务 15 — `server/modules/im-ws/src/broadcaster.rs` 实现好友事件广播（依赖任务 7、14）
    - ✅ 15.1 添加 `im-friend` 依赖并实现 trait
    - ✅ 15.2 转换 `FriendUser` proto
    - ✅ 15.3 按用户发送好友事件帧
16. ✅ 任务 16 — `server/modules/im-ws/src/dispatcher.rs` 更新好友事件入站策略（依赖任务 3）
    - ✅ 16.1 客户端发来的好友事件帧统一 ignore
    - ✅ 16.2 保持 PING/CHAT_MESSAGE 行为不变
17. ✅ 任务 17 — `server/Cargo.toml` 接入 `im-friend`（依赖任务 13、15）
    - ✅ 17.1 添加 workspace member
    - ✅ 17.2 添加宿主依赖
    - ✅ 17.3 给 `im-ws` 补 `im-friend` path 依赖
18. ✅ 任务 18 — `server/src/routes/mod.rs` 注册好友路由（依赖任务 15、17）
    - ✅ 18.1 构造 `WsBroadcaster`
    - ✅ 18.2 merge `im_friend::router_with_broadcaster(...)`
    - ✅ 18.3 保持现有 auth/user/conversation/message/ws 路由不变
19. ✅ 任务 19 — `server/modules/im-friend/src/service.rs` 与仓储测试（依赖任务 11）
    - ✅ 19.1 覆盖分页和 message 校验
    - ✅ 19.2 覆盖 relation_status 优先级
    - ✅ 19.3 覆盖 SQL 关键约束
20. ✅ 任务 20 — `server/src/lib.rs` 补充集成测试（依赖任务 18）
    - ✅ 20.1 验证好友接口缺 token 返回 401
    - ✅ 20.2 验证新增 WS 帧类型可编码
    - ✅ 20.3 验证用户搜索接口路由注册
21. ✅ 任务 21 — `docs/features/im/friend/api/friend/request/friend.py` 新增链路测试脚本（依赖任务 18）
    - ✅ 21.1 登录两个测试用户
    - ✅ 21.2 搜索用户、发送申请、查询收到申请
    - ✅ 21.3 接受申请、查询好友列表、删除好友
22. ✅ 最后 — 格式化、编译、迁移与接口验证（依赖任务 1-21）
    - ✅ 22.1 `cd server && cargo fmt --check`
    - ✅ 22.2 `cd server && cargo build`
    - ✅ 22.3 `cd server && cargo test -p im-friend`
    - ✅ 22.4 `cd server && cargo test -p im-ws`
    - ✅ 22.5 `cd server && cargo test`
    - ✅ 22.6 `python3 docs/features/im/friend/api/friend/request/friend.py`

---

## 任务 1：`server/migrations/20260720000100_im_friends.sql` — 新增好友表迁移 `✅ 已完成`

文件：`server/migrations/20260720000100_im_friends.sql`

改动类型：`新建文件`

### 1.1 补充 flash_id `✅`

```sql
ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS flash_id VARCHAR(64);

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_profiles_flash_id
    ON user_profiles(flash_id)
    WHERE flash_id IS NOT NULL;
```

### 1.2 创建 friend_requests `✅`

```sql
CREATE TABLE friend_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_user_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    to_user_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    message VARCHAR(200) NOT NULL DEFAULT '',
    status SMALLINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    handled_at TIMESTAMPTZ,
    from_deleted_at TIMESTAMPTZ,
    to_deleted_at TIMESTAMPTZ,
    UNIQUE (from_user_id, to_user_id),
    CHECK (from_user_id <> to_user_id)
);
```

### 1.3 创建 friend_relations `✅`

```sql
CREATE TABLE friend_relations (
    user_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    friend_user_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    source_request_id UUID REFERENCES friend_requests(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, friend_user_id),
    CHECK (user_id <> friend_user_id)
);
```

### 1.4 创建索引 `✅`

```sql
CREATE INDEX idx_user_profiles_nickname ON user_profiles(nickname);
CREATE INDEX idx_friend_requests_to_status ON friend_requests(to_user_id, status, updated_at DESC);
CREATE INDEX idx_friend_requests_from_status ON friend_requests(from_user_id, status, updated_at DESC);
CREATE INDEX idx_friend_relations_friend_user ON friend_relations(friend_user_id);
```

---

## 任务 2：`proto/friend.proto` — 新增好友事件协议 `✅ 已完成`

文件：`proto/friend.proto`

改动类型：`新建文件`

### 2.1 定义 FriendUser `✅`

```protobuf
message FriendUser {
  int64 account_id = 1;
  string nickname = 2;
  string avatar = 3;
  string signature = 4;
  string flash_id = 5;
}
```

### 2.2 定义 FriendRequestEvent `✅`

```protobuf
message FriendRequestEvent {
  string request_id = 1;
  FriendUser from_user = 2;
  string message = 3;
  string created_at = 4;
}
```

### 2.3 定义 FriendAcceptedEvent `✅`

```protobuf
message FriendAcceptedEvent {
  string request_id = 1;
  FriendUser friend = 2;
  string conversation_id = 3;
  string accepted_at = 4;
}
```

### 2.4 定义 FriendRemovedEvent `✅`

```protobuf
message FriendRemovedEvent {
  FriendUser friend = 1;
  string removed_at = 2;
}
```

---

## 任务 3：`proto/ws.proto` — 扩展好友 WS 帧类型 `✅ 已完成`

文件：`proto/ws.proto`

改动类型：`修改文件`

### 3.1-3.3 新增好友帧 `✅`

```protobuf
enum WsFrameType {
  PING = 0;
  PONG = 1;
  AUTH = 2;
  AUTH_RESULT = 3;
  CHAT_MESSAGE = 4;
  MESSAGE_ACK = 5;
  CONVERSATION_UPDATE = 6;
  FRIEND_REQUEST = 7;
  FRIEND_ACCEPTED = 8;
  FRIEND_REMOVED = 9;
}
```

---

## 任务 4：`server/modules/im-ws/build.rs` — 编译 friend proto `✅ 已完成`

文件：`server/modules/im-ws/build.rs`

改动类型：`修改文件`

### 4.1-4.2 增加 friend proto `✅`

```rust
let protos = ["../../proto/ws.proto", "../../proto/message.proto", "../../proto/friend.proto"];
for proto in protos {
    println!("cargo:rerun-if-changed={proto}");
}
prost_build::compile_protos(&protos, &["../../proto"])?;
```

---

## 任务 5：`server/modules/im-friend/Cargo.toml` — 新增好友 crate 配置 `✅ 已完成`

文件：`server/modules/im-friend/Cargo.toml`

改动类型：`新建文件`

### 5.1-5.3 配置 crate 与依赖 `✅`

```toml
[package]
name = "im-friend"
version = "0.1.0"
edition = "2024"
publish = false

[dependencies]
async-trait = "0.1.89"
axum = "0.8.9"
chrono = { version = "0.4.42", features = ["serde"] }
flash_core = { path = "../flash_core" }
im-conversation = { path = "../im-conversation" }
im-message = { path = "../im-message" }
serde = { version = "1.0.228", features = ["derive"] }
serde_json = "1.0.145"
sqlx = { version = "0.8.6", features = ["runtime-tokio-rustls", "postgres", "macros", "chrono", "json", "uuid"] }
uuid = { version = "1", features = ["serde", "v4"] }
```

---

## 任务 6：`server/modules/im-friend/src/models.rs` — 新增好友领域模型 `✅ 已完成`

文件：`server/modules/im-friend/src/models.rs`

改动类型：`新建文件`

### 6.1 状态枚举和查询参数 `✅`

```rust
pub const FRIEND_REQUEST_PENDING: i16 = 0;
pub const FRIEND_REQUEST_ACCEPTED: i16 = 1;
pub const FRIEND_REQUEST_REJECTED: i16 = 2;

#[derive(Debug, Deserialize)]
pub struct FriendRequestListQuery {
    pub status: Option<String>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}
```

### 6.2 数据库行结构 `✅`

```rust
#[derive(Debug, sqlx::FromRow)]
pub struct FriendRequestRow { /* id/from/to/message/status/time/profile fields */ }

#[derive(Debug, sqlx::FromRow)]
pub struct FriendUserRow { /* account_id/nickname/avatar/signature/flash_id/relation_status */ }
```

### 6.3 HTTP DTO `✅`

```rust
#[derive(Debug, Deserialize)]
pub struct SendFriendRequestBody {
    pub to_user_id: i64,
    pub message: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct FriendUserResponse {
    pub account_id: i64,
    pub nickname: String,
    pub avatar: String,
    pub signature: String,
    pub flash_id: Option<String>,
    pub relation_status: Option<String>,
}
```

---

## 任务 7：`server/modules/im-friend/src/broadcast.rs` — 新增好友广播抽象 `✅ 已完成`

文件：`server/modules/im-friend/src/broadcast.rs`

改动类型：`新建文件`

### 7.1-7.3 定义 trait 与 Noop `✅`

```rust
#[derive(Clone, Debug)]
pub struct FriendUserPayload { /* account_id, nickname, avatar, signature, flash_id */ }

#[async_trait::async_trait]
pub trait FriendBroadcaster: Send + Sync {
    async fn broadcast_friend_request(&self, to_user_id: i64, event: FriendRequestPayload) -> AppResult<()>;
    async fn broadcast_friend_accepted(&self, to_user_id: i64, event: FriendAcceptedPayload) -> AppResult<()>;
    async fn broadcast_friend_removed(&self, to_user_id: i64, event: FriendRemovedPayload) -> AppResult<()>;
}
```

---

## 任务 8：`server/modules/im-friend/src/repository.rs` — 新增好友仓储 `✅ 已完成`

文件：`server/modules/im-friend/src/repository.rs`

改动类型：`新建文件`

### 8.1 用户搜索与资料查询 `✅`

签名骨架：

```rust
pub async fn search_users(pool: &PgPool, current_user_id: i64, query: &str, limit: i64) -> AppResult<Vec<FriendUserRow>>;
pub async fn get_public_user(pool: &PgPool, current_user_id: i64, account_id: i64) -> AppResult<Option<FriendUserRow>>;
```

### 8.2 好友申请 SQL `✅`

签名骨架：

```rust
pub async fn upsert_friend_request(pool: &PgPool, from_user_id: i64, to_user_id: i64, message: &str) -> AppResult<FriendRequestRow>;
pub async fn list_received_requests(pool: &PgPool, user_id: i64, status: Option<i16>, limit: i64, offset: i64) -> AppResult<Vec<FriendRequestRow>>;
pub async fn list_sent_requests(pool: &PgPool, user_id: i64, status: Option<i16>, limit: i64, offset: i64) -> AppResult<Vec<FriendRequestRow>>;
```

### 8.3 好友关系 SQL `✅`

签名骨架：

```rust
pub async fn are_friends(pool: &PgPool, user_id: i64, friend_user_id: i64) -> AppResult<bool>;
pub async fn insert_friend_relations(pool: &PgPool, user_id: i64, friend_user_id: i64, request_id: Uuid) -> AppResult<()>;
pub async fn remove_friend_relations(pool: &PgPool, user_id: i64, friend_user_id: i64) -> AppResult<u64>;
pub async fn list_friends(pool: &PgPool, user_id: i64) -> AppResult<Vec<FriendUserRow>>;
```

### 8.4 relation_status SQL `✅`

优先级骨架：

```text
friend > pending_sent > pending_received > none
```

---

## 任务 9：`server/modules/im-conversation/src/repository.rs` — 扩展私聊会话创建/复用 `✅ 已完成`

文件：`server/modules/im-conversation/src/repository.rs`

改动类型：`修改文件`

### 9.1-9.3 新增 create_or_get_private 所需 SQL `✅`

```rust
pub async fn find_private_conversation(pool: &PgPool, user_a: i64, user_b: i64) -> AppResult<Option<Uuid>>;
pub async fn create_private_conversation(pool: &PgPool, user_a: i64, user_b: i64) -> AppResult<Uuid>;
```

说明：
- `find_private_conversation` 必须确认 type=0 且成员恰好包含双方。
- `create_private_conversation` 创建 `conversations` 后 upsert 两条 `conversation_members`，并把 `is_deleted` 置回 false。

---

## 任务 10：`server/modules/im-conversation/src/service.rs` — 暴露私聊会话服务 `✅ 已完成`

文件：`server/modules/im-conversation/src/service.rs`

改动类型：`修改文件`

### 10.1 新增 create_or_get_private `✅`

```rust
impl<'a> ConversationMessageService<'a> {
    pub async fn create_or_get_private(&self, user_a: i64, user_b: i64) -> AppResult<Uuid>;
}
```

---

## 任务 11：`server/modules/im-friend/src/service.rs` — 新增好友业务流程 `✅ 已完成`

文件：`server/modules/im-friend/src/service.rs`

改动类型：`新建文件`

### 11.1-11.6 实现服务方法 `✅`

```rust
pub struct FriendService<B> {
    broadcaster: Arc<B>,
}

impl<B: FriendBroadcaster> FriendService<B> {
    pub async fn send_request(&self, context: &SharedContext, from_user_id: i64, body: SendFriendRequestBody) -> AppResult<FriendRequestResponse>;
    pub async fn accept_request(&self, context: &SharedContext, operator_id: i64, request_id: Uuid) -> AppResult<AcceptFriendRequestResponse>;
    pub async fn reject_request(&self, context: &SharedContext, operator_id: i64, request_id: Uuid) -> AppResult<RejectFriendRequestResponse>;
    pub async fn delete_request(&self, context: &SharedContext, operator_id: i64, request_id: Uuid) -> AppResult<()>;
    pub async fn list_friends(&self, context: &SharedContext, user_id: i64) -> AppResult<Vec<FriendUserResponse>>;
    pub async fn remove_friend(&self, context: &SharedContext, user_id: i64, friend_user_id: i64) -> AppResult<()>;
    pub async fn search_users(&self, context: &SharedContext, user_id: i64, q: String, limit: Option<i64>) -> AppResult<Vec<FriendUserResponse>>;
    pub async fn get_public_user(&self, context: &SharedContext, user_id: i64, account_id: i64) -> AppResult<FriendUserResponse>;
}
```

---

## 任务 12：`server/modules/im-friend/src/routes.rs` — 新增 HTTP 路由 `✅ 已完成`

文件：`server/modules/im-friend/src/routes.rs`

改动类型：`新建文件`

### 12.1-12.3 注册路由 `✅`

```rust
pub fn router_with_broadcaster<B>(broadcaster: Arc<B>) -> Router<SharedContext>
where
    B: FriendBroadcaster + Clone + 'static,
{
    Router::new()
        .route("/api/friends/requests", post(send_request))
        .route("/api/friends/requests/received", get(list_received_requests))
        .route("/api/friends/requests/sent", get(list_sent_requests))
        .route("/api/friends/requests/{id}/accept", post(accept_request))
        .route("/api/friends/requests/{id}/reject", post(reject_request))
        .route("/api/friends/requests/{id}", delete(delete_request))
        .route("/api/friends", get(list_friends))
        .route("/api/friends/{friend_user_id}", delete(remove_friend))
        .route("/api/users/search", get(search_users))
        .route("/api/users/{account_id}", get(get_public_user))
}
```

---

## 任务 13：`server/modules/im-friend/src/lib.rs` — 暴露模块入口 `✅ 已完成`

文件：`server/modules/im-friend/src/lib.rs`

改动类型：`新建文件`

### 13.1-13.2 导出模块和 router `✅`

```rust
pub mod broadcast;
pub mod models;
pub mod repository;
pub mod routes;
pub mod service;

pub use routes::{router, router_with_broadcaster};
```

---

## 任务 14：`server/modules/im-ws/src/frame.rs` — 增加好友事件帧 helper `✅ 已完成`

文件：`server/modules/im-ws/src/frame.rs`

改动类型：`修改文件`

### 14.1-14.3 新增 helper `✅`

```rust
pub fn friend_request_frame(event: FriendRequestEvent) -> Vec<u8>;
pub fn friend_accepted_frame(event: FriendAcceptedEvent) -> Vec<u8>;
pub fn friend_removed_frame(event: FriendRemovedEvent) -> Vec<u8>;
```

---

## 任务 15：`server/modules/im-ws/src/broadcaster.rs` — 实现好友事件广播 `✅ 已完成`

文件：`server/modules/im-ws/src/broadcaster.rs`

改动类型：`修改文件`

### 15.1-15.3 实现 FriendBroadcaster `✅`

```rust
#[async_trait]
impl FriendBroadcaster for WsBroadcaster {
    async fn broadcast_friend_request(&self, to_user_id: i64, event: FriendRequestPayload) -> AppResult<()> {
        self.state.send_to_user(to_user_id, friend_request_frame(to_proto_request(event)));
        Ok(())
    }
}
```

---

## 任务 16：`server/modules/im-ws/src/dispatcher.rs` — 更新好友事件入站策略 `✅ 已完成`

文件：`server/modules/im-ws/src/dispatcher.rs`

改动类型：`修改文件`

### 16.1-16.2 忽略客户端好友事件帧 `✅`

```rust
WsFrameType::FriendRequest | WsFrameType::FriendAccepted | WsFrameType::FriendRemoved => {
    Ok(DispatchOutcome::Ignore)
}
```

---

## 任务 17：`server/Cargo.toml` — 接入 im-friend `✅ 已完成`

文件：`server/Cargo.toml`、`server/modules/im-ws/Cargo.toml`

改动类型：`配置修改`

### 17.1-17.3 添加 workspace 和依赖 `✅`

```toml
members = [
    "modules/im-friend",
]

[dependencies]
im-friend = { path = "modules/im-friend" }
```

---

## 任务 18：`server/src/routes/mod.rs` — 注册好友路由 `✅ 已完成`

文件：`server/src/routes/mod.rs`

改动类型：`修改文件`

### 18.1-18.3 merge 好友路由 `✅`

```rust
use im_friend::router_with_broadcaster as build_im_friend_router;
use im_ws::broadcaster::WsBroadcaster;

.merge(build_im_friend_router(Arc::new(WsBroadcaster::new(
    im_ws::ws_state(),
    state.postgres.pool().clone(),
))))
```

说明：
- 如果当前 `im-ws` 没有暴露全局 `WsState`，优先在 `im-ws` 提供 `shared_state()`，避免创建多个互不相通的在线状态。

---

## 任务 19：`server/modules/im-friend/src/service.rs` 与仓储测试 `✅ 已完成`

文件：`server/modules/im-friend/src/service.rs`、`server/modules/im-friend/src/repository.rs`

改动类型：`修改文件`

### 19.1-19.3 补测试 `✅`

```rust
#[cfg(test)]
mod tests {
    #[test]
    fn normalize_message_rejects_too_long_text() {}

    #[test]
    fn relation_status_priority_prefers_friend() {}
}
```

---

## 任务 20：`server/src/lib.rs` — 补充集成测试 `✅ 已完成`

文件：`server/src/lib.rs`

改动类型：`修改文件`

### 20.1-20.3 路由和帧测试 `✅`

```rust
#[tokio::test]
async fn friend_routes_require_authentication() {}

#[test]
fn friend_ws_frame_types_encode() {}
```

---

## 任务 21：`docs/features/im/friend/api/friend/request/friend.py` — 新增链路测试脚本 `✅ 已完成`

文件：`docs/features/im/friend/api/friend/request/friend.py`

改动类型：`新建文件`

### 21.1-21.3 链路脚本 `✅`

脚本流程：

```text
1. POST /auth/sms + POST /auth/login 登录 A、B
2. GET /api/users/search?q=<B phone>
3. POST /api/friends/requests
4. GET /api/friends/requests/received
5. POST /api/friends/requests/{id}/accept
6. GET /api/friends
7. DELETE /api/friends/{friend_user_id}
```

---

## 最后：格式化、编译、迁移与接口验证 `✅ 已完成`

文件：`docs/features/im/friend/v0.0.1/server/tasks.md`

改动类型：`验证`

### 22.1-22.6 执行验证 `✅`

```bash
cd server && cargo fmt --check
cd server && cargo build
cd server && cargo test -p im-friend
cd server && cargo test -p im-ws
cd server && cargo test
python3 docs/features/im/friend/api/friend/request/friend.py
```

实际验证结果：

| 命令 | 结果 |
|------|------|
| `cd server && cargo fmt --check` | 通过 |
| `cd server && cargo build` | 通过 |
| `cd server && cargo test -p im-friend` | 通过，4 passed |
| `cd server && cargo test -p im-ws` | 通过，5 passed |
| `cd server && cargo test` | 通过，21 passed |
| `python3 -m py_compile docs/features/im/friend/api/friend/request/friend.py` | 通过 |
| `python3 docs/features/im/friend/api/friend/request/friend.py` | 通过，8 个接口步骤 PASS，并生成 API 文档 |
