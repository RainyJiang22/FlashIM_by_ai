x# 群聊 v0.0.2 架构 Agent 验收报告（attempt 2）

## 结论

**PASS**

attempt 1 的四个 P1 均已按最小闭环修复，客户端 `dynamic` 类型擦除也已移除。最新客户端 Harness `harness-check-client-attempt-3.json` 为 `PASS`，变更范围覆盖率 `81.92%`，全部 Flutter test/analyze 命令通过；最新服务端 Harness `harness-check-server-attempt-4.json` 为 `PASS`，变更范围覆盖率 `84.05%`，Rust test、fmt、Clippy 全部通过。

## P1 复验

### 1. 外部 WS type=4 邀请卡片伪造：PASS

- 外部 WS dispatcher 在解析请求后先调用 `validate_client_message_type`，只允许 0～3，type 4 和负数均返回 `unsupported client message type`（`server/modules/im-ws/src/dispatcher.rs:40-77`）。
- 单元测试明确覆盖普通客户端不能发送 type 4（`server/modules/im-ws/src/dispatcher.rs:89-110`）。
- type 4 仍可由 `im-group` 的内部服务调用 `MessageService` 生成，因此没有破坏真实邀请卡片链路（`server/modules/im-group/src/service.rs:156-180`）。

结论：外部信任边界已封闭，只有服务端群领域编排能够产生邀请卡片。

### 2. 数据已提交后广播失败被返回成业务失败：PASS

- `MessageService` 先通过 Repository 完成原子持久化，随后广播使用 best-effort，不再用广播结果改变发送成功语义（`server/modules/im-message/src/service.rs:110-155`）。
- 群直接加人提交后，新成员通知同样不再向上转成业务失败（`server/modules/im-group/src/service.rs:93-110`）。
- 接受邀请提交并加载会话后，通知失败也不覆盖已成功的接受结果（`server/modules/im-group/src/service.rs:209-224`）。
- 数据库集成测试使用 `FailingBroadcaster` 证明广播失败时已提交消息仍返回成功（`server/src/lib.rs:415-431`）。

结论：客户端不会再收到“数据库已成功、接口却失败”的假失败，也不会因重试进入已存在冲突。

### 3. 邀请、消息与广播一致性：PASS

- 多个 invitee 先在同一事务内完成群锁、整批好友校验、整批成员冲突校验、人数上限校验和 invitation 创建；任一输入无效时整批不提交（`server/modules/im-group/src/repository.rs:308-373`）。
- Service 仅为新 invitation 创建私聊并发送卡片；消息持久化失败时删除对应未投递 invitation，并在响应中标记 `delivered=false`（`server/modules/im-group/src/service.rs:148-206`）。
- 消息、seq、会话预览和未读数现已在一个事务内提交；广播位于事务之后且不触发 invitation 删除，因此不会再出现“卡片已持久化但 invitation 因广播失败被删”的无效卡片（`server/modules/im-message/src/repository.rs:27-136`、`server/modules/im-message/src/service.rs:110-155`）。
- 客户端 Repository 检查所有响应项的 `delivered`；存在部分失败时抛出稳定领域错误，Cubit 映射为明确中文反馈（`client/modules/flash_im_group/lib/src/data/group_repository.dart:87-100`、`client/modules/flash_im_group/lib/src/logic/group_detail_cubit.dart:149-160`）。
- 数据库测试证明含非法成员的批量邀请不会留下前半批 pending 记录，并证明正常邀请存在唯一持久化卡片（`server/src/lib.rs:481-530`）。

结论：输入校验具备整批原子性，消息持久化与广播结果已分离，部分投递失败也能沿 API → Repository → Cubit 显式反馈。

### 4. 软解散与消息发送 TOCTOU：PASS

- 消息写入从“先查成员、后独立插入”改为单事务：先对 active conversation 和 active sender 执行 `FOR UPDATE OF c`，再生成 seq、写消息、更新预览/未读并提交（`server/modules/im-message/src/repository.rs:13-136`）。
- 解散同样先通过 `lock_group_for_actor` 获取 conversation 行锁，再标记 dissolved、软删除成员和失效 pending invitation（`server/modules/im-group/src/repository.rs:121-146,500-535`）。
- 两条写链对同一 conversation 使用一致的行锁顺序：发送先获得锁时会在解散前完整提交；解散先获得锁时，发送重新判断 active 条件后返回 conversation not found，不再可能在 dissolved 提交后插入新消息。
- SQL 测试锁定 active member、`is_dissolved=false` 与 `FOR UPDATE OF c` 三个必要条件（`server/modules/im-message/src/repository.rs:198-226`）。

结论：软解散状态与消息写入建立了数据库级串行化边界。

## 客户端强类型复验

- `GroupDetailCubit._save` 已从 `Future<dynamic> Function()` 改为 `Future<GroupDetail> Function()`，并显式导入领域模型（`client/modules/flash_im_group/lib/src/logic/group_detail_cubit.dart:1-5,116-146`）。

结论：Repository → Cubit 的结果类型不再被擦除。

## 依赖与边界回归

- Flutter 仍保持 Page → Cubit → `GroupRepository` → Dio 实现，宿主负责 DI；`flash_im_chat` 通过 callback 接受邀请，没有新增对 `flash_im_group` 的反向依赖。
- Rust 仍保持 Route → `GroupService` → Repository；`im-group` 单向依赖 `im-conversation`、`im-message`，外部 WS 入口只消费消息服务的用户消息能力。
- 群解散后的列表、详情、成员校验和消息写入均以 `is_dissolved=false`/active member 为数据库事实源，客户端退出页面和刷新首页只是展示同步，不承担权限保护。

## 不阻塞的后续建议

- P2：当前广播失败通过 `let _ = ...` 丢弃，不会再破坏业务成功语义，但缺少日志、指标与重试（`server/modules/im-message/src/service.rs:138-145`、`server/modules/im-group/src/service.rs:108,221-223`）。建议加入结构化告警，后续使用 outbox 补偿在线推送。
- P2：invitation 事务提交与邀请卡片事务之间仍存在极短的进程崩溃窗口；本版已修复正常错误路径和广播错误路径，若要求进程崩溃级 exactly-once，应将 invitation-card 事件写入事务 outbox，并让重复 pending invitation 检查实际投递状态后补发。
- P2：type 4 虽已从外部 WS 禁止，但 `MessageService::send` 的内部 API 仍以裸 `i16` 区分消息类型。后续可提供受限的 `send_group_invitation` 强类型入口，进一步减少其他服务误用。

## 最终判定

当前实现满足本次 Spec 的分层、权限、消息兼容、邀请反馈、软解散一致性、DI、生命周期和公共 API 要求；上述剩余项属于生产可观测性与更高等级投递保证，不阻塞本次功能门禁。
