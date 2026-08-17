# 群聊 v0.0.1 架构 Agent 审查 — attempt 3

## 结论

**FAIL**

Harness 本身为通过状态：客户端 `harness-check-client-attempt-3.json:1-6` 为 `PASS`，客户端变更范围覆盖率为 84.29%，服务端 `server-attempt-4/summary.md:22-27` 的定向检查通过且变更生产代码覆盖率为 96.55%。但当前交付仍有安全凭据泄露、创建事务结果不原子两个阻断问题；另外存在新增群模块直接依赖 Dio 和异步 Cubit 生命周期风险。按质量门禁，需退回编码阶段修复后重新执行 Harness 与双 Agent 验收。

## 审查范围与架构识别

- Spec：`analysis.md`、服务端/客户端 `design.md` 与 `tasks.md`。
- 实现：完整工作区 diff、所有新增 `flash_im_group` 文件、Cargo/pubspec、真实 import、DI、路由和现有消息链。
- 证据：`quality/harness-check-client-attempt-3.json`、`quality/server-attempt-4/summary.md`、`api/group/doc/00_link.md` 及各接口文档。
- Rust 服务端是 Axum + SQLx 的模块化单体：宿主在 `server/src/routes/mod.rs:17-35` 组合各 crate 路由；`im-conversation` 保持 `routes -> service -> repository -> PostgreSQL`。
- Flutter 客户端是 path package 模块化结构：宿主 `FlashImApp` 是 composition root，在 `client/lib/app/flash_im_app.dart:258-307` 创建并注入 `ConversationRepository`、`MessageRepository`、`FriendRepository` 与 `WsClient`；页面用 Bloc/Cubit 管理状态。
- `flash_im_group` 的清单依赖方向为 `group -> conversation/friend/shared`（`client/modules/flash_im_group/pubspec.yaml:10-21`），没有依赖宿主 `client/lib`，也没有形成 package 循环。

## 阻断问题

### P0 — API 链产物持久化了完整 Bearer JWT

**证据**

- `docs/features/im/group/v0.0.1/api/group/request/group.py:65-71` 把原始 token 拼进 `Authorization: Bearer ...` 命令。
- 同文件 `91-96` 把包含凭据的完整 curl 命令保存在响应对象，`162-166` 再原样写进 Markdown。
- 已生成文档确实包含完整 JWT，例如 `api/group/doc/02_create_group.md:50-54`、`03_list_groups.md:58-62`、`08_non_friend_member.md:26-30`；扫描结果覆盖 02～10、12 共 11 份文档。

**影响**

测试账号 token 被写入版本化质量产物，违反敏感认证信息不得入日志/文档的安全边界。即使 token 短期有效或属于测试账号，也不应进入仓库历史。

**最小修复**

在 `group.py` 生成文档前把 Authorization 值替换为固定占位符（如 `<REDACTED_TOKEN>`），运行请求仍使用内存中的真实 token；重新生成全部接口文档并确认 `rg` 不再命中 JWT 三段式内容。若这些 token 仍可能有效，应使其失效或轮换。不得只手工改当前 Markdown，否则下次运行会再次泄露。

### P1 — 创建接口可能返回失败但群已提交，破坏失败回滚语义

**证据**

- `server/modules/im-conversation/src/repository.rs:150-184` 在事务内校验好友、插入会话和成员，但在 `186-191` 已经提交后只返回 `Uuid`。
- `server/modules/im-conversation/src/service.rs:93-101` 在事务完成后才通过新的数据库查询构造响应。
- 如果该详情查询失败，`POST /conversations` 返回 500，但数据库中群和成员已经存在。此行为与 `analysis.md:166-175` 中“创建失败 -> 事务回滚，页面保留选择重试”的回退契约不一致；客户端重试会创建另一个群。
- 现有 `server/src/lib.rs:304-367` 和 API 链只覆盖成功查询及输入拒绝，未覆盖“写入成功、响应详情查询失败”的提交歧义。

**影响**

HTTP 结果与数据库事实不一致，调用方无法判断是否已创建成功，可能产生重复群聊；这也是典型的事务/响应边界不完整。

**最小修复**

