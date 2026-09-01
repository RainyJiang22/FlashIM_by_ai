# 群治理与群信息实时同步 — 服务端任务清单

基于 [design.md](./design.md) 增量实现 `im-group` v0.0.4。

全局约束：服务端优先；保留并扩展现有 add/remove/name/dissolve 路由，不建立平行接口；治理通知必须走 type=5 持久化消息链；解散后仅原成员可读历史且始终不可发送；不恢复旧解散群；不回滚无关改动；不执行 Gradle/Xcode。

---

## 执行顺序

1. ⬜ 任务 1 — 公告数据库迁移（无依赖）
2. ⬜ 任务 2 — Protobuf 与 WS 帧（依赖任务 1）
3. ⬜ 任务 3 — 群治理 API/DB 模型（依赖任务 1）
4. ⬜ 任务 4 — 群广播领域边界（依赖任务 2、3）
5. ⬜ 任务 5 — Repository 治理事务与快照（依赖任务 3）
6. ⬜ 任务 6 — type=5 治理消息与解散原子消息（依赖任务 5）
7. ⬜ 任务 7 — Service 编排（依赖任务 4-6）
8. ⬜ 任务 8 — HTTP 路由与 WS 宿主接线（依赖任务 7）
9. ⬜ 任务 9 — 解散会话读写鉴权分流（依赖任务 5-8）
10. ⬜ 任务 10 — Rust 单元/路由/数据库测试（依赖任务 1-9）
11. ⬜ 任务 11 — API/WS 链路脚本与中文文档（依赖任务 8-10）
12. ⬜ 最后 — 服务端 Harness：测试、新鲜覆盖率 ≥80%、fmt/Clippy（依赖任务 10-11）

---

## 任务 1：公告迁移 `⬜ 待处理`

文件：`server/migrations/20260831000200_group_governance.sql`；改动类型：新建。

### 1.1 字段、外键和长度约束 `⬜`

```sql
ALTER TABLE conversations
  ADD COLUMN announcement TEXT,
  ADD COLUMN announcement_updated_at TIMESTAMPTZ,
  ADD COLUMN announcement_updated_by BIGINT REFERENCES accounts(id) ON DELETE SET NULL;
-- announcement 为 NULL 或 char_length 在 1..2000
```

## 任务 2：Protobuf 与 WS 帧 `⬜ 待处理`

文件：`proto/group.proto`、`proto/ws.proto`、`server/modules/im-ws/src/frame.rs`、`server/modules/im-ws/src/dispatcher.rs`；改动类型：修改。

### 2.1 定义并生成协议 `⬜`

```proto
GROUP_INFO_UPDATE = 11;
message GroupInfoUpdateNotification {
  string conversation_id = 1;
  // name/avatar/owner/member_count/announcement/timestamps
  // is_dissolved/membership_active/current_user_role/change_type
}
```

### 2.2 下行帧 helper 与 dispatcher 兼容 `⬜`

增加 `group_info_update_frame(...)`；客户端不允许上行 type 11，dispatcher 保持只下行分支。

## 任务 3：群治理模型 `⬜ 待处理`

文件：`server/modules/im-group/src/models.rs`；改动类型：修改。

### 3.1 扩展详情与数据库行 `⬜`

`GroupSummaryRow/GroupDetail` 增加公告三字段、更新人名称和 `is_dissolved`，ID 继续按字符串 JSON 输出。

### 3.2 请求和快照类型 `⬜`

```rust
pub struct TransferGroupOwnerBody { pub owner_id: i64 }
pub struct UpdateGroupAnnouncementBody { pub announcement: String }
pub struct GroupGovernanceSnapshot { /* detail + active/departed recipients */ }
```

## 任务 4：群广播边界 `⬜ 待处理`

文件：`server/modules/im-group/src/broadcast.rs`、`server/modules/im-ws/src/broadcaster.rs`；改动类型：修改。

### 4.1 领域 payload/trait `⬜`

```rust
pub struct GroupInfoUpdatePayload { /* 完整轻量快照 + change_type */ }
async fn broadcast_group_info_update(
    &self,
    recipients: Vec<GroupInfoRecipient>,
    event: GroupInfoUpdatePayload,
) -> AppResult<()>;
```

### 4.2 WS 收件人定制 `⬜`

WsBroadcaster 对每个 recipient 写入其 `membership_active/current_user_role` 后定向发送 type 11；Noop 实现同步扩展。

## 任务 5：Repository 治理事务 `⬜ 待处理`

文件：`server/modules/im-group/src/repository.rs`；改动类型：修改。

### 5.1 公告与详情 SQL `⬜`

所有 `GroupSummaryRow` 查询补齐公告/更新人/解散字段，详情成员仍只允许未解散活跃群。

### 5.2 退群与转让事务 `⬜`

```rust
pub async fn leave_group(...) -> AppResult<GroupMutationResult>;
pub async fn transfer_group_owner(...) -> AppResult<GroupMutationResult>;
```

锁群后校验角色与目标活跃成员；退群软删本人并刷新头像，转让只更新 `owner_id`。

### 5.3 公告、增删成员、改名返回治理快照 `⬜`

