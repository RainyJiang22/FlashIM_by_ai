# im-core v0.0.2 — 服务端任务清单

基于 [design.md](./design.md) 设计，拆分 `server/` 侧会话列表落库、种子数据、`im-conversation` crate 和 HTTP 路由接入步骤。目标是让登录用户通过 `GET /conversations?limit=20&offset=0` 获取真实私聊会话列表。

全局约束：
- 本清单只覆盖服务端会话管理的最小可用闭环：`conversations` / `conversation_members` 落库、种子用户与私聊会话、会话列表查询、宿主路由注册。
- 设计文档中 `POST /conversations` 与 `DELETE /conversations/:id` 章节和“本版本只做会话管理和列表查询，不提供创建接口”“会话删除暂不实现”存在范围冲突；本清单以更强的范围约束为准，不实现创建和删除接口。
- 设计文档中 `conversation_seq` 同时出现“本版本建表但不使用”和“消息收发版本创建，本版本不需要”的冲突；本清单按目标与关键设计决策预留 `conversation_seq` 表，但不在业务代码读写。
- 不实现 messages 表、消息发送/接收、在线用户表、群聊创建、置顶、免打扰、删除恢复、未读计数更新。
- `unread_count` 字段保留但本版本由种子数据或默认值提供，接口不主动计算新未读。
- 新接口必须复用现有 `flash_core::jwt::extract_user_id`、`SharedContext`、`AppResult`、`response::utf8_json`，不重复实现 JWT 校验或响应包装。
- 当前仓库已有旧 demo 路由 `GET /conversation` 和假数据文件 `server/src/routes/conversation.rs`；本版本新增真实 `GET /conversations`，不依赖旧假数据接口。
- 种子用户使用传统色名体系，手机号格式 `1380001xxxx`，默认密码 `111111`，朱红账号登录手机号为 `13800010001`。

---

## 执行顺序

1. ✅ 任务 1 — `server/migrations/20260707000100_im_conversations.sql` 新增会话表迁移（无依赖）
   - ✅ 1.1 启用 UUID 生成扩展
   - ✅ 1.2 创建 `conversations`
   - ✅ 1.3 创建 `conversation_members`
   - ✅ 1.4 创建预留 `conversation_seq`
2. ✅ 任务 2 — `scripts/database/im_seed/users.json` 新增传统色测试用户配置（依赖任务 1）
   - ✅ 2.1 定义 53 个测试用户
   - ✅ 2.2 固定手机号、昵称、默认密码约定
3. ✅ 任务 3 — `scripts/database/im_seed/conversations.json` 新增朱红私聊会话配置（依赖任务 2）
   - ✅ 3.1 定义朱红与其他 51 人的私聊关系
   - ✅ 3.2 为部分会话配置最后消息预览和时间偏移
4. ✅ 任务 4 — `scripts/database/seed_im_conversations.sh` 新增种子写入脚本（依赖任务 2、3）
   - ✅ 4.1 读取数据库环境
   - ✅ 4.2 幂等写入账号、资料、手机号凭证
   - ✅ 4.3 幂等写入私聊会话和成员记录
5. ✅ 任务 5 — `server/modules/im-conversation/Cargo.toml` 新增 crate 配置（依赖任务 1）
   - ✅ 5.1 配置 package 元信息
   - ✅ 5.2 添加业务依赖
6. ✅ 任务 6 — `server/modules/im-conversation/src/models.rs` 新增会话模型（依赖任务 5）
   - ✅ 6.1 定义数据库行结构
   - ✅ 6.2 定义接口响应结构
   - ✅ 6.3 定义分页查询结构
7. ✅ 任务 7 — `server/modules/im-conversation/src/repository.rs` 新增查询仓储（依赖任务 6）
   - ✅ 7.1 实现会话列表 SQL
   - ✅ 7.2 补充单聊对方资料字段
   - ✅ 7.3 过滤当前用户软删除会话
