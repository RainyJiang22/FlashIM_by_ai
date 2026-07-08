# IM Core v0.0.3 — 服务端任务清单

基于 [design.md](./design.md) 设计，拆分 `server/` 侧文本消息收发闭环：消息表迁移、`im-message` crate、Protobuf 协议扩展、`im-ws` 帧分发与在线广播、历史消息 HTTP 查询、会话预览和未读数更新。

全局约束：
- 本清单只覆盖文本消息完整收发链路：`CHAT_MESSAGE` 入站、消息持久化、会话序列号递增、`MESSAGE_ACK` 回执、对方实时广播、`CONVERSATION_UPDATE` 推送、历史消息查询。
- 必须复用现有认证链路：HTTP 继续使用 `flash_core::jwt::extract_user_id`，WebSocket 继续先收 `AUTH` 帧并解析 Bearer token。
- `im-message` 不直接依赖 `im-ws`；广播能力通过 `MessageBroadcaster` trait 注入，`im-ws` 只实现该 trait。
- `im-conversation` 继续负责会话成员关系、会话预览和未读数更新；`im-message` 不重复写成员校验 SQL。
- 当前仓库迁移文件采用 SQLx 时间戳命名，本版本实际文件使用 `server/migrations/20260708000100_im_messages.sql`，不使用设计中的概念名 `20260330_003_messages.sql`。
- `conversation_seq` 在 v0.0.2 中可能已经预留；迁移必须对该表使用兼容写法，避免重复建表导致本地迁移失败。
- 不实现设计文档“暂不实现”范围：图片/文件消息、消息撤回、per-user 消息删除、已读回执、消息搜索、消息置顶、增量同步、`client_id` 去重。
- 参考现有文件：`server/modules/im-conversation/*` 的 Axum/SQLx 分层方式、`server/modules/im-ws/src/handler.rs` 的认证流程、`proto/ws.proto` 的 `prost-build` 生成方式、`docs/features/im/core/v0.0.2/server/tasks.md` 的任务追踪格式。

---

## 执行顺序

1. ✅ 任务 1 — `server/migrations/20260708000100_im_messages.sql` 新增消息表迁移（无依赖）
   - ✅ 1.1 创建 `messages`
   - ✅ 1.2 兼容创建或复用 `conversation_seq`
   - ✅ 1.3 创建历史查询索引
2. ✅ 任务 2 — `proto/message.proto` 新增消息协议（依赖任务 1）
   - ✅ 2.1 定义 `ChatMessage`
   - ✅ 2.2 定义 `SendMessageRequest`
   - ✅ 2.3 定义 `MessageAck` 和 `ConversationUpdate`
3. ✅ 任务 3 — `proto/ws.proto` 扩展 WebSocket 帧类型（依赖任务 2）
   - ✅ 3.1 新增 `CHAT_MESSAGE = 4`
   - ✅ 3.2 新增 `MESSAGE_ACK = 5`
   - ✅ 3.3 新增 `CONVERSATION_UPDATE = 6`
4. ✅ 任务 4 — `server/modules/im-ws/build.rs` 编译多 proto 文件（依赖任务 2、3）
   - ✅ 4.1 监听 `ws.proto`
   - ✅ 4.2 监听并编译 `message.proto`
5. ✅ 任务 5 — `server/modules/im-message/Cargo.toml` 新增消息 crate 配置（依赖任务 1）
   - ✅ 5.1 配置 crate 元信息
   - ✅ 5.2 添加 `flash_core`、`im-conversation`、SQLx、Axum 等依赖
6. ✅ 任务 6 — `server/modules/im-message/src/models.rs` 新增消息模型（依赖任务 5）
   - ✅ 6.1 定义数据库行结构
   - ✅ 6.2 定义写入模型
   - ✅ 6.3 定义历史查询响应和分页参数
7. ✅ 任务 7 — `server/modules/im-message/src/seq.rs` 新增会话序列号生成器（依赖任务 6）
   - ✅ 7.1 实现 `next_seq`
   - ✅ 7.2 覆盖并发安全 SQL 骨架测试
8. ✅ 任务 8 — `server/modules/im-message/src/repository.rs` 新增消息仓储（依赖任务 6、7）
   - ✅ 8.1 实现消息写入
   - ✅ 8.2 实现 `before_seq` 历史查询
   - ✅ 8.3 关联 `user_profiles` 补发送者信息
9. ✅ 任务 9 — `server/modules/im-message/src/broadcast.rs` 新增广播抽象（依赖任务 6）
   - ✅ 9.1 定义 `MessageBroadcaster`
   - ✅ 9.2 提供 `NoopBroadcaster`
10. ✅ 任务 10 — `server/modules/im-conversation/src/repository.rs` 补充消息联动 SQL（依赖任务 1）
    - ✅ 10.1 校验成员关系
    - ✅ 10.2 查询成员列表
    - ✅ 10.3 更新最后消息预览
    - ✅ 10.4 给非发送者累加未读
11. ✅ 任务 11 — `server/modules/im-conversation/src/service.rs` 暴露消息联动服务（依赖任务 10）
    - ✅ 11.1 新增 `is_member`
    - ✅ 11.2 新增 `get_member_ids`
    - ✅ 11.3 新增 `update_last_message`
    - ✅ 11.4 新增 `increment_unread`
