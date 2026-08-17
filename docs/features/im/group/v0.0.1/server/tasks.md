# 群聊 v0.0.1 — 服务端任务清单

基于 [design.md](./design.md) 设计，优先完成群会话创建、类型筛选、响应扩展、服务端测试和 API 链路验证；服务端门禁完成后才进入客户端编码。

全局约束：

- 复用现有 `conversations`、`conversation_members`、`friend_relations`，不新增数据库迁移和 `group_info`。
- 只扩展 `im-conversation`；不修改 `im-message`、`im-ws`、protobuf 和消息生产代码。
- 群创建只允许当前用户的有效好友，邀请人数 2～199，总人数最多 200；写入必须使用 SQLx 事务。
- 新字段保持旧客户端兼容：可空字段用 null，列表字段用空数组。
- 不执行 Gradle/Android 或 Xcode/iOS 构建；服务端使用 Rust 定向检查、测试和新鲜覆盖率。
- 参考现有文件：`server/modules/im-conversation/src/*`、`server/modules/im-friend/src/repository.rs`、`server/modules/im-message/src/service.rs`。

---

## 执行顺序

1. ✅ 任务 1 — 扩展会话模型与请求契约（无依赖）
2. ✅ 任务 2 — 扩展列表/详情查询并实现群创建事务（依赖任务 1）
3. ✅ 任务 3 — 实现输入校验、类型筛选和群创建编排（依赖任务 2）
4. ✅ 任务 4 — 注册 `POST /conversations`（依赖任务 3）
5. ✅ 任务 5 — 增加服务端路由与消息复用回归测试（依赖任务 4）
6. ✅ 任务 6 — 生成并执行群聊 API 链路测试和中文接口文档（依赖任务 4、5）
7. ✅ 最后 — 服务端 Harness Check：格式、测试、新鲜覆盖率 ≥80%、静态扫描（依赖任务 1-6）

---

## 任务 1：`models.rs` — 扩展会话 DTO `✅ 已完成`

文件：`server/modules/im-conversation/src/models.rs`

改动类型：`修改文件`

### 1.1 扩展数据库行与响应 `✅`

```rust
pub struct ConversationListRow {
    pub avatar: Option<String>,
    pub owner_id: Option<i64>,
    pub member_avatars: Vec<String>,
    // 保留现有字段
}

pub struct ConversationListItem {
    pub avatar: Option<String>,
    pub owner_id: Option<String>,
    pub member_avatars: Vec<String>,
    // 保留现有字段
}
```

### 1.2 扩展查询和创建请求 `✅`

```rust
#[derive(Debug, Deserialize)]
pub struct ConversationListQuery {
    pub limit: Option<i64>,
    pub offset: Option<i64>,
    pub r#type: Option<i16>,
}

#[derive(Debug, Deserialize)]
pub struct CreateConversationBody {
    pub r#type: String,
    pub name: String,
    pub member_ids: Vec<i64>,
}
```

## 任务 2：`repository.rs` — 群查询与创建事务 `✅ 已完成`

文件：`server/modules/im-conversation/src/repository.rs`

改动类型：`修改文件`

### 2.1 扩展列表与详情 SQL `✅`

- SELECT 增加 `c.avatar`、`c.owner_id`。
- 对群聊用 LATERAL 子查询聚合最多 4 个有效成员的 `user_profiles.avatar_url`。
- 列表 WHERE 增加可选 `$4::SMALLINT` 类型过滤；详情保持成员权限校验。

### 2.2 实现群创建事务 `✅`

```rust
pub async fn create_group_conversation(
    pool: &PgPool,
    owner_id: i64,
    name: &str,
    member_ids: &[i64],
) -> AppResult<Uuid>;
```

逻辑顺序：`BEGIN` → 查询 `friend_relations` 覆盖数量 → 插入 `conversations(type=1)` → 批量插入 owner + members → `COMMIT`。好友校验不通过时返回 400 且不写数据。

### 2.3 更新仓储单元测试 `✅`

- 断言列表 SQL 包含 type 过滤、owner 和成员头像。
- 断言详情 SQL与列表返回形状一致。
- 断言群创建 SQL保留好友关系校验、事务和 type=1 约束。

## 任务 3：`service.rs` — 群创建业务规则 `✅ 已完成`

文件：`server/modules/im-conversation/src/service.rs`

改动类型：`修改文件`

### 3.1 扩展列表查询校验 `✅`

```rust
pub fn normalize_list_query(
    query: ConversationListQuery,
) -> AppResult<(i64, i64, Option<i16>)>;
```

只允许 `type` 为 0、1 或空，分页规则保持不变。

### 3.2 定义并校验群创建输入 `✅`

```rust
pub struct CreateGroupInput {
    pub name: String,
    pub member_ids: Vec<i64>,
}

pub fn normalize_group_input(
    owner_id: i64,
    body: CreateConversationBody,
) -> AppResult<CreateGroupInput>;
```