8. ✅ 任务 8 — `server/modules/im-conversation/src/service.rs` 新增业务服务（依赖任务 7）
   - ✅ 8.1 规范化分页参数
   - ✅ 8.2 调用仓储返回列表
9. ✅ 任务 9 — `server/modules/im-conversation/src/routes.rs` 新增 HTTP 路由处理器（依赖任务 8）
   - ✅ 9.1 从 Header 提取当前用户
   - ✅ 9.2 注册 `GET /conversations`
10. ✅ 任务 10 — `server/modules/im-conversation/src/lib.rs` 暴露模块入口（依赖任务 9）
    - ✅ 10.1 导出内部模块
    - ✅ 10.2 暴露 `router()`
11. ✅ 任务 11 — `server/Cargo.toml` 接入 `im-conversation` workspace 与依赖（依赖任务 10）
    - ✅ 11.1 添加 workspace member
    - ✅ 11.2 添加宿主依赖
12. ✅ 任务 12 — `server/src/routes/mod.rs` 注册真实会话路由（依赖任务 11）
    - ✅ 12.1 引入 `im_conversation::router`
    - ✅ 12.2 merge 新 router
    - ✅ 12.3 保留旧 `/conversation` demo 路由
13. ✅ 任务 13 — `server/modules/im-conversation/src/repository.rs` 补充单元测试或查询构造测试（依赖任务 7）
    - ✅ 13.1 覆盖分页 clamp
    - ✅ 13.2 覆盖排序 SQL 的关键约束
14. ✅ 任务 14 — `server/src/lib.rs` 或集成测试文件补充路由注册测试（依赖任务 12）
    - ✅ 14.1 验证 `/conversations` 已注册
    - ✅ 14.2 验证缺失 token 返回 401
15. ✅ 最后 — 格式化、编译、迁移与接口验证（依赖任务 1-14）
    - ✅ 15.1 `cd server && cargo fmt --check`
    - ✅ 15.2 `cd server && cargo build -p im-conversation`
    - ✅ 15.3 `cd server && cargo test -p im-conversation`
    - ✅ 15.4 `cd server && cargo test`
    - ✅ 15.5 `scripts/database/reset_sqlx_database.sh`
    - ✅ 15.6 `scripts/database/seed_im_conversations.sh`
    - ✅ 15.7 登录朱红后请求 `GET /conversations?limit=20&offset=0`

---

## 任务 1：`server/migrations/20260707000100_im_conversations.sql` — 新增会话表迁移 `✅ 已完成`

文件：`server/migrations/20260707000100_im_conversations.sql`

改动类型：`新建`

### 1.1 启用 UUID 生成扩展 `✅`

关键 SQL 骨架：

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
```

说明：
- `conversations.id` 使用 `gen_random_uuid()`。

### 1.2 创建 conversations `✅`

关键 SQL 骨架：

```sql
CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type SMALLINT NOT NULL DEFAULT 0,
    name VARCHAR(100),
    avatar VARCHAR(500),
    owner_id BIGINT REFERENCES accounts(id) ON DELETE SET NULL,
    last_message_at TIMESTAMPTZ,
    last_message_preview VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_conversations_type ON conversations(type);
CREATE INDEX idx_conversations_last_message
    ON conversations(last_message_at DESC NULLS LAST);
```

说明：
- `type=0` 表示单聊，`type=1` 仅预留群聊。
- 本版本不新增群聊创建逻辑。

### 1.3 创建 conversation_members `✅`

关键 SQL 骨架：

```sql
CREATE TABLE conversation_members (
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    unread_count INT NOT NULL DEFAULT 0,
    last_read_seq BIGINT NOT NULL DEFAULT 0,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    is_muted BOOLEAN NOT NULL DEFAULT FALSE,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (conversation_id, user_id)
);

CREATE INDEX idx_conversation_members_user
    ON conversation_members(user_id);