12. ✅ 任务 12 — `server/modules/im-conversation/src/lib.rs` 暴露跨 crate 服务入口（依赖任务 11）
    - ✅ 12.1 公开 `service`
    - ✅ 12.2 保持原 `router()` 入口不变
13. ✅ 任务 13 — `server/modules/im-message/src/service.rs` 新增消息业务流程（依赖任务 7、8、9、11）
    - ✅ 13.1 实现 `send`
    - ✅ 13.2 实现 `get_history`
    - ✅ 13.3 构造 `ChatMessage`、`MessageAck`、`ConversationUpdate`
14. ✅ 任务 14 — `server/modules/im-message/src/routes.rs` 新增历史消息 HTTP 路由（依赖任务 13）
    - ✅ 14.1 注册 `GET /conversations/:id/messages`
    - ✅ 14.2 解析 `before_seq` 和 `limit`
15. ✅ 任务 15 — `server/modules/im-message/src/lib.rs` 暴露模块入口（依赖任务 14）
    - ✅ 15.1 导出模块
    - ✅ 15.2 暴露 `router()`
16. ✅ 任务 16 — `server/Cargo.toml` 接入 `im-message` workspace 和依赖（依赖任务 15）
    - ✅ 16.1 添加 workspace member
    - ✅ 16.2 添加宿主依赖
    - ✅ 16.3 给 `im-ws` 补 `im-message` 依赖
17. ✅ 任务 17 — `server/modules/im-ws/src/frame.rs` 增加消息帧编解码 helper（依赖任务 4、13、16）
    - ✅ 17.1 编码 `CHAT_MESSAGE`
    - ✅ 17.2 编码 `MESSAGE_ACK`
    - ✅ 17.3 编码 `CONVERSATION_UPDATE`
18. ✅ 任务 18 — `server/modules/im-ws/src/state.rs` 新增在线用户状态（依赖任务 16）
    - ✅ 18.1 管理账号到连接 sender
    - ✅ 18.2 支持注册、移除、按用户发送
19. ✅ 任务 19 — `server/modules/im-ws/src/broadcaster.rs` 实现 WebSocket 广播器（依赖任务 17、18）
    - ✅ 19.1 实现 `MessageBroadcaster`
    - ✅ 19.2 推送 `ChatMessage`
    - ✅ 19.3 推送 `ConversationUpdate`
20. ✅ 任务 20 — `server/modules/im-ws/src/dispatcher.rs` 重写帧分发（依赖任务 13、17、19）
    - ✅ 20.1 保留 `PING -> PONG`
    - ✅ 20.2 处理 `CHAT_MESSAGE`
    - ✅ 20.3 返回 `MESSAGE_ACK`
21. ✅ 任务 21 — `server/modules/im-ws/src/handler.rs` 改造认证后连接循环（依赖任务 18、20）
    - ✅ 21.1 注册在线连接
    - ✅ 21.2 使用 mpsc channel 支持服务端主动推送
    - ✅ 21.3 `select!` 同时处理客户端输入和服务端输出
22. ✅ 任务 22 — `server/modules/im-ws/src/lib.rs` 注册带在线状态的 `/ws/im` 路由（依赖任务 18、21）
    - ✅ 22.1 新增模块导出
    - ✅ 22.2 注入共享 `WsState`
23. ✅ 任务 23 — `server/src/routes/mod.rs` 注册 `im-message` HTTP 路由（依赖任务 15、16）
    - ✅ 23.1 merge `im_message::router()`
    - ✅ 23.2 保持现有 `/conversations` 和 `/ws/im` 不变
24. ✅ 任务 24 — `server/src/lib.rs` 补充服务端集成测试（依赖任务 23）
    - ✅ 24.1 验证历史消息路由注册
    - ✅ 24.2 验证缺失 token 返回 401
    - ✅ 24.3 验证新增帧类型编解码
25. ✅ 任务 25 — `docs/features/im/core/v0.0.3/test/ws_chat_test.py` 新增 WebSocket 全链路测试脚本（依赖任务 21、23）
    - ✅ 25.1 登录两个测试用户
    - ✅ 25.2 完成双 WebSocket 认证
    - ✅ 25.3 验证 ACK、广播、会话更新、历史查询
26. ✅ 任务 26 — `docs/features/im/core/v0.0.3/test/conversation_message.py` 新增历史消息接口 Link Test Writer 脚本（依赖任务 14、23）
    - ✅ 26.1 登录并获取 token
    - ✅ 26.2 请求 `GET /conversations/:id/messages`
    - ✅ 26.3 验证 `before_seq` 分页
27. ✅ 最后 — 格式化、编译、迁移与链路验证（依赖任务 1-26）
    - ✅ 27.1 `cd server && cargo fmt --check`
    - ✅ 27.2 `cd server && cargo build`
    - ✅ 27.3 `cd server && cargo test -p im-message`
    - ✅ 27.4 `cd server && cargo test -p im-ws`
    - ✅ 27.5 `cd server && cargo test`
    - ✅ 27.6 `scripts/database/reset_sqlx_database.sh`
    - ✅ 27.7 `scripts/database/seed_im_conversations.sh`
    - ✅ 27.8 `python docs/features/im/core/v0.0.3/test/ws_chat_test.py`
    - ✅ 27.9 `python docs/features/im/core/v0.0.3/test/conversation_message.py`