让 repository 在同一 SQLx transaction 中完成详情查询并返回 `ConversationListRow`，成功拿到响应对象后再 commit；service 只做 DTO 映射。若选择保留提交后查询，则必须设计幂等键和冲突恢复，但这超出当前最小版本，优先采用事务内查询。补一个可注入查询失败或数据库约束失败的测试，断言无半成品会话。

### P1 — 新群业务状态层直接依赖 Dio 传输类型

**证据**

- `client/modules/flash_im_group/pubspec.yaml:10-12` 为群业务包直接声明 `dio`。
- `client/modules/flash_im_group/lib/src/logic/create_group_cubit.dart:1` 在 Cubit 层导入 Dio，`97-107` 识别 `DioException` 并解析 HTTP 响应 Map。
- UI/Cubit 其他调用已经正确依赖 `FriendRepository`/`ConversationRepository` 接口（同文件 `8-28`），因此只有错误通道穿透了数据/网络边界。

**影响**

表现/业务状态层了解具体 HTTP 客户端与响应形状，替换网络实现时仍需修改 Cubit；错误映射也散落，无法统一处理超时、未认证、服务端业务错误和格式错误。

**最小修复**

在 conversation 数据边界把 `DioException` 映射为不依赖 Dio 的 typed failure/AppException（至少包含可展示 message），Cubit 只消费统一错误类型或中文兜底；随后删除 `flash_im_group` 的 Dio 依赖。不要把 `Response`/Map 暴露到 Repository 接口。

### P1 — 新建页面退出时可能发生 Cubit 关闭后继续 emit

**证据**

- `CreateGroupCubit.loadFriends` 在 `client/modules/flash_im_group/lib/src/logic/create_group_cubit.dart:30-46` await Repository 后直接 emit；`createGroup` 在 `64-87` 同样在 await 成功/失败后直接 emit。
- `GroupListCubit.load/loadMore` 在 `client/modules/flash_im_group/lib/src/logic/group_list_cubit.dart:16-33`、`38-58` await 网络后直接 emit。
- 这些 Cubit 由页面局部 `BlocProvider` 创建（`create_group_page.dart:18-27`、`my_groups_page.dart:13-20`），路由 pop 会自动 close；慢请求期间返回上页后，Future 仍可能恢复并对已关闭 Cubit emit。

**影响**

产生 `Cannot emit new states after calling close` 异步异常；创建请求尤其可能在用户退出页面后成功，随后成功/失败分支仍试图更新已销毁状态。

**最小修复**

所有 await 后、每次 emit 前检查 `isClosed`；创建成功时若 Cubit 已关闭，不再 emit，但可安全结束 Future。若 Repository 支持取消，再给页面级请求接入 CancelToken/可取消操作。补“pending request 时 close Cubit，完成后不抛异常”的单测。

## 通过项

### 分层与依赖方向 — PASS

- 服务端 handler 仅做鉴权/提取/响应（`server/modules/im-conversation/src/routes.rs:14-42`），业务规则在 service（`service.rs:40-117`），SQL 和事务在 repository（`repository.rs:102-204`）。
- `im-conversation` 没有反向依赖 `im-friend`；它在自己的 repository 内校验 `friend_relations`，避免 `im-friend -> im-conversation` 既有方向形成 Cargo 循环。Cargo 证据：`server/modules/im-conversation/Cargo.toml:7-13`、`server/modules/im-friend/Cargo.toml:7-15`。
- Flutter 群页面只从 DI 读取 Repository 接口（`create_group_page.dart:18-27`、`my_groups_page.dart:13-20`），宿主集中处理路由和打开聊天（`client/lib/app/app_router.dart:112-202`、`main_shell_page.dart:110-193`）。除上述 Dio 错误穿透外，没有 Widget 直接发 HTTP/访问存储。

### 权限与数据访问 — PASS（除事务结果问题）

- 服务端校验 type、trim 后名称、2～199 人、本人 ID 和重复 ID：`server/modules/im-conversation/src/service.rs:40-67`。
- 好友数量校验、群主+成员插入均在同一 transaction：`server/modules/im-conversation/src/repository.rs:144-189`；非好友链路实测为 400：`api/group/doc/08_non_friend_member.md:1-23`。
- 列表和详情均以当前用户 `conversation_members.is_deleted = FALSE` 限制访问：`repository.rs:48-52`、`96-99`；非成员详情 API 链为 404：`api/group/doc/00_link.md:15-17`。

