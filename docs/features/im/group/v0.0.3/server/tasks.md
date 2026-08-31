# 搜索加群与入群审批 — 服务端任务清单

基于 [design.md](./design.md) 实现 `im-group` v0.0.3。

全局约束：后端优先；复用 `conversations.join_approval_required`、成员软恢复、宫格头像和 type=5 持久化系统消息；不新增群公开字段；不回滚无关改动；不执行 Gradle/Xcode。

## 执行顺序

1. ✅ 任务 1 — 数据库迁移（无依赖）
2. ✅ 任务 2 — Protobuf 与 WS 帧（依赖任务 1）
3. ✅ 任务 3 — 群广播边界（依赖任务 2）
4. ✅ 任务 4 — 服务端模型（依赖任务 1）
5. ✅ 任务 5 — Repository 搜索/申请/审批事务（依赖任务 4）
6. ✅ 任务 6 — Service 规则、系统消息与广播（依赖任务 3、5）
7. ✅ 任务 7 — HTTP 路由与宿主接线（依赖任务 6）
8. ✅ 任务 8 — Rust 单元/路由/数据库测试（依赖任务 1-7）
9. ✅ 任务 9 — API 链路脚本与中文文档（依赖任务 7）
10. 🟨 最后 — Harness Check：测试、新鲜覆盖率 ≥80%、fmt/Clippy（依赖任务 8-9；执行中被用户叫停）

## 任务 1：入群申请迁移 `✅ 已完成`

文件：`server/migrations/20260831000100_group_join_requests.sql`；改动类型：新建。

### 1.1 表、约束与索引 `✅`

创建 `group_join_requests(id, conversation_id, applicant_id, message, status, created_at, handled_at)`；增加 status check、owner 查询索引、applicant 查询索引和 pending 部分唯一索引。

## 任务 2：Protobuf 与 WS 帧 `✅ 已完成`

文件：`proto/group.proto`、`proto/ws.proto`、`server/modules/im-ws/build.rs`、`server/modules/im-ws/src/frame.rs`、`server/modules/im-ws/src/dispatcher.rs`；改动类型：新建 + 修改。

### 2.1 定义 payload 和帧号 `✅`

```proto
GROUP_JOIN_REQUEST = 10;
message GroupJoinRequestNotification { /* request/group/applicant/status/timestamps */ }
```

### 2.2 服务端生成与帧编解码 `✅`

把 `group.proto` 加入 build.rs，增加 frame helper，并把服务端只下行帧加入 dispatcher ignore 分支。

## 任务 3：群广播边界 `✅ 已完成`

文件：`server/modules/im-group/src/broadcast.rs`、`server/modules/im-group/src/lib.rs`、`server/modules/im-group/Cargo.toml`、`server/modules/im-ws/Cargo.toml`、`server/modules/im-ws/src/broadcaster.rs`；改动类型：新建 + 修改。

### 3.1 领域 trait `✅`

```rust
#[async_trait]
pub trait GroupBroadcaster {
    async fn broadcast_group_join_request(&self, to_user_id: i64, event: GroupJoinRequestPayload) -> AppResult<()>;
}
```

Noop 同时实现 GroupBroadcaster 和 MessageBroadcaster；WsBroadcaster 映射为 protobuf 后定向发送。

## 任务 4：API 与 DB 模型 `✅ 已完成`

文件：`server/modules/im-group/src/models.rs`；改动类型：修改。

### 4.1 搜索、加入、列表和审批模型 `✅`

增加 `GroupSearchQuery/Item/Response`、`JoinGroupBody/Response`、`GroupJoinRequestRow/Item/ListResponse`、`HandleJoinRequestBody`，所有 ID 按既有 JSON 规范序列化。

## 任务 5：Repository `✅ 已完成`

文件：`server/modules/im-group/src/repository.rs`；改动类型：修改。

### 5.1 搜索与列表查询 `✅`

参数化 SQL 过滤 active group，完整 UUID 精确匹配，否则 name ILIKE；聚合 member_count/is_member/pending。列表仅返回当前 owner 的群申请。

### 5.2 直接加入或创建申请事务 `✅`

```rust
pub async fn join_or_request(...) -> AppResult<JoinDecision>;
```

锁群，校验非成员和人数；按 setting upsert 成员或插入 pending；直接加入刷新头像。

### 5.3 审批事务 `✅`

```rust
pub async fn handle_join_request(...) -> AppResult<HandledJoinRequest>;
```

锁群与 request；校验 owner/status/所属群；approved 时检查上限、恢复成员、刷新头像；更新 handled_at。

## 任务 6：Service 编排 `✅ 已完成`

文件：`server/modules/im-group/src/service.rs`、`server/modules/im-message/src/service.rs`；改动类型：修改。

### 6.1 输入规范与返回对象 `✅`

关键词 1～100 字，留言默认值/200 字边界；direct join 返回 ConversationListItem。

### 6.2 系统消息与 WS `✅`

MessageService 增加成员加入系统消息方法；pending 提交后通知 owner，handled 提交后通知 applicant。通知失败不反转成功事务。

## 任务 7：路由与接线 `✅ 已完成`

文件：`server/modules/im-group/src/routes.rs`、`server/src/routes/mod.rs`；改动类型：修改。

### 7.1 注册接口 `✅`

注册 GET search/list、POST join/handle；router 泛型同时约束 `GroupBroadcaster + MessageBroadcaster`，宿主继续注入同一个 WsBroadcaster。

## 任务 8：服务端测试 `✅ 已完成`

文件：`server/modules/im-group/src/{models,repository,service}.rs`、`server/modules/im-ws/src/{frame,broadcaster,dispatcher}.rs`、`server/src/lib.rs`；改动类型：修改测试。

### 8.1 单元与 SQL 合同测试 `✅`

覆盖关键词/留言边界、状态映射、active/search/owner SQL、pending unique、权限和 200 人上限。

### 8.2 路由 PostgreSQL round-trip `✅`

覆盖搜索四态、直接加入、创建申请、重复申请、非 owner、同意/拒绝、已处理、已解散、头像刷新、系统消息和 WS payload。

## 任务 9：API 链路与文档 `✅ 已完成`

文件：`docs/features/im/group/v0.0.3/api/group_join/request/group_join.py` 与 `doc/`；改动类型：新建。

### 9.1 正常和错误业务链 `✅`

登录多用户，创建/选择两个群并切换 setting，串联搜索、直接加入、申请、列表、审批、重复/越权/已处理错误；生成脱敏中文文档。

## 最后：服务端 Harness Check `🟨 未完成（执行中被用户叫停）`

```bash
cd server && cargo fmt --check
cd server && cargo test -p im-group -p im-ws -p im-message
cd server && cargo llvm-cov --workspace --lcov --output-path <attempt>/server.lcov
cd server && cargo clippy -p im-group -p im-ws -p im-message --all-targets -- -D warnings
```

保存新 attempt 的命令输出、变更生产代码清单和 changed coverage，要求不低于 80%。

## 验证记录

- ✅ `cargo test -p im-group -p im-ws -p im-message`：共 20 项通过。
- ✅ `group_join_routes_round_trip_against_configured_database`：真实 PostgreSQL 路由 round-trip 通过。
- ✅ `api/group_join/request/group_join.py`：HTTP + WS 业务链 15/15 通过，并生成脱敏中文文档。
- 🟨 Harness attempt-01 已启动但被用户叫停，未形成可用于放行的新鲜覆盖率、fmt 与 Clippy 完整结论。