---

## 任务 1：`server/migrations/20260708000100_im_messages.sql` — 新增消息表迁移 `✅ 已完成`

文件：`server/migrations/20260708000100_im_messages.sql`

改动类型：`新建`

### 1.1 创建 messages `✅`

关键 SQL 骨架：

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    seq BIGINT NOT NULL,
    type SMALLINT NOT NULL DEFAULT 0,
    content TEXT NOT NULL,
    extra JSONB,
    status SMALLINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (conversation_id, seq)
);
```

说明：
- `type=0` 为文本消息，本版本只写入文本。
- `status` 只保留字段，不实现撤回和删除。

### 1.2 兼容创建 conversation_seq `✅`

关键 SQL 骨架：

```sql
CREATE TABLE IF NOT EXISTS conversation_seq (
    conversation_id UUID PRIMARY KEY REFERENCES conversations(id) ON DELETE CASCADE,
    current_seq BIGINT NOT NULL DEFAULT 0
);
```

说明：
- 如果 v0.0.2 已创建该表，本迁移不能失败。
- 如果已存在 `updated_at` 字段，不需要删除或重建。

### 1.3 创建历史查询索引 `✅`

关键 SQL 骨架：

```sql
CREATE INDEX idx_messages_conversation_seq
    ON messages(conversation_id, seq DESC);

CREATE INDEX idx_messages_conversation_created
    ON messages(conversation_id, created_at DESC);
```

说明：
- 历史查询以 `seq` 倒序分页，不能使用 offset 作为主要分页策略。

---

## 任务 2：`proto/message.proto` — 新增消息协议 `✅ 已完成`

文件：`proto/message.proto`

改动类型：`新建`

### 2.1 定义 ChatMessage `✅`

关键 Protobuf 骨架：

```proto
syntax = "proto3";

package im;

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
}
```

说明：
- `extra` 先用 JSON 字符串承载，避免 Protobuf map 与 SQLx JSONB 之间增加额外转换复杂度。

### 2.2 定义 SendMessageRequest `✅`

关键 Protobuf 骨架：

```proto
message SendMessageRequest {
  string conversation_id = 1;
  int32 type = 2;
  string content = 3;
  string extra = 4;
  string client_id = 5;
}
```

说明：
- `client_id` 字段保留但本版本不做去重。

### 2.3 定义 MessageAck 和 ConversationUpdate `✅`

关键 Protobuf 骨架：

```proto
message MessageAck {
  string message_id = 1;
  int64 seq = 2;
}

message ConversationUpdate {
  string conversation_id = 1;
  string last_message_preview = 2;
  string last_message_at = 3;
  int32 unread_count = 4;
}
```

说明：
- `ConversationUpdate` 用于前端本地刷新列表，不要求客户端重新拉取会话列表。

---

## 任务 3：`proto/ws.proto` — 扩展 WebSocket 帧类型 `✅ 已完成`

文件：`proto/ws.proto`

改动类型：`修改`

### 3.1 新增 CHAT_MESSAGE `✅`

关键 Protobuf 骨架：

```proto
enum WsFrameType {
  PING = 0;
  PONG = 1;
  AUTH = 2;
  AUTH_RESULT = 3;
  CHAT_MESSAGE = 4;
  MESSAGE_ACK = 5;
  CONVERSATION_UPDATE = 6;
}
```

说明：
- 保持现有编号不变，避免破坏 v0.0.1 认证和心跳。

---

## 任务 4：`server/modules/im-ws/build.rs` — 编译多 proto 文件 `✅ 已完成`

文件：`server/modules/im-ws/build.rs`

改动类型：`修改`

### 4.1 监听并编译 ws.proto 与 message.proto `✅`

关键 Rust 骨架：

```rust
let proto_files = [repo_root.join("proto/ws.proto"), repo_root.join("proto/message.proto")];

for proto_file in &proto_files {
    println!("cargo:rerun-if-changed={}", proto_file.display());
}

config.compile_protos(&proto_files, &[proto_dir])?;
```

说明：
- `server/modules/im-ws/src/proto.rs` 继续 `include!(concat!(env!("OUT_DIR"), "/im.rs"));`，不需要改生成入口。

---

## 任务 5：`server/modules/im-message/Cargo.toml` — 新增消息 crate 配置 `✅ 已完成`

文件：`server/modules/im-message/Cargo.toml`

改动类型：`新建`

### 5.1 配置 package 和依赖 `✅`

关键 TOML 骨架：

```toml
[package]
name = "im-message"
version = "0.1.0"
edition = "2024"
publish = false

