# 在线状态与已读回执 — 服务端任务清单

基于 [design.md](./design.md) 执行。保持 `im-message` 负责消息已读事实、`im-ws` 负责连接与 protobuf 传输、`im-friend` 只提供好友关系查询；不新增数据库迁移，不修改现有帧编号 0～11，不回滚工作区其他功能。

---

## 执行顺序

1. ✅ 任务 1 — 扩展共享 protobuf（无依赖）
2. ✅ 任务 2 — 增加好友 ID 查询（依赖任务 1）
3. ✅ 任务 3 — 扩展 WsState 在线语义（依赖任务 1）
4. ✅ 任务 4 — 增加在线与回执帧编码（依赖任务 1）
5. ✅ 任务 5 — 接入认证/断开在线广播（依赖任务 2～4）
6. ✅ 任务 6 — 实现已读数据库与 HTTP 模型（依赖任务 1）
7. ✅ 任务 7 — 实现已读服务、广播和 WS 分发（依赖任务 4、6）
8. ✅ 任务 8 — 暴露已读详情 HTTP 路由（依赖任务 6、7）
9. ✅ 任务 9 — 补齐 Rust 与数据库路由测试（依赖任务 2～8）
10. ✅ 任务 10 — API/WS 链路脚本与中文文档（依赖任务 9）
11. ✅ 任务 11 — Harness Check、覆盖率与静态扫描（依赖全部任务）

---

## 任务 1：共享 protobuf — 在线与已读协议 `✅ 已完成`

文件：`proto/ws.proto`、`proto/presence.proto`、`proto/message.proto`、`server/modules/im-ws/build.rs`；改动类型：新建 + 修改。

### 1.1 帧类型 `✅`

保留 0～11，新增 `USER_ONLINE=12`、`USER_OFFLINE=13`、`ONLINE_LIST=14`、`READ_RECEIPT=15`。

### 1.2 Payload `✅`

```protobuf
message UserPresenceEvent { int64 user_id = 1; }
message OnlineUserList { repeated int64 user_ids = 1; }
message ReadReceipt {
  string conversation_id = 1;
  int64 reader_id = 2;
  int64 previous_read_seq = 3;
  int64 read_seq = 4;
}
```

`ChatMessage` 新增 `int32 read_count = 12`，服务端构建脚本加入 `presence.proto`。

## 任务 2：`im-friend/repository.rs` — 好友 ID 查询 `✅ 已完成`

文件：`server/modules/im-friend/src/repository.rs`；改动类型：修改。

### 2.1 查询函数 `✅`

```rust
pub async fn list_friend_ids(pool: &PgPool, user_id: i64) -> AppResult<Vec<i64>>;
```

只读取 `friend_relations.friend_user_id`，按 ID 稳定排序。

## 任务 3：`im-ws/state.rs` — 首连、末连与在线查询 `✅ 已完成`

文件：`server/modules/im-ws/src/state.rs`；改动类型：修改。

### 3.1 注册结果 `✅`

```rust
pub struct Registration {
    pub receiver: OutboundReceiver,
    pub is_first_connection: bool,
}
```

`register` 在同一锁内判断是否为首连；`unregister` 返回是否删除了最后连接。

### 3.2 在线查询 `✅`

```rust
pub fn is_online(&self, account_id: i64) -> bool;
pub fn online_subset(&self, account_ids: &[i64]) -> Vec<i64>;
```

## 任务 4：`im-ws/frame.rs` — 新帧编码 `✅ 已完成`

文件：`server/modules/im-ws/src/frame.rs`、`server/modules/im-ws/src/proto.rs`；改动类型：修改。

### 4.1 编码函数 `✅`

增加 `user_online_frame`、`user_offline_frame`、`online_list_frame`、`read_receipt_frame`，全部复用 `encode_frame`。

## 任务 5：`im-ws/handler.rs` — 在线生命周期 `✅ 已完成`

文件：`server/modules/im-ws/src/handler.rs`；改动类型：修改。

### 5.1 认证后初始化 `✅`

注册连接后查询好友，向当前 socket 发送 `ONLINE_LIST`；首连时向在线好友发送 `USER_ONLINE`。

### 5.2 最后下线 `✅`