校验 group 类型、trim 后群名 1～100 字、成员数量、本人 ID、重复 ID；失败统一返回稳定的 400 错误。

### 3.3 编排创建并返回会话详情 `✅`

```rust
pub async fn create_conversation(
    context: &SharedContext,
    owner_id: i64,
    body: CreateConversationBody,
) -> AppResult<ConversationListItem>;
```

调用仓储事务创建后，以 owner 视角查询详情并返回。

### 3.4 增加 service 单元测试 `✅`

覆盖默认分页、type=0/1、非法 type、群名边界、2/199 人边界、本人 ID、重复成员和错误 type。

## 任务 4：`routes.rs` — 注册群创建接口 `✅ 已完成`

文件：`server/modules/im-conversation/src/routes.rs`

改动类型：`修改文件`

### 4.1 新增创建 handler `✅`

```rust
pub async fn create_conversation(
    State(context): State<SharedContext>,
    headers: HeaderMap,
    Json(body): Json<CreateConversationBody>,
) -> AppResult<impl IntoResponse>;
```

提取登录用户 ID，调用 service，使用 `utf8_json` 返回会话对象。

### 4.2 在同一路径合并 GET/POST `✅`

```rust
.route("/conversations", get(list_conversations).post(create_conversation))
```

## 任务 5：`server/src/lib.rs` — 路由和消息复用回归 `✅ 已完成`

文件：`server/src/lib.rs`

改动类型：`修改测试`

### 5.1 创建接口鉴权测试 `✅`

未带 token 调用 `POST /conversations` 必须返回 401，证明新路由已注册并沿用认证。

### 5.2 群消息复用证据 `✅`

服务端生产代码不修改消息模块；在 API 链路中创建三用户群后，通过现有 WS `SendMessageRequest` 验证另一成员收到 `ChatMessage`，发送者收到 ACK，历史接口能查询消息。

### 5.3 可选真实数据库路由/服务集成测试 `✅`

当运行环境提供 `DATABASE_URL`、`JWT_SECRET` 时，`server/src/lib.rs` 通过 Axum Router，`im-conversation` 自身通过 service/repository 覆盖创建、类型筛选、详情和非好友拒绝；普通无数据库单测环境自动跳过这些用例。

## 任务 6：API 链路与接口文档 `✅ 已完成`

文件由 `feature-link-test-writer` 阶段确定，实际位于：

- `docs/features/im/group/v0.0.1/api/group/request/group.py`：Python 测试链。
- `docs/features/im/group/v0.0.1/api/group/doc/`：自动生成的中文接口与链路文档。

改动类型：`新建文件`

### 6.1 正常链路 `✅`

登录 3 个测试用户 → 建立好友关系 → 创建群聊 → 三方查询群列表/详情 → 通过现有 WS 发送和接收消息 → 查询历史。

### 6.2 错误链路 `✅`

覆盖未认证、成员不足、重复成员、包含自己、非好友成员、非法 type 查询和非成员详情访问。

## 最后：服务端 Harness Check `✅ 已完成`

验证文件：服务端本次变更清单与新鲜报告目录。

### 7.1 格式、测试、覆盖率与静态扫描 `✅`

```bash
cd server && cargo fmt --check
cd server && cargo test -p im-conversation
cd server && cargo test
cd server && cargo llvm-cov --workspace --lcov --output-path <attempt>/server.lcov
cd server && cargo clippy --workspace --all-targets -- -D warnings
```

若环境没有 `cargo-llvm-cov`，必须记录原始错误并按质量门禁处理，不能复用旧覆盖率。

### 7.2 Harness 报告 `✅`

- 记录 attempt id、变更生产文件、测试命令、覆盖率与 clippy 输出路径。
- 覆盖率按本次变更生产代码范围计算，阈值不得低于 80%。

结果：

- `server-attempt-1`：crate 基线 37.72%（304/806），低于阈值，回退补真实数据库测试。
- `server-attempt-2`：外部 instrumented 服务被中断后未新增可合并 coverage，仍为 37.72%。
- `server-attempt-3`：`--dep-coverage` 对 workspace 内部 crate 导出为空，判定无效报告。
- `server-attempt-4`：crate 整体 60.90%（567/931）；本次变更生产代码 96.55%（364/377），通过 80% 门禁。
- `server-attempt-5`：创建详情查询纳入同一事务后重新验证；本次变更生产代码 94.04%（363/386），通过 80% 门禁。
- `cargo fmt --check`：通过。
- `cargo test -p im-conversation`：14/14 通过；提供真实环境变量时数据库 round-trip 也通过。
- `cargo test -p falsh-im group_conversation_routes_round_trip_against_configured_database`：1/1 通过。
- `cargo clippy -p im-conversation --all-targets -- -D warnings`：通过。
- workspace Clippy 的既有 `app-storage` 测试/函数 lint 失败已记录，不属于本次变更生产代码，未越界修改。