[dependencies]
async-trait = "0.1.89"
axum = { version = "0.8.9" }
chrono = { version = "0.4.42", features = ["serde"] }
flash_core = { path = "../flash_core" }
im-conversation = { path = "../im-conversation" }
serde = { version = "1.0.228", features = ["derive"] }
serde_json = "1.0.145"
sqlx = { version = "0.8.6", features = ["runtime-tokio-rustls", "postgres", "macros", "chrono", "uuid", "json"] }
uuid = { version = "1", features = ["serde", "v4"] }
```

说明：
- `im-message` 只依赖 `im-conversation`，不能依赖 `im-ws`。

---

## 任务 6：`server/modules/im-message/src/models.rs` — 新增消息模型 `✅ 已完成`

文件：`server/modules/im-message/src/models.rs`

改动类型：`新建`

### 6.1 定义数据库行结构 `✅`

关键 Rust 骨架：

```rust
#[derive(Debug, sqlx::FromRow)]
pub struct MessageRow {
    pub id: uuid::Uuid,
    pub conversation_id: uuid::Uuid,
    pub sender_id: i64,
    pub seq: i64,
    pub r#type: i16,
    pub content: String,
    pub extra: Option<serde_json::Value>,
    pub status: i16,
    pub created_at: chrono::DateTime<chrono::Utc>,
}
```

### 6.2 定义写入模型 `✅`

关键 Rust 骨架：

```rust
pub struct NewMessage {
    pub conversation_id: uuid::Uuid,
    pub sender_id: i64,
    pub seq: i64,
    pub r#type: i16,
    pub content: String,
    pub extra: Option<serde_json::Value>,
}
```

### 6.3 定义历史查询响应和分页参数 `✅`

关键 Rust 骨架：

```rust
#[derive(Debug, serde::Deserialize)]
pub struct MessageQuery {
    pub before_seq: Option<i64>,
    pub limit: Option<i64>,
}

#[derive(Debug, serde::Serialize)]
pub struct MessageWithSender {
    pub id: uuid::Uuid,
    pub conversation_id: uuid::Uuid,
    pub sender_id: String,
    pub sender_name: Option<String>,
    pub sender_avatar: Option<String>,
    pub seq: i64,
    pub msg_type: i16,
    pub content: String,
    pub extra: Option<serde_json::Value>,
    pub status: i16,
    pub created_at: chrono::DateTime<chrono::Utc>,
}
```

说明：
- JSON 响应中的 `sender_id` 保持字符串，和现有会话接口中的用户 ID 字符串化风格一致。

---

## 任务 7：`server/modules/im-message/src/seq.rs` — 新增会话序列号生成器 `✅ 已完成`

文件：`server/modules/im-message/src/seq.rs`

改动类型：`新建`

### 7.1 实现 next_seq `✅`

关键 Rust 骨架：

```rust
pub struct SeqGenerator;

impl SeqGenerator {
    pub async fn next_seq(pool: &sqlx::PgPool, conversation_id: uuid::Uuid) -> flash_core::AppResult<i64> {
        // 1. INSERT ... ON CONFLICT
        // 2. current_seq + 1
        // 3. RETURNING current_seq
    }
}
```

关键 SQL 骨架：

```sql
INSERT INTO conversation_seq (conversation_id, current_seq)
VALUES ($1, 1)
ON CONFLICT (conversation_id)
DO UPDATE SET current_seq = conversation_seq.current_seq + 1
RETURNING current_seq;
```

说明：
- 采用单条 upsert，避免先 `UPDATE` 再 `INSERT` 的竞态窗口。

---

## 任务 8：`server/modules/im-message/src/repository.rs` — 新增消息仓储 `✅ 已完成`

文件：`server/modules/im-message/src/repository.rs`

改动类型：`新建`

### 8.1 实现消息写入 `✅`

关键 Rust 骨架：

```rust
pub async fn insert_message(
    pool: &sqlx::PgPool,
    message: NewMessage,
) -> flash_core::AppResult<MessageRow>;
```

关键 SQL 骨架：

```sql
INSERT INTO messages (conversation_id, sender_id, seq, type, content, extra)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING id, conversation_id, sender_id, seq, type, content, extra, status, created_at;
```

### 8.2 实现 before_seq 历史查询 `✅`

关键 Rust 骨架：

```rust
pub async fn find_before(
    pool: &sqlx::PgPool,
    conversation_id: uuid::Uuid,
    before_seq: i64,
    limit: i64,
) -> flash_core::AppResult<Vec<MessageWithSenderRow>>;
```

关键 SQL 骨架：

```sql
SELECT m.*, p.nickname AS sender_name, p.avatar_url AS sender_avatar
FROM messages m
LEFT JOIN user_profiles p ON p.account_id = m.sender_id
WHERE m.conversation_id = $1
  AND m.seq < $2
ORDER BY m.seq DESC
LIMIT $3;
```

### 8.3 补充 SQL 约束测试 `✅`

关键测试骨架：

```rust
#[test]
fn history_sql_uses_seq_pagination() {
    let sql = find_before_sql();
    assert!(sql.contains("m.seq < $2"));
    assert!(sql.contains("ORDER BY m.seq DESC"));
}
```

---

## 任务 9：`server/modules/im-message/src/broadcast.rs` — 新增广播抽象 `✅ 已完成`

文件：`server/modules/im-message/src/broadcast.rs`

改动类型：`新建`

### 9.1 定义 MessageBroadcaster `✅`

关键 Rust 骨架：

```rust
#[async_trait::async_trait]
pub trait MessageBroadcaster: Send + Sync {
    async fn broadcast_message(
        &self,
        message: &crate::models::MessageRow,
        member_ids: &[i64],
        exclude_sender: Option<i64>,
    );

