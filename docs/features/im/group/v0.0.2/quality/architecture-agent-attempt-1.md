# 群聊 v0.0.2 架构 Agent 验收报告（attempt 1）

## 结论

**FAIL**

客户端 Harness 为 `PASS`，变更范围覆盖率 `81.94%`；服务端 Harness 为 `PASS`，变更范围覆盖率 `90.97%`，格式与 Clippy 均通过。静态门禁证明当前代码可分析、可测试，但以下邀请可信边界与事务后副作用问题会产生真实业务不一致，需修复后重新执行 Harness 和双 Agent 验收。

## 已识别架构

- Flutter：宿主 `FlashImApp` 统一创建并注入 `GroupRepository`（`client/lib/app/flash_im_app.dart:286-315`）；群详情遵循 Page → Cubit → Repository 接口 → Dio 实现，`flash_im_chat` 仅通过 callback 上抛邀请接受，不反向依赖 `flash_im_group`（`client/modules/flash_im_chat/lib/src/view/chat_page.dart:20-63`、`client/lib/app/app_router.dart:172-202`）。该依赖方向 **PASS**。
- Rust：宿主合并路由，`im-group` 依赖 `im-conversation`、`im-message`，后两者不反向依赖 `im-group`（`server/modules/im-group/Cargo.toml:7-16`、`server/src/routes/mod.rs:29-33`）。Route → Service → Repository 的主方向 **PASS**。
- 首页菜单由 `List<MessageQuickAction>` 生成，入口与菜单容器解耦，后续追加 action 无需改弹层结构（`client/lib/features/messages/presentation/widgets/message_quick_actions_menu.dart:4-21,41-75`）。可扩展性 **PASS**。
- 群详情路由以明确的 `GroupDetailsResult` 回传 updated/dissolved，群聊页只热更新展示会话，不重建 `ChatCubit`；解散结果由宿主关闭聊天并刷新列表（`client/modules/flash_im_group/lib/src/data/group_detail.dart:96-112`、`client/modules/flash_im_chat/lib/src/view/chat_page.dart:87-143`、`client/lib/app/app_router.dart:172-185`、`client/lib/features/home/presentation/main_shell_page.dart:120-131`）。生命周期与 DI 主链 **PASS**。

## 阻塞问题

### 1. P1：外部 WS 消息入口可以伪造“群邀请卡片”

证据：

- WS dispatcher 将认证用户提交的任意 `request.type` 原样传给消息服务（`server/modules/im-ws/src/dispatcher.rs:40-63`）。
- `MessageService::send` 已允许 `msg_type=4`，但只检查 extra 字段存在，不校验 invitation 是否存在、发送者是否为 inviter、接收私聊对象是否为 invitee（`server/modules/im-message/src/service.rs:93-109,257-279`）。
- 客户端把所有收到的 type 4 直接渲染成带“同意加入”的可信卡片（`client/modules/flash_im_chat/lib/src/view/bubble/message_bubble.dart:45-67`）。接受接口仍会做最终权限校验，因此不构成直接越权入群，但攻击者可以制造看似真实的邀请卡片和群名/邀请人文案，破坏卡片可信边界。

最小修复建议：外部 `CHAT_MESSAGE` 入口仅允许用户发送 0～3；type 4 改为 `im-group` 内部专用发送能力。若必须共用 `MessageService`，增加不可由外部调用的受限方法，并在持久化前校验 invitation、inviter、invitee、group 与目标私聊成员完全匹配。补一条“普通 WS 用户发送 type 4 被拒绝”的路由/dispatcher 测试。

### 2. P1：成员写入已提交后，广播失败会把成功操作返回成失败

证据：