### DI、路由与包职责 — PASS

- 没有新增全局单例或新的 Repository 注入；复用宿主已经注册的 `ConversationRepository` 与 `FriendRepository`。
- 路由常量和 typed argument 集中在 `client/lib/app/app_router.dart:13-58`；业务包不依赖宿主路由。
- 新 `flash_im_group` 将 Cubit/state 与页面/widgets 分开，`flash_im_conversation` 继续拥有 DTO/API 和通用会话头像展示，符合客户端设计 `client/design.md:181-197`。

### 消息收发完全复用已有链路 — PASS

这是本次架构审查的明确通过项：

- 生产 diff 中 `flash_im_chat` 只修改 `lib/src/view/chat_page.dart`，增加可选详情按钮；`ChatCubit`、`MessageRepository`、`WsClient` 均无生产代码变更，服务端 `im-message`、`im-ws` 与 protobuf 也无生产代码变更。
- `ChatPage` 仍按原路径注入同一个 `MessageRepository`、`WsClient` 并创建 `ChatCubit`：`client/modules/flash_im_chat/lib/src/view/chat_page.dart:37-61`。
- 现有发送/ACK/接收路径保持为 `ChatCubit._sendOverWebSocket`（`chat_cubit.dart:326-340`）→ `WsClient.sendMessage`（`ws_client.dart:118-140`）→ 现有 ACK/ChatMessage stream（`ws_client.dart:172-189`、`chat_cubit.dart:386-425`）。
- 服务端仍由现有 dispatcher 调 `MessageService.send`（`server/modules/im-ws/src/dispatcher.rs:40-68`），再做成员校验、seq、持久化、未读和广播（`server/modules/im-message/src/service.rs:93-173`）。
- 真实 API/WS 链 12/12 通过（`api/group/doc/00_link.md:6-19`）；现有 WS 帧得到 sender、seq、unread 证据（`11_group_message_ws.md:1-22`），同一消息可由原历史接口读取（`12_group_message_history.md:1-32`）。未发现任何群专属消息 Repository、Cubit、WS frame 或 HTTP 发送旁路。

### 公共 API 与兼容性 — 基本 PASS，有内部源兼容提示

- 后端响应只追加可空字段/空数组；既有路径与字段未删除，旧 JSON 客户端通常可忽略新字段。
- `Conversation` 新字段均为可选/default，`ChatPage.onDetailsTap` 也是可选，既有构造调用兼容。
- `ConversationRepository.getList` 新增 optional named `type` 会要求仓库外自定义实现/测试 fake 更新方法签名；`ContactsPage.onOpenGroups` 从无到 required 是明确的 Dart 源兼容变化（`client/modules/flash_im_friend/lib/src/view/contacts_page.dart:16-24`）。当前 monorepo 消费方已更新且包均 `publish_to: none`，所以不单独阻断；若这些内部包被其他仓库 path 引用，应把 callback 设为可选或在版本说明中标明 breaking change。

## 非阻断审计问题

- `client/tasks.md:18-27` 与 `31-250` 仍将几乎所有客户端任务标为进行中/待处理，但实现、测试和 attempt-3 Harness 已存在。这不改变本报告的代码结论，但破坏工作流追踪；修复并重跑门禁后由主编排更新任务状态，架构 Agent 不修改任务文档。
- Harness 变更清单包含 `client/modules/flash_im_chat/build/...`、coverage 和 IDE 生成文件（`harness-check-client-attempt-3.json:8-18`）。提交前应排除生成缓存/二进制变更，保留必要的质量报告即可。

## 重验条件

1. 文档生成器完成 token 脱敏，全部生成文档不再包含真实 JWT。
2. 群创建详情在提交前构造完成，或提供等价的幂等/一致性保证，并补失败回滚测试。
3. `flash_im_group` 不再依赖 Dio 具体异常，错误由数据边界统一映射。
4. 新 Cubit 覆盖关闭后异步完成场景，不再 emit-after-close。
5. 重新执行当前客户端和服务端 Harness；通过后重新运行测试 Agent 与架构 Agent。