```

说明：
- `is_deleted` 字段仅预留，列表查询要过滤当前用户 `is_deleted = false`。

### 1.4 创建 conversation_seq `✅`

关键 SQL 骨架：

```sql
CREATE TABLE conversation_seq (
    conversation_id UUID PRIMARY KEY REFERENCES conversations(id) ON DELETE CASCADE,
    current_seq BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

说明：
- 本表只作为消息版本的序号预留；本版本业务代码不读写。

---

## 任务 2：`scripts/database/im_seed/users.json` — 新增传统色测试用户配置 `✅ 已完成`

文件：`scripts/database/im_seed/users.json`

改动类型：`新建`

### 2.1 定义 53 个测试用户 `✅`

关键 JSON 骨架：

```json
[
  { "id": 1, "phone": "13800010000", "nickname": "系统助手", "password": "111111" },
  { "id": 2, "phone": "13800010001", "nickname": "朱红", "password": "111111" },
  { "id": 3, "phone": "13800010002", "nickname": "橘橙", "password": "111111" }
]
```

说明：
- 完整列表需覆盖 id=1..53。
- id=2 是客户端验收用朱红账号。

### 2.2 固定资料字段约定 `✅`

关键字段骨架：

```json
{
  "id": 2,
  "phone": "13800010001",
  "nickname": "朱红",
  "password": "111111",
  "signature": "传统色测试账号",
  "avatar": null
}
```

说明：
- `avatar` 为空时由脚本生成 identicon URL 或复用现有账号默认头像规则。

---

## 任务 3：`scripts/database/im_seed/conversations.json` — 新增朱红私聊会话配置 `✅ 已完成`

文件：`scripts/database/im_seed/conversations.json`

改动类型：`新建`

### 3.1 定义 51 个私聊关系 `✅`

关键 JSON 骨架：

```json
[
  {
    "owner_user_id": 2,
    "peer_user_id": 3,
    "type": 0,
    "last_message_preview": "今天的接口联调先看会话列表。",
    "last_message_minutes_ago": 5
  }
]
```

说明：
- `owner_user_id=2` 固定为朱红。
- `peer_user_id` 覆盖除朱红外的 51 个账号；是否包含系统助手按设计“其他 51 人”执行。

### 3.2 配置排序样例 `✅`

关键字段骨架：

```json
{
  "last_message_preview": null,
  "last_message_minutes_ago": null,
  "unread_count_for_owner": 0,
  "unread_count_for_peer": 0
}
```

说明：
- 部分会话允许无最后消息，用于验证 `NULLS LAST` 排序。

---

## 任务 4：`scripts/database/seed_im_conversations.sh` — 新增种子写入脚本 `✅ 已完成`

文件：`scripts/database/seed_im_conversations.sh`

改动类型：`新建`

### 4.1 读取数据库环境 `✅`

关键脚本骨架：

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/sqlx_common.sh"

USERS_JSON="$SCRIPT_DIR/im_seed/users.json"
CONVERSATIONS_JSON="$SCRIPT_DIR/im_seed/conversations.json"
```

说明：
- 复用现有 `scripts/database/sqlx_common.sh` 中的数据库 URL 解析，不硬编码本机账号。

### 4.2 幂等写入账号与凭证 `✅`

关键 SQL 骨架：

```sql
INSERT INTO accounts (id, primary_identifier)
VALUES (:id, :phone)
ON CONFLICT (id) DO UPDATE
SET primary_identifier = EXCLUDED.primary_identifier,
    updated_at = NOW();

INSERT INTO user_profiles (account_id, nickname, avatar_url, signature, bio)
VALUES (:id, :nickname, :avatar_url, :signature, NULL)
ON CONFLICT (account_id) DO UPDATE
SET nickname = EXCLUDED.nickname,
    avatar_url = EXCLUDED.avatar_url,
    signature = EXCLUDED.signature,
    updated_at = NOW();
```

说明：
- 默认密码 `111111` 需要写入 `auth_credentials` 的 `password_hash`；实现时可调用已有 Rust/CLI hash 逻辑或使用仓库认可的生成方式，不能明文存库。

### 4.3 幂等写入私聊会话 `✅`

关键 SQL 骨架：

```sql
WITH existing AS (
    SELECT c.id
    FROM conversations c
    JOIN conversation_members m1 ON m1.conversation_id = c.id
    JOIN conversation_members m2 ON m2.conversation_id = c.id
    WHERE c.type = 0
      AND m1.user_id = :owner_user_id
      AND m2.user_id = :peer_user_id
    LIMIT 1
), inserted AS (
    INSERT INTO conversations (type, last_message_preview, last_message_at)
    SELECT 0, :last_message_preview, :last_message_at
    WHERE NOT EXISTS (SELECT 1 FROM existing)
    RETURNING id
)
SELECT id FROM inserted
UNION ALL
SELECT id FROM existing;
```

说明：
- 获取会话 id 后分别插入 owner 和 peer 两条 `conversation_members`。
- 同步插入 `conversation_seq(conversation_id)`，只初始化不更新。

---

## 任务 5：`server/modules/im-conversation/Cargo.toml` — 新增 crate 配置 `✅ 已完成`

文件：`server/modules/im-conversation/Cargo.toml`

改动类型：`新建`

### 5.1 配置 package 元信息 `✅`

关键配置骨架：

```toml
[package]
name = "im-conversation"
version = "0.1.0"
edition = "2024"
```

### 5.2 添加业务依赖 `✅`

关键配置骨架：

```toml
[dependencies]
axum = { version = "0.8.9" }
chrono = { version = "0.4.42", features = ["serde"] }
flash_core = { path = "../flash_core" }
serde = { version = "1.0.228", features = ["derive"] }
sqlx = { version = "0.8.6", features = ["runtime-tokio-rustls", "postgres", "macros", "chrono", "uuid"] }
uuid = { version = "1", features = ["serde", "v4"] }
```

说明：
- 版本号应尽量和 `server/Cargo.toml` 当前依赖保持一致。

---

## 任务 6：`server/modules/im-conversation/src/models.rs` — 新增会话模型 `✅ 已完成`

文件：`server/modules/im-conversation/src/models.rs`

改动类型：`新建`

### 6.1 定义数据库行结构 `✅`

关键代码骨架：

```rust
use chrono::{DateTime, Utc};
use serde::Serialize;
use uuid::Uuid;

#[derive(Debug, sqlx::FromRow)]
pub struct ConversationListRow {
    pub id: Uuid,
    pub r#type: i16,
    pub name: Option<String>,
    pub peer_user_id: Option<i64>,
    pub peer_nickname: Option<String>,
    pub peer_avatar: Option<String>,
    pub last_message_at: Option<DateTime<Utc>>,
    pub last_message_preview: Option<String>,
    pub unread_count: i32,
    pub created_at: DateTime<Utc>,
}
```

### 6.2 定义接口响应结构 `✅`

关键代码骨架：

```rust
#[derive(Debug, Serialize)]
pub struct ConversationListItem {
    pub id: Uuid,
    pub r#type: i16,
    pub name: Option<String>,
    pub peer_user_id: Option<String>,
    pub peer_nickname: Option<String>,
    pub peer_avatar: Option<String>,
    pub last_message_at: Option<DateTime<Utc>>,
    pub last_message_preview: Option<String>,
    pub unread_count: i32,
    pub created_at: DateTime<Utc>,
}
```

说明：
- `peer_user_id` 对外按设计响应为字符串，避免客户端整型精度问题。

### 6.3 定义分页查询结构 `✅`

关键代码骨架：

```rust
#[derive(Debug, serde::Deserialize)]
pub struct ConversationListQuery {
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}
```

---

## 任务 7：`server/modules/im-conversation/src/repository.rs` — 新增查询仓储 `✅ 已完成`

文件：`server/modules/im-conversation/src/repository.rs`

改动类型：`新建`

### 7.1 实现会话列表 SQL `✅`

关键函数骨架：

```rust
use flash_core::AppResult;
use sqlx::PgPool;

use crate::models::ConversationListRow;

pub async fn list_conversations_by_user(
    pool: &PgPool,
    user_id: i64,
    limit: i64,
    offset: i64,
) -> AppResult<Vec<ConversationListRow>> {
    // sqlx::query_as::<_, ConversationListRow>(...)
}
```

关键 SQL 骨架：

```sql
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
  AND me.is_deleted = FALSE
ORDER BY c.last_message_at DESC NULLS LAST, c.created_at DESC
LIMIT $2 OFFSET $3;
```

### 7.2 补充单聊对方资料字段 `✅`

说明：
- 单聊通过另一条 `conversation_members` 找到 peer。
- 群聊本版本不创建；字段保持 `Option`。

### 7.3 过滤当前用户软删除会话 `✅`

说明：
- 只判断 `me.is_deleted = false`，不影响对方成员记录。
- 不实现恢复、删除接口或置顶排序。

---

## 任务 8：`server/modules/im-conversation/src/service.rs` — 新增业务服务 `✅ 已完成`

文件：`server/modules/im-conversation/src/service.rs`

改动类型：`新建`

### 8.1 规范化分页参数 `✅`

关键代码骨架：

```rust
use flash_core::{AppError, AppResult, SharedContext};

use crate::models::{ConversationListItem, ConversationListQuery};

const DEFAULT_LIMIT: i64 = 20;
const MAX_LIMIT: i64 = 100;

pub fn normalize_pagination(query: ConversationListQuery) -> AppResult<(i64, i64)> {
    // limit 默认 20，范围 1..=100
    // offset 默认 0，不能小于 0
}
```

### 8.2 调用仓储返回列表 `✅`

关键函数骨架：

```rust
pub async fn list_conversations(
    context: &SharedContext,
    user_id: i64,
    query: ConversationListQuery,
) -> AppResult<Vec<ConversationListItem>> {
    let (limit, offset) = normalize_pagination(query)?;
    let rows = crate::repository::list_conversations_by_user(
        context.postgres.pool(),
        user_id,
        limit,
        offset,
    )
    .await?;

    // map ConversationListRow -> ConversationListItem
}
```

说明：
- `sqlx::Error` 需要映射成 `AppError::internal_server_error("failed to list conversations")` 或在 `flash_core` 增加统一转换后复用。

---

## 任务 9：`server/modules/im-conversation/src/routes.rs` — 新增 HTTP 路由处理器 `✅ 已完成`

文件：`server/modules/im-conversation/src/routes.rs`

改动类型：`新建`

### 9.1 从 Header 提取当前用户 `✅`

关键代码骨架：

```rust
use axum::{
    extract::{Query, State},
    http::HeaderMap,
    response::IntoResponse,
    Json,
};
use flash_core::{AppResult, SharedContext, jwt::extract_user_id, response::utf8_json};

use crate::models::ConversationListQuery;

pub async fn list_conversations(
    State(context): State<SharedContext>,
    headers: HeaderMap,
    Query(query): Query<ConversationListQuery>,
) -> AppResult<impl IntoResponse> {
    let user_id = extract_user_id(context.as_ref(), &headers)?;
    let conversations = crate::service::list_conversations(&context, user_id, query).await?;
    Ok(utf8_json(Json(conversations)))
}
```

### 9.2 注册 GET /conversations `✅`

关键代码骨架：

```rust
use axum::{Router, routing::get};
use flash_core::SharedContext;

pub fn router() -> Router<SharedContext> {
    Router::new().route("/conversations", get(list_conversations))
}
```

说明：
- 不注册 `POST /conversations` 或 `DELETE /conversations/:id`。

---

## 任务 10：`server/modules/im-conversation/src/lib.rs` — 暴露模块入口 `✅ 已完成`

文件：`server/modules/im-conversation/src/lib.rs`

改动类型：`新建`

### 10.1 导出内部模块 `✅`

关键代码骨架：

```rust
mod models;
mod repository;
mod routes;
mod service;
```

### 10.2 暴露 router `✅`

关键代码骨架：

```rust
use axum::Router;
use flash_core::SharedContext;

pub fn router() -> Router<SharedContext> {
    routes::router()
}
```

---

## 任务 11：`server/Cargo.toml` — 接入 im-conversation `✅ 已完成`

文件：`server/Cargo.toml`

改动类型：`配置修改`

### 11.1 添加 workspace member `✅`

关键配置骨架：

```toml
[workspace]
members = [
    ".",
    "modules/flash_core",
    "modules/flash_auth",
    "modules/flash_user",
    "modules/im-ws",
    "modules/im-conversation",
]
```

### 11.2 添加宿主依赖 `✅`

关键配置骨架：

```toml
[dependencies]
im-conversation = { path = "modules/im-conversation" }
```

说明：
- Rust import 名使用 `im_conversation`。

---

## 任务 12：`server/src/routes/mod.rs` — 注册真实会话路由 `✅ 已完成`

文件：`server/src/routes/mod.rs`

改动类型：`修改`

### 12.1 引入 im_conversation router `✅`

关键代码骨架：

```rust
use im_conversation::router as build_im_conversation_router;
```

### 12.2 merge 新 router `✅`

关键代码骨架：

```rust
let router = Router::new()
    .route("/v", get(health::version))
    .route("/conversation", get(conversation::conversations))
    .route("/ws", get(ws::websocket_handler))
    .route("/chat_room/ws", get(ws::chat_room_websocket_handler))
    .merge(build_user_router())
    .merge(build_im_ws_router())
    .merge(build_im_conversation_router());
```

### 12.3 保留旧 demo 路由 `✅`

说明：
- `GET /conversation` 仍保留给旧客户端或本地 demo。
- 新客户端应迁移到 `GET /conversations`。

---

## 任务 13：`server/modules/im-conversation/src/repository.rs` — 补充测试 `✅ 已完成`

文件：`server/modules/im-conversation/src/repository.rs`

改动类型：`修改`

### 13.1 覆盖分页 clamp `✅`

关键代码骨架：

```rust
#[cfg(test)]
mod tests {
    use crate::{models::ConversationListQuery, service::normalize_pagination};

    #[test]
    fn pagination_defaults_to_twenty() {
        let (limit, offset) = normalize_pagination(ConversationListQuery {
            limit: None,
            offset: None,
        })
        .expect("pagination should be valid");
        assert_eq!((limit, offset), (20, 0));
    }
}
```

说明：
- 如果测试放在 `service.rs` 更自然，可将本任务目标文件调整为 `server/modules/im-conversation/src/service.rs`，但任务执行时必须保留同等覆盖。

### 13.2 覆盖排序 SQL 的关键约束 `✅`

说明：
- 优先用集成测试覆盖真实排序：有 `last_message_at` 的会话排前，无消息会话排后。
- 若本地数据库测试成本过高，至少保留仓储 SQL 的集中函数，避免路由层拼接查询。

---

## 任务 14：`server/src/lib.rs` 或集成测试文件 — 补充路由注册测试 `✅ 已完成`

文件：`server/src/lib.rs` 或 `server/tests/im_conversation_routes.rs`

改动类型：`修改` / `新建`

### 14.1 验证 /conversations 已注册 `✅`

关键测试骨架：

```rust
#[tokio::test]
async fn conversations_route_requires_authentication() {
    // build_router(...)
    // GET /conversations
    // assert 401 Unauthorized
}
```

### 14.2 验证缺失 token 返回 401 `✅`

说明：
- 该测试不需要真实数据库连接；缺失 token 应在访问仓储前返回。
- 如果现有 `build_router` 测试已经有 helper，复用 helper 构造 `SharedContext` 和 `SharedAuthStore`。

---

## 最后：格式化、编译、迁移与接口验证 `✅ 已完成`

依赖：任务 1-14

### 15.1 Rust 格式化 `✅`

命令：

```bash
cd server && cargo fmt --check
```

### 15.2 新 crate 编译 `✅`

命令：

```bash
cd server && cargo build -p im-conversation
```

### 15.3 新 crate 测试 `✅`

命令：

```bash
cd server && cargo test -p im-conversation
```

### 15.4 宿主全量测试 `✅`

命令：

```bash
cd server && cargo test
```

### 15.5 迁移和种子数据验证 `✅`

命令：

```bash
scripts/database/reset_sqlx_database.sh
scripts/database/seed_im_conversations.sh
```

验收点：
- `accounts` 有 53 个传统色测试账号。
- `conversations` 有 51 条朱红私聊会话。
- 每条会话至少有 2 条 `conversation_members`。

### 15.6 HTTP 验证 `✅`

验证路径：

```bash
# 1. 登录朱红：13800010001 / 111111，取 token
# 2. 请求：
curl -H "Authorization: Bearer $TOKEN" \
  "http://127.0.0.1:8080/conversations?limit=20&offset=0"
```

验收点：
- HTTP 200。
- 返回数组长度为 20。
- 第一页包含 `peer_user_id`、`peer_nickname`、`peer_avatar`、`last_message_preview`、`unread_count`。
- 有最后消息的会话排在无最后消息的会话前。
- `offset=20` 能返回后续会话。

---

## 执行结果

状态：`✅ 已完成`

实际改动：
- 新增迁移文件：`server/migrations/20260707000100_im_conversations.sql`
- 新增种子配置：`scripts/database/im_seed/users.json`、`scripts/database/im_seed/conversations.json`
- 新增幂等种子脚本：`scripts/database/seed_im_conversations.sh`
- 新增服务端 crate：`server/modules/im-conversation`
- 接入 workspace 与宿主依赖：`server/Cargo.toml`
- 注册真实会话路由：`server/src/routes/mod.rs`
- 补充路由注册测试：`server/src/lib.rs`

实现说明：
- 原任务文件名为 `202607070001_im_conversations.sql`，实际落地为 `20260707000100_im_conversations.sql`。原因是仓库已有迁移版本号为 14 位 `20260612170000`，SQLx 按数字版本排序；12 位 `202607070001` 会被排到旧迁移之前，导致引用 `accounts` 表时报错。
- `POST /conversations`、`DELETE /conversations/:id`、消息表、消息收发、未读主动计算、置顶和免打扰均按本清单约束未实现。
- 种子脚本为朱红账号 `13800010001 / 111111` 写入密码凭证，密码以 Argon2 PHC hash 存储，不明文入库。

验证记录：
- `ruby -rjson -e 'JSON.parse(File.read("scripts/database/im_seed/users.json")); JSON.parse(File.read("scripts/database/im_seed/conversations.json")); puts "json ok"'`：通过
- `bash -n scripts/database/seed_im_conversations.sh`：通过
- `cd server && cargo fmt --check`：通过
- `cd server && cargo build -p im-conversation`：通过
- `cd server && cargo test -p im-conversation`：通过，4 个测试通过
- `cd server && cargo test`：通过，11 个测试通过
- `scripts/database/reset_sqlx_database.sh && scripts/database/seed_im_conversations.sh`：通过
- `POST http://127.0.0.1:9600/auth/login`，朱红账号 `13800010001 / 111111`：HTTP 200，`account_id=2`，`password_setup_required=false`
- `GET http://127.0.0.1:9600/conversations?limit=20&offset=0`：HTTP 200，返回 20 条，首条 peer 为橘橙，包含 peer、头像、最后消息和未读字段
- `GET http://127.0.0.1:9600/conversations?limit=20&offset=20`：HTTP 200，返回 20 条
- `GET http://127.0.0.1:9600/conversations?limit=20&offset=40`：HTTP 200，返回 11 条
- 未携带 token 请求 `GET /conversations?limit=20&offset=0`：HTTP 401