```rust
pub async fn update_group_announcement(...) -> AppResult<GroupMutationResult>;
```

现有操作保留接口语义，但返回广播与系统消息所需 actor/target/active recipients 快照。

### 5.4 解散保留成员 `⬜`

删除“软删全部成员”SQL；使解散消息写入、最后消息/未读更新、`is_dissolved=true` 和 pending 邀请失效处于同一事务。

## 任务 6：治理系统消息 `⬜ 待处理`

文件：`server/modules/im-message/src/repository.rs`、`server/modules/im-message/src/service.rs`；改动类型：修改。

### 6.1 通用 type=5 入口 `⬜`

```rust
pub async fn send_group_system_event(
    &self,
    context: &SharedContext,
    conversation_id: Uuid,
    sender_id: i64,
    content: String,
    system_event: &'static str,
) -> AppResult<SendMessageOutput>;
```

`send_group_created/member_joined` 复用此入口；未知 event 不影响消息链。

### 6.2 解散事务消息支持 `⬜`

抽取可在外部 SQLx transaction 中写 type=5 消息、seq、preview、未读并返回广播数据的受控函数；普通用户消息仍必须使用 active-conversation lock。

## 任务 7：GroupService 编排 `⬜ 待处理`

文件：`server/modules/im-group/src/service.rs`；改动类型：修改。

### 7.1 输入规范和新动作 `⬜`

实现公告 1～2000 字、转让目标校验、退群、公告、转让 service 方法。

### 7.2 扩展既有操作副作用 `⬜`

增员、审批加入、邀请接受、移除、改名和解散生成权威中文 type=5 文案；事务成功后广播 `GROUP_INFO_UPDATE`，WS 失败不反转 HTTP 成功。

### 7.3 解散广播 `⬜`

提交原子事务后向全部原成员发送最后系统消息、会话更新和 `dissolved` 群信息事件。

## 任务 8：HTTP 与 WS 接线 `⬜ 待处理`

文件：`server/modules/im-group/src/routes.rs`、`server/modules/im-ws/src/frame.rs`、`server/modules/im-ws/src/dispatcher.rs`、`server/src/routes/mod.rs`；改动类型：修改。

### 8.1 注册新路由 `⬜`

```text
POST  /groups/{id}/leave
PATCH /groups/{id}/owner
PATCH /groups/{id}/announcement
```

保留现有具体路由优先级和统一认证 extractor。

### 8.2 type 11 宿主验证 `⬜`

验证 protobuf 映射、frame type 和 WsBroadcaster 注入，不增加另一套 broadcaster 实例。

## 任务 9：解散会话读写分流 `⬜ 待处理`

文件：`server/modules/im-conversation/src/models.rs`、`repository.rs`、`service.rs`、`server/modules/im-message/src/service.rs`；改动类型：修改。

### 9.1 会话返回解散状态 `⬜`

`ConversationListRow/Item` 增加 `is_dissolved`。主列表在未传 type 时允许已解散群；type=1 列表继续过滤；按 ID 对原成员开放。

### 9.2 历史鉴权拆分 `⬜`

新增只检查成员未软删的 `can_read_history`；`get_history` 使用它。发送链继续使用 `is_dissolved=false` 锁，不扩大写权限。

## 任务 10：服务端测试 `⬜ 待处理`

文件：`server/modules/im-group/src/{models,repository,service}.rs`、`server/modules/im-message/src/{repository,service}.rs`、`server/modules/im-conversation/src/{models,repository}.rs`、`server/modules/im-ws/src/{frame,broadcaster,dispatcher}.rs`、`server/src/lib.rs`；改动类型：修改测试。

### 10.1 单元与 SQL 合同测试 `⬜`

覆盖公告边界、角色/成员校验、解散保留成员、type=1 过滤、历史可读/发送拒绝、system_event 和 type 11 映射。

### 10.2 PostgreSQL 路由 round-trip `⬜`

覆盖 owner/member 三用户：退群、转让、公告、改名、踢人、解散、并发/重复/越权、消息持久化、WS 收件人和旧 v0.0.3 回归。

## 任务 11：API/WS 链路 `⬜ 待处理`

文件：`docs/features/im/group/v0.0.4/api/group_governance/request/group_governance.py`、`docs/features/im/group/v0.0.4/api/group_governance/doc/*.md`；改动类型：新建。

### 11.1 可重复业务链 `⬜`

脚本自行登录/创建群和准备好友，顺序验证公告、改名、加人、转让、退群、踢人、解散只读与错误码；解码 type 5/type 11 WS，不依赖手工数据库状态。

### 11.2 脱敏中文文档 `⬜`

生成接口、请求响应、预期/实际结果与运行命令；不得写入 token、密码或本地数据库秘密。

## 最后：服务端 Harness Check `⬜ 待处理`

```bash
cd server && cargo fmt --check
cd server && cargo test -p im-group -p im-ws -p im-message -p im-conversation
cd server && cargo llvm-cov --workspace --lcov --output-path <fresh-attempt>/server.lcov
cd server && cargo clippy -p im-group -p im-ws -p im-message -p im-conversation --all-targets -- -D warnings
```

保存新的 attempt 输出和变更生产代码清单，changed coverage 必须不低于 80%。
