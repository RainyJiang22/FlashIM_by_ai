# 综合搜索 — 服务端任务清单

基于 [design.md](design.md) 设计执行。保持 `routes -> service -> repository`，先后端再客户端；不新增业务表，不搜索陌生人、未加入群或系统消息；不执行 Gradle/Xcode 构建。

---

## 执行顺序

1. ✅ 任务 1 — 新增搜索索引迁移（无依赖）
2. ✅ 任务 2 — 好友搜索接口（依赖任务 1）
3. ✅ 任务 3 — 已加入群搜索接口（依赖任务 1）
4. ✅ 任务 4 — 跨会话与会话内消息搜索接口（依赖任务 1、3）
5. ✅ 任务 5 — 服务端路由/数据库测试（依赖任务 2–4）
6. ✅ 任务 6 — API 链路脚本与中文接口文档（依赖任务 5）
7. ⬜ 任务 7 — Harness Check、覆盖率和静态扫描（依赖任务 1–6）

---

## 任务 1：搜索索引迁移 `✅ 已完成`

文件：`server/migrations/20260904000100_search_indexes.sql`（新建）

### 1.1 启用并建立索引 `✅`

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX ... user_profiles ... nickname gin_trgm_ops;
CREATE INDEX ... conversations ... name gin_trgm_ops;
CREATE INDEX ... messages ... content gin_trgm_ops WHERE type <> 5;
```

## 任务 2：好友搜索接口 `✅ 已完成`

文件：`server/modules/im-friend/src/models.rs`、`repository.rs`、`service.rs`、`routes.rs`（修改，领域内紧耦合）

### 2.1 查询模型与路由 `✅`

```rust
pub struct FriendSearchQuery { pub q: String, pub limit: Option<i64> }
// GET /api/friends/search
```

### 2.2 权限 SQL 与服务校验 `✅`

按 `friend_relations.user_id = $1` 限定好友，关键词匹配昵称或完整 Flash ID；长度 1–100，limit 默认 20、最大 50。新增 normalizer 与 SQL 单测。

## 任务 3：已加入群搜索接口 `✅ 已完成`

文件：`server/modules/im-conversation/src/models.rs`、`repository.rs`、`service.rs`、`routes.rs`（修改，领域内紧耦合）

### 3.1 查询模型与路由 `✅`

```rust
pub struct JoinedGroupSearchQuery { pub q: String, pub limit: Option<i64> }
// GET /api/conversations/search-joined-groups
```

### 3.2 复用会话投影 `✅`

返回 `Vec<ConversationListItem>`；SQL 限定当前有效成员、群类型和未解散状态，保留群头像/成员数投影。新增 normalizer 与 SQL 单测。

## 任务 4：消息搜索接口 `✅ 已完成`

文件：`server/modules/im-message/src/models.rs`、`repository.rs`、`service.rs`、`routes.rs`（修改，领域内紧耦合）

### 4.1 定义查询与响应 `✅`

```rust
pub struct GlobalMessageSearchQuery {
    pub q: String,
    pub group_limit: Option<i64>,
    pub message_limit: Option<i64>,
}
pub struct ConversationMessageSearchQuery { pub q: String, pub limit: Option<i64> }
pub struct MessageSearchGroup {
    pub conversation: ConversationListItem,
    pub match_count: i64,
    pub messages: Vec<MessageWithSender>,
}
```

### 4.2 实现受权限约束的 SQL `✅`

跨会话查询用窗口函数限制会话数和每会话消息数；单会话查询先验证有效成员。两者均排除 `type = 5`，转义 `%`、`_`、`\\` 并绑定参数。

### 4.3 增加路由 `✅`

```text
GET /api/messages/search
GET /conversations/{id}/messages/search
```

新增参数校验、聚合和 SQL 单测。

## 任务 5：服务端路由/数据库测试 `✅ 已完成`

文件：`server/src/lib.rs`（修改）

### 5.1 鉴权回归 `✅`

四个接口缺少 token 均返回 `401`。

### 5.2 PostgreSQL 路由链路 `✅`

建立好友、群聊、普通消息和系统消息夹具，验证范围过滤、分组、系统消息排除、非法关键词与无权会话 `404`。测试名：`search_routes_round_trip_against_configured_database`。

## 任务 6：API 链路脚本与文档 `✅ 已完成`

文件：

- `docs/features/im/search/v0.0.1/api/search/request/search.py`（新建）
- `docs/features/im/search/v0.0.1/api/search/doc/00_link.md` 及逐接口文档（新建）

### 6.1 生成并执行真实接口测试链 `✅`

覆盖登录、好友范围、已加入群范围、跨会话分组、会话内搜索、系统消息排除、空关键词、无权访问；记录命令与结果，API 链结果不计覆盖率。

执行记录（2026-09-04）：

```bash
python3 docs/features/im/search/v0.0.1/api/search/request/search.py
```

结果：6/6 PASS；同时通过已加载 `server/.env` 的 `search_routes_round_trip_against_configured_database`（1 passed），确认不是跳过的数据库用例。

## 任务 7：服务端质量门禁 `⬜ 待处理`

文件：`docs/features/im/search/v0.0.1/quality/`（新建报告）

### 7.1 Harness Check `⬜`

```bash
cd server && cargo test --workspace
cd server && cargo llvm-cov --workspace --lcov --output-path <fresh-lcov>
cd server && cargo clippy --workspace --all-targets -- -D warnings
cd server && cargo fmt --all -- --check
python3 <feature-quality-gate>/scripts/harness_check.py ...
```

使用新 attempt id；变更生产代码覆盖率必须 `>= 80%`。完成测试 Agent、架构 Agent 和最终 Harness Check 后才标记任务完成。