- 直接加人先在 Repository 提交事务（`server/modules/im-group/src/repository.rs:215-260`），随后 Service `await notify_new_members`，广播失败会让整个 HTTP 请求报错（`server/modules/im-group/src/service.rs:93-110`）。
- 接受邀请同样先提交成员与 accepted 状态（`server/modules/im-group/src/repository.rs:452-477`），随后广播并用 `?` 向上返回错误（`server/modules/im-group/src/service.rs:205-219`）。
- 实际 `WsBroadcaster` 在构造会话更新时会查询数据库并可能返回 `AppError`，并非纯内存、永不失败的通知（`server/modules/im-ws/src/broadcaster.rs:56-68,184-197`）。

影响：数据库已经成功加人，客户端却收到失败并允许重试；重试可能变成“成员已存在”或产生错误 UX，违反“以服务端响应为准”的边界。

最小修复建议：提交后的 WS 推送不能决定业务接口成败。短期将通知改为 best-effort 并记录错误；生产方案使用事务 outbox，在成员/邀请事务内写事件，提交后异步投递。补 broadcaster 故障测试，断言接口仍返回已提交的成功快照。

### 3. P1：邀请创建、消息持久化与广播不是同一事实链，失败回收会留下无效卡片

证据：

- 批量邀请逐个创建并逐个提交，循环中任一后项失败时，前项已经生效（`server/modules/im-group/src/service.rs:148-202`、`server/modules/im-group/src/repository.rs:308-365`）。
- `MessageService::send` 在广播前已经依次写入消息、会话预览和未读数（`server/modules/im-message/src/service.rs:120-165`）。若广播阶段失败，`im-group` 随即删除 pending invitation（`server/modules/im-group/src/service.rs:183-190`），但已持久化的 type 4 消息没有回滚，用户历史消息中会出现永远无法接受的卡片。

最小修复建议：先在一个事务内批量预校验并创建全部 invitation，同时持久化邀请消息或写 outbox；提交后再广播。至少要让消息持久化结果与广播结果可区分，禁止因广播失败删除一个已经有持久化卡片引用的 invitation。补“第二个 invitee 失败不产生半批结果”和“广播失败后 invitation/消息保持一致”测试。

### 4. P1：软解散与消息发送之间存在 TOCTOU 竞态

证据：

- 消息发送先独立执行成员检查，再独立生成 seq 和插入消息（`server/modules/im-message/src/service.rs:111-132`）。
- 解散事务锁群、标记 `is_dissolved` 并软删除成员（`server/modules/im-group/src/repository.rs:480-515`）。

并发时，发送请求可以在解散前通过成员检查、在解散提交后继续插入消息；因此“解散后不能继续发消息”只在串行场景成立。

最小修复建议：把 active-group/member 校验与消息插入放进同一事务，并锁定 conversation；或让插入使用带 `EXISTS(conversations.is_dissolved = FALSE AND active member)` 的原子守卫并检查 affected rows。补并发解散/发送数据库测试。

## 非阻塞架构债务

- P2：`GroupMemberPickerPage` 在 Widget State 中直接读取 `FriendRepository`、捕获异常并维护加载/搜索/选择业务状态（`client/modules/flash_im_group/lib/src/view/group_member_picker_page.dart:25-67,155-160`），与同包已有 Cubit 分层不一致。建议按设计中的 `GroupMemberPickerState` 下沉到 Cubit，页面只渲染和派发事件。
- P2：`GroupDetailCubit._save` 使用 `Future<dynamic>`，削弱了 Repository → Cubit 的强类型边界（`client/modules/flash_im_group/lib/src/logic/group_detail_cubit.dart:115-130`）。改为 `Future<GroupDetail> Function()`。
- P2：群更新接口在目标不存在/已解散和“非 owner”两种情况下都可能返回 403（`server/modules/im-group/src/repository.rs:65-91,93-119`），与设计中不存在/解散返回 404 的契约不完全一致。建议先用不泄露信息的 owner-active 查询统一映射，再执行更新。

## 复验要求

1. 修复四个 P1 后重新生成客户端、服务端新鲜 Harness 报告。
2. 重新执行测试 Agent 与架构 Agent，不得复用本 attempt。
3. 重点新增：外部 type 4 拒绝、broadcast 故障、批量邀请中途失败、解散/发送并发竞态测试。