    async fn broadcast_conversation_update(
        &self,
        updates: Vec<ConversationUpdateEvent>,
    );
}
```

### 9.2 提供 NoopBroadcaster `✅`

关键 Rust 骨架：

```rust
#[derive(Default)]
pub struct NoopBroadcaster;

#[async_trait::async_trait]
impl MessageBroadcaster for NoopBroadcaster {
    // 空实现，用于 HTTP 历史查询或测试。
}
```

说明：
- trait 放在 `im-message`，`im-ws` 通过实现 trait 接入，不形成 crate 循环。

---

## 任务 10：`server/modules/im-conversation/src/repository.rs` — 补充消息联动 SQL `✅ 已完成`

文件：`server/modules/im-conversation/src/repository.rs`

改动类型：`修改`

### 10.1 校验成员关系 `✅`

关键 Rust 骨架：

```rust
pub async fn is_member(
    pool: &sqlx::PgPool,
    conversation_id: uuid::Uuid,
    user_id: i64,
) -> flash_core::AppResult<bool>;
```

关键 SQL 骨架：

```sql
SELECT EXISTS (
    SELECT 1
    FROM conversation_members
    WHERE conversation_id = $1
      AND user_id = $2
      AND is_deleted = FALSE
);
```

### 10.2 查询成员列表 `✅`

关键 Rust 骨架：

```rust
pub async fn get_member_ids(
    pool: &sqlx::PgPool,
    conversation_id: uuid::Uuid,
) -> flash_core::AppResult<Vec<i64>>;
```

### 10.3 更新最后消息预览 `✅`

关键 Rust 骨架：

```rust
pub async fn update_last_message(
    pool: &sqlx::PgPool,
    conversation_id: uuid::Uuid,
    preview: &str,
    last_message_at: chrono::DateTime<chrono::Utc>,
) -> flash_core::AppResult<()>;
```

### 10.4 给非发送者累加未读 `✅`

关键 Rust 骨架：

```rust
pub async fn increment_unread(
    pool: &sqlx::PgPool,
    conversation_id: uuid::Uuid,
    sender_id: i64,
) -> flash_core::AppResult<Vec<(i64, i32)>>;
```

关键 SQL 骨架：

```sql
UPDATE conversation_members
SET unread_count = unread_count + 1
WHERE conversation_id = $1
  AND user_id <> $2
RETURNING user_id, unread_count;
```

说明：
- 返回更新后的未读数，供 `CONVERSATION_UPDATE` 给每个成员推送差异值。

---

## 任务 11：`server/modules/im-conversation/src/service.rs` — 暴露消息联动服务 `✅ 已完成`

文件：`server/modules/im-conversation/src/service.rs`

改动类型：`修改`

### 11.1 新增服务函数 `✅`

关键 Rust 骨架：

```rust
pub async fn is_member(
    context: &flash_core::SharedContext,
    conversation_id: uuid::Uuid,
    user_id: i64,
) -> flash_core::AppResult<bool>;

pub async fn get_member_ids(
    context: &flash_core::SharedContext,
    conversation_id: uuid::Uuid,
) -> flash_core::AppResult<Vec<i64>>;

pub async fn update_last_message(
    context: &flash_core::SharedContext,
    conversation_id: uuid::Uuid,
    preview: &str,
    last_message_at: chrono::DateTime<chrono::Utc>,
) -> flash_core::AppResult<()>;

pub async fn increment_unread(
    context: &flash_core::SharedContext,
    conversation_id: uuid::Uuid,
    sender_id: i64,
) -> flash_core::AppResult<Vec<(i64, i32)>>;
```

说明：
- 现有 `list_conversations` 不改行为。
- 发送消息时如果不是成员，返回 `AppError::unauthorized("not a conversation member")` 或同等语义错误。

---

## 任务 12：`server/modules/im-conversation/src/lib.rs` — 暴露跨 crate 服务入口 `✅ 已完成`

文件：`server/modules/im-conversation/src/lib.rs`

改动类型：`修改`

### 12.1 公开 service 模块 `✅`

关键 Rust 骨架：

```rust
mod models;
mod repository;
mod routes;
pub mod service;

pub fn router() -> Router<SharedContext> {
    routes::router()
}
```

说明：
- 只公开 `service` 即可；`repository` 保持 crate 内部实现细节。

---

## 任务 13：`server/modules/im-message/src/service.rs` — 新增消息业务流程 `✅ 已完成`

文件：`server/modules/im-message/src/service.rs`

改动类型：`新建`

### 13.1 实现 send `✅`

关键 Rust 骨架：

```rust
pub struct MessageService<B> {
    broadcaster: B,
}