连接循环结束后注销；仅最后连接触发 `USER_OFFLINE`。查询或发送失败记录日志但不破坏清理。

## 任务 6：`im-message` — 已读数据库与模型 `✅ 已完成`

文件：`server/modules/im-message/src/models.rs`、`server/modules/im-message/src/repository.rs`；改动类型：修改。

### 6.1 历史 read_count `✅`

`MessageWithSenderRow/MessageWithSender` 增加 `read_count: i32`；历史 SQL 统计除发送者外当前成员的已读人数。

### 6.2 已读推进事务 `✅`

```rust
pub async fn advance_read(
    pool: &PgPool,
    conversation_id: Uuid,
    reader_id: i64,
    requested_read_seq: i64,
) -> AppResult<ReadAdvance>;
```

锁定成员、校验 current seq、单调推进并重算 unread_count。

### 6.3 已读详情查询 `✅`

定义 `ReadStatusMember`、`MessageReadStatus`，查询消息发送者与当前成员 `last_read_seq` 后分组。

## 任务 7：`im-message` 与 `im-ws` — 已读服务和 WS `✅ 已完成`

文件：`server/modules/im-message/src/broadcast.rs`、`server/modules/im-message/src/service.rs`、`server/modules/im-ws/src/broadcaster.rs`、`server/modules/im-ws/src/dispatcher.rs`；改动类型：修改。

### 7.1 领域广播 `✅`

```rust
pub struct ReadReceiptPayload { /* conversation, reader, previous, current */ }
async fn broadcast_read_receipt(&self, payload: ReadReceiptPayload, member_ids: &[i64]);
```

### 7.2 服务入口 `✅`

```rust
pub async fn mark_read(&self, context: &SharedContext, reader_id: i64, conversation_id: Uuid, read_seq: i64);
pub async fn get_read_status(&self, context: &SharedContext, requester_id: i64, conversation_id: Uuid, message_id: Uuid);
```

推进成功后广播回执，并向阅读者发送会话未读纠偏。

### 7.3 Dispatcher `✅`

解析上行 `ReadReceipt`，忽略客户端传入 reader/previous 字段，使用认证账号调用服务。

## 任务 8：`im-message/routes.rs` — 已读详情接口 `✅ 已完成`

文件：`server/modules/im-message/src/routes.rs`；改动类型：修改。

### 8.1 HTTP 路由 `✅`

注册 `GET /conversations/{conversation_id}/messages/{message_id}/read-status` 并返回 UTF-8 JSON。

## 任务 9：服务端测试 `✅ 已完成`

文件：`server/modules/im-ws/src/{state,frame,dispatcher,broadcaster}.rs`、`server/modules/im-message/src/{repository,service}.rs`、`server/src/lib.rs`；改动类型：修改。

### 9.1 单元测试 `✅`

覆盖首连/末连、多端、在线交集、帧往返、伪造 reader 被忽略、read_count SQL、回执单调性与详情权限。

### 9.2 数据库路由测试 `✅`

使用配置数据库验证已读推进、历史 read_count、详情已读/未读分组及越权拒绝；跳过必须显式报告，不能当通过。

## 任务 10：API/WS 链路 `✅ 已完成`

文件：`docs/features/im/presence/v0.0.1/api/presence_read_receipt/request/presence_read_receipt.py` 及生成文档；改动类型：新建。

### 10.1 正常链路 `✅`

两账号 WS 登录、在线列表、上线/下线、多端保持在线、发消息、上报已读、历史 read_count、详情分组。

### 10.2 异常链路 `✅`

覆盖未来 seq、非成员会话、非发送者查询详情；文档 Token 必须脱敏。

## 任务 11：服务端质量门禁 `✅ 已完成`

文件：`docs/features/im/presence/v0.0.1/quality/`；改动类型：新建报告。

### 11.1 验证命令 `✅`

```bash
cargo fmt --all -- --check
cargo test -p im-friend -p im-message -p im-ws
cargo clippy -p im-friend -p im-message -p im-ws --all-targets -- -D warnings
```

### 11.2 Harness `✅`

运行新 attempt 的服务端测试、fresh changed-production coverage（阈值 80%）与静态扫描，并记录报告路径。