impl<B: MessageBroadcaster> MessageService<B> {
    pub async fn send(
        &self,
        context: &flash_core::SharedContext,
        sender_id: i64,
        request: SendMessageInput,
    ) -> flash_core::AppResult<SendMessageOutput>;
}
```

逻辑步骤：
1. 解析并校验 `conversation_id`。
2. 校验发送者是会话成员。
3. 校验 `type == 0` 且 `content.trim()` 非空。
4. 调用 `SeqGenerator::next_seq`。
5. 写入 `messages`。
6. 更新 `conversations.last_message_preview` 和 `last_message_at`。
7. 对非发送者累加 `conversation_members.unread_count`。
8. 构造 `MessageAck`、`ChatMessage`、`ConversationUpdate` 事件。
9. 调用 broadcaster 推送给在线成员。

### 13.2 实现 get_history `✅`

关键 Rust 骨架：

```rust
pub async fn get_history(
    context: &flash_core::SharedContext,
    user_id: i64,
    conversation_id: uuid::Uuid,
    query: MessageQuery,
) -> flash_core::AppResult<Vec<MessageWithSender>>;
```

逻辑步骤：
1. 校验当前用户是会话成员。
2. 规范化 `before_seq.unwrap_or(i64::MAX)`。
3. 规范化 `limit.unwrap_or(50).min(100)`。
4. 查询 `repository::find_before`。

### 13.3 构造 Protobuf 输出所需数据 `✅`

关键 Rust 骨架：

```rust
pub struct SendMessageOutput {
    pub message: MessageRow,
    pub ack: MessageAckPayload,
    pub member_ids: Vec<i64>,
    pub unread_updates: Vec<(i64, i32)>,
}
```

说明：
- `im-message` 不引用 `im_ws::proto` 类型；如需 Protobuf 类型转换，放到 `im-ws` 侧完成，避免反向依赖。

---

## 任务 14：`server/modules/im-message/src/routes.rs` — 新增历史消息 HTTP 路由 `✅ 已完成`

文件：`server/modules/im-message/src/routes.rs`

改动类型：`新建`

### 14.1 注册 GET /conversations/:id/messages `✅`

关键 Rust 骨架：

```rust
pub async fn list_messages(
    State(context): State<flash_core::SharedContext>,
    headers: HeaderMap,
    Path(conversation_id): Path<uuid::Uuid>,
    Query(query): Query<MessageQuery>,
) -> flash_core::AppResult<impl IntoResponse> {
    let user_id = flash_core::jwt::extract_user_id(context.as_ref(), &headers)?;
    let messages = crate::service::get_history(&context, user_id, conversation_id, query).await?;
    Ok(flash_core::response::utf8_json(Json(messages)))
}

pub fn router() -> Router<flash_core::SharedContext> {
    Router::new().route("/conversations/:id/messages", get(list_messages))
}
```

说明：
- 路径复用 `/conversations` 资源命名，和 v0.0.2 会话列表保持一致。

---

## 任务 15：`server/modules/im-message/src/lib.rs` — 暴露模块入口 `✅ 已完成`

文件：`server/modules/im-message/src/lib.rs`

改动类型：`新建`

### 15.1 导出模块和 router `✅`

关键 Rust 骨架：

```rust
pub mod broadcast;
pub mod models;
mod repository;
mod routes;
mod seq;
pub mod service;

use axum::Router;
use flash_core::SharedContext;

pub fn router() -> Router<SharedContext> {
    routes::router()
}
```

说明：
- `broadcast` 和 `service` 需要给 `im-ws` 使用。

---

## 任务 16：`server/Cargo.toml` — 接入 `im-message` workspace 和依赖 `✅ 已完成`

文件：`server/Cargo.toml`、`server/modules/im-ws/Cargo.toml`

改动类型：`配置修改`

### 16.1 添加 workspace member 和宿主依赖 `✅`

关键 TOML 骨架：

```toml
[workspace]
members = [
    ".",
    "modules/im-message",
]

[dependencies]
im-message = { path = "modules/im-message" }
```

### 16.2 给 im-ws 添加依赖 `✅`

关键 TOML 骨架：

```toml
[dependencies]
async-trait = "0.1.89"
im-message = { path = "../im-message" }
tokio = { version = "1.52.3", features = ["time", "sync", "macros"] }
```

说明：
- 如果 `tokio::select!` 不需要 `macros` 以外的新特性，可按实际编译结果收敛 features。

---

## 任务 17：`server/modules/im-ws/src/frame.rs` — 增加消息帧编解码 helper `✅ 已完成`

文件：`server/modules/im-ws/src/frame.rs`

改动类型：`修改`

### 17.1 增加消息帧 helper `✅`

关键 Rust 骨架：

```rust
pub fn message_ack_frame(message_id: impl Into<String>, seq: i64) -> Vec<u8>;

pub fn chat_message_frame(message: ChatMessage) -> Vec<u8>;

pub fn conversation_update_frame(update: ConversationUpdate) -> Vec<u8>;

pub fn decode_send_message_payload(
    payload: &[u8],
) -> Result<SendMessageRequest, prost::DecodeError>;
```

说明：
- 继续复用已有 `encode_frame` 和 `decode_frame`。

---

## 任务 18：`server/modules/im-ws/src/state.rs` — 新增在线用户状态 `✅ 已完成`

文件：`server/modules/im-ws/src/state.rs`

改动类型：`新建`

### 18.1 管理在线连接 `✅`

关键 Rust 骨架：

```rust
#[derive(Clone, Default)]
pub struct WsState {
    connections: Arc<RwLock<HashMap<i64, HashMap<Uuid, UnboundedSender<Vec<u8>>>>>>,
}

impl WsState {
    pub async fn register(&self, user_id: i64, connection_id: Uuid, sender: UnboundedSender<Vec<u8>>);
    pub async fn unregister(&self, user_id: i64, connection_id: Uuid);
    pub async fn send_to_user(&self, user_id: i64, frame: Vec<u8>);
}
```

说明：
- 同一个账号允许多端连接，不能只保存一个 sender。

---

## 任务 19：`server/modules/im-ws/src/broadcaster.rs` — 实现 WebSocket 广播器 `✅ 已完成`

文件：`server/modules/im-ws/src/broadcaster.rs`

改动类型：`新建`

### 19.1 实现 MessageBroadcaster `✅`

关键 Rust 骨架：

```rust
#[derive(Clone)]
pub struct WsBroadcaster {
    state: WsState,
}

#[async_trait::async_trait]
impl im_message::broadcast::MessageBroadcaster for WsBroadcaster {
    async fn broadcast_message(
        &self,
        message: &im_message::models::MessageRow,
        member_ids: &[i64],
        exclude_sender: Option<i64>,
    );

    async fn broadcast_conversation_update(
        &self,
        updates: Vec<im_message::broadcast::ConversationUpdateEvent>,
    );
}
```

说明：
- `CHAT_MESSAGE` 广播排除发送者。
- `CONVERSATION_UPDATE` 发送给双方；发送者未读数为 0，对方使用更新后的 unread_count。

---

## 任务 20：`server/modules/im-ws/src/dispatcher.rs` — 重写帧分发 `✅ 已完成`

文件：`server/modules/im-ws/src/dispatcher.rs`

改动类型：`修改`

### 20.1 扩展分发输入 `✅`

关键 Rust 骨架：

```rust
pub enum DispatchOutcome {
    Reply(Vec<u8>),
    Ignore,
    Close,
}

pub async fn dispatch_frame(
    context: &flash_core::SharedContext,
    broadcaster: WsBroadcaster,
    account_id: i64,
    frame_type: WsFrameType,
    payload: Vec<u8>,
) -> DispatchOutcome;
```

### 20.2 处理 CHAT_MESSAGE `✅`

逻辑步骤：
1. `decode_send_message_payload(payload.as_slice())`。
2. 转换为 `im_message::service::SendMessageInput`。
3. 调用 `MessageService::new(broadcaster).send(...)`。
4. 返回 `MESSAGE_ACK` 二进制帧。

说明：
- `PING` 仍返回 `PONG`。
- `PONG`、`AUTH`、`AUTH_RESULT` 认证后忽略。

---

## 任务 21：`server/modules/im-ws/src/handler.rs` — 改造认证后连接循环 `✅ 已完成`

文件：`server/modules/im-ws/src/handler.rs`

改动类型：`修改`

### 21.1 注册在线连接 `✅`

关键 Rust 骨架：

```rust
pub async fn ws_handler(
    State(context): State<SharedContext>,
    Extension(ws_state): Extension<WsState>,
    websocket: WebSocketUpgrade,
) -> AppResult<impl IntoResponse>;
```

### 21.2 使用 select 双向循环 `✅`

关键 Rust 骨架：

```rust
let (outbound_tx, outbound_rx) = tokio::sync::mpsc::unbounded_channel::<Vec<u8>>();
ws_state.register(account_id, connection_id, outbound_tx).await;

loop {
    tokio::select! {
        inbound = socket.recv() => {
            // 解帧并调用 dispatcher
        }
        outbound = outbound_rx.recv() => {
            // socket.send(Message::Binary(outbound.into())).await
        }
    }
}

ws_state.unregister(account_id, connection_id).await;
```

说明：
- 必须保证断开时清理连接，避免在线状态泄漏。

---

## 任务 22：`server/modules/im-ws/src/lib.rs` — 注册带在线状态的 `/ws/im` 路由 `✅ 已完成`

文件：`server/modules/im-ws/src/lib.rs`

改动类型：`修改`

### 22.1 新增模块导出和状态注入 `✅`

关键 Rust 骨架：

```rust
pub mod broadcaster;
pub mod state;

pub fn router() -> Router<SharedContext> {
    let ws_state = state::WsState::default();
    Router::new()
        .route("/ws/im", get(handler::ws_handler))
        .layer(axum::Extension(ws_state))
}
```

说明：
- `WsState` 由 `im-ws` 自己持有，不污染 `flash_core::AppContext`。

---

## 任务 23：`server/src/routes/mod.rs` — 注册 `im-message` HTTP 路由 `✅ 已完成`

文件：`server/src/routes/mod.rs`

改动类型：`修改`

### 23.1 merge 历史消息路由 `✅`

关键 Rust 骨架：

```rust
use im_message::router as build_im_message_router;

pub fn build_router(state: SharedContext, auth_store: SharedAuthStore) -> Router {
    let router = Router::new()
        // ...
        .merge(build_im_ws_router())
        .merge(build_im_conversation_router())
        .merge(build_im_message_router());
}
```

说明：
- 保留现有旧 demo `/conversation`，不在本任务中清理。

---

## 任务 24：`server/src/lib.rs` — 补充服务端集成测试 `✅ 已完成`

文件：`server/src/lib.rs`

改动类型：`修改`

### 24.1 验证历史消息路由注册 `✅`

关键测试骨架：

```rust
#[tokio::test]
async fn messages_route_rejects_missing_token() {
    let (_, _, app) = build_test_app();
    let response = app
        .oneshot(
            Request::builder()
                .method("GET")
                .uri("/conversations/00000000-0000-0000-0000-000000000000/messages")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}
```

### 24.2 验证帧类型编解码 `✅`

关键测试骨架：

```rust
#[test]
fn message_frame_types_round_trip() {
    let frame = im_ws::frame::message_ack_frame("message-id", 1);
    let (frame_type, _) = im_ws::frame::decode_frame(&frame).unwrap();
    assert_eq!(frame_type, WsFrameType::MessageAck);
}
```

说明：
- 当前 `server/src/lib.rs` 已有 WebSocket 认证和 PING/PONG 测试，可在相同 test module 内补充。

---

## 任务 25：`docs/features/im/core/v0.0.3/test/ws_chat_test.py` — 新增 WebSocket 全链路测试脚本 `✅ 已完成`

文件：`docs/features/im/core/v0.0.3/test/ws_chat_test.py`

改动类型：`新建`

### 25.1 测试脚本结构 `✅`

关键 Python 骨架：

```python
async def login(phone: str, password: str) -> str:
    ...

async def auth_ws(token: str):
    ...

async def send_chat_message(ws, conversation_id: str, content: str):
    ...

async def main():
    # 1. 登录朱红、橘橙
    # 2. 建立两个 /ws/im 连接
    # 3. 发送 AUTH 帧
    # 4. A 发送 CHAT_MESSAGE
    # 5. A 收到 MESSAGE_ACK
    # 6. B 收到 CHAT_MESSAGE
    # 7. 双方收到 CONVERSATION_UPDATE
    # 8. HTTP 查询历史消息验证持久化
```

说明：
- 依赖 `websockets` 和 `protobuf`。
- Python 生成的 protobuf 文件放在 `docs/features/im/core/v0.0.3/test/proto/`，该目录后续可 gitignore。

---

## 任务 26：`docs/features/im/core/v0.0.3/test/conversation_message.py` — 新增历史消息接口验证脚本 `✅ 已完成`

文件：`docs/features/im/core/v0.0.3/test/conversation_message.py`

改动类型：`新建`

### 26.1 验证历史查询和 before_seq 分页 `✅`

关键 Python 骨架：

```python
def login_as_zhuhong() -> str:
    ...

def list_conversations(token: str) -> list[dict]:
    ...

def list_messages(token: str, conversation_id: str, before_seq: int | None = None) -> list[dict]:
    ...

def main():
    # 1. 登录朱红
    # 2. 取第一条会话
    # 3. GET /conversations/:id/messages
    # 4. 使用 before_seq 再查下一页
```

说明：
- 该脚本用于补齐设计文档中“Link Test Writer 接口文档 / before_seq 分页待验证”的验收项。

---

## 最后：格式化、编译、迁移与链路验证 `✅ 已完成`

文件：`server/`、`scripts/database/`、`docs/features/im/core/v0.0.3/test/`

改动类型：`验证`

### 27.1 Rust 格式化与编译 `✅`

执行命令：

```bash
cd server && cargo fmt --check
cd server && cargo build
```

### 27.2 Rust 测试 `✅`

执行命令：

```bash
cd server && cargo test -p im-message
cd server && cargo test -p im-ws
cd server && cargo test
```

### 27.3 数据库与种子数据验证 `✅`

执行命令：

```bash
scripts/database/reset_sqlx_database.sh
scripts/database/seed_im_conversations.sh
```

### 27.4 WebSocket 和 HTTP 全链路验证 `✅`

执行命令：

```bash
python docs/features/im/core/v0.0.3/test/ws_chat_test.py
python docs/features/im/core/v0.0.3/test/conversation_message.py
```

验收结果记录：
- `cargo fmt --check`：通过
- `cargo build`：通过
- `cargo test -p im-message`：通过，4 个测试通过
- `cargo test -p im-ws`：通过，2 个测试通过
- `cargo test`：通过，13 个测试通过
- `scripts/database/reset_sqlx_database.sh`：通过，已应用 `20260708000100_im_messages.sql`
- `scripts/database/seed_im_conversations.sh`：通过，写入 53 个账号、51 个会话、102 条成员关系
- `python3 docs/features/im/core/v0.0.3/test/conversation_message.py`：通过，历史消息 HTTP 接口和 `before_seq` 分页校验通过
- `python3 docs/features/im/core/v0.0.3/test/ws_chat_test.py`：通过，双 WebSocket 认证、`MESSAGE_ACK`、对端 `CHAT_MESSAGE` 广播、双方 `CONVERSATION_UPDATE`、历史查询闭环校验通过
