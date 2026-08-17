# 群聊 v0.0.1 — Test Agent 复验（attempt 4）

## 结论

**INCOMPLETE**

本轮未发现新的已证实功能错误；attempt 3 的四个主要交互阻断均已按 Spec 修复，服务端与 API/WS 证据也通过。但在 `harness-check-client-attempt-4.json` 生成后，当前工作树继续修改了两个测试文件，因此 attempt 4 的 Harness 不再是当前 diff 的新鲜证据：

- `harness-check-client-attempt-4.json` 生成时间为 `2026-08-16T13:11:30Z`（本地 21:11:30），见 `harness-check-client-attempt-4.json:640`。
- `client/modules/flash_im_chat/test/chat_cubit_test.dart` 本地修改时间为 21:20:20，新增 12 秒无 ACK 失败态测试，见该文件 `:47-75`。
- `client/modules/flash_im_group/test/create_group_cubit_test.dart` 本地修改时间为 21:20:39，新增 100 code point 群名截断测试，见该文件 `:88-119`。

按质量门禁规则，当前代码/测试变更必须重新生成新 attempt 的测试、覆盖率与静态扫描证据；不能用较早的 attempt 4 PASS 替代。最小修复是对当前工作树重新执行客户端 Harness，并在新报告通过后重新发起 Test Agent 验收，不需要为此修改生产代码。

本报告严格只读审查；未自行执行会写入 `build/`、`coverage/` 或文档的测试命令，以下运行结果均来自指定 Harness/API 证据。

## 验收逐项核对

### 1. 从好友中选人创建群聊：实现 PASS，当前执行证据 INCOMPLETE

Spec：`analysis.md:13-25`、`client/design.md:12-18,84-90`。

实现证据：

- 消息页 `+` 已改为菜单，菜单项为“发起群聊”：`client/lib/features/messages/presentation/messages_placeholder_page.dart:115-136`。
- 已选头像支持点击取消；锁定成员头像没有取消回调：`client/modules/flash_im_group/lib/src/view/widgets/selected_friend_strip.dart:35-53`。
- 页面把 `lockedIds` 和取消动作传入头像横条：`client/modules/flash_im_group/lib/src/view/create_group_page.dart:86-91`。
- 普通成员可切换，锁定成员及创建中均禁止切换：`client/modules/flash_im_group/lib/src/logic/create_group_cubit.dart:58-67`。
- 至少 2 人才可提交：`client/modules/flash_im_group/lib/src/logic/create_group_state.dart:25-26`。
- 3 人以内用顿号，4 人以上取前三并追加“等”，按 Unicode code point 截到 100：`client/modules/flash_im_group/lib/src/logic/create_group_cubit.dart:101-104`。
- Repository 固定发送 `type=group`、`name`、`member_ids`：`client/modules/flash_im_conversation/lib/src/data/conversation_repository.dart:63-90`。

对应测试：

- `selects two friends and returns created conversation`，并实际点击已选头像取消后重新选择：`client/modules/flash_im_group/test/create_group_page_test.dart:11-58`。
- `loads, searches and protects locked member`：`client/modules/flash_im_group/test/create_group_cubit_test.dart:9-23`。
- `requires two members and creates group with generated name`：同文件 `:25-48`。
- `more than three members uses first three names plus 等`：同文件 `:68-85`。
- 新增的 `generated group name truncates Unicode safely to 100 code points`：同文件 `:88-119`，但晚于 attempt 4 Harness，尚无本轮执行结果。
- 宿主从 `+` 菜单选择“发起群聊”、创建并打开聊天：`client/test/features/main_shell/presentation/main_shell_page_test.dart:98-108`。

attempt 4 已执行命令：

- `flutter test --coverage`（群包，12 项通过）：`harness-check-client-attempt-4.json:203-210`。
- `flutter test test/app/app_router_group_test.dart test/features/main_shell/presentation/main_shell_page_test.dart test/features/startup/presentation/startup_page_test.dart --coverage`（7 项通过）：同报告 `:230-237`。

缺口与最小修复：重新执行包含新增 100 字边界用例的当前群包测试并生成新 Harness。另建议按 `client/tasks.md:125-127` 补一个“创建中重复点击只调用一次 Repository”的定向测试；当前实现已有 `isCreating` 保护，但尚无对应测试名称。

### 2. 从单聊拉人创建新群：PASS

Spec：`analysis.md:28-43,105-129`、`client/tasks.md:230-232`。

实现证据：

- 私聊 ChatPage 仅在存在回调时显示详情按钮：`client/modules/flash_im_chat/lib/src/view/chat_page.dart:81-91`。
- 私聊详情把当前对端作为 `initialMembers` 打开建群页：`client/lib/app/app_router.dart:180-200`。
- 建群成功后以新群会话替换当前 Chat 路由：`client/lib/app/app_router.dart:126-162`。

对应测试：

- `private chat invite creates group and replaces chat route` 完整执行“私聊 → 详情 → 邀请 → 锁定对端 → 再选好友 → 创建 → 新群 Chat”，并断言成员 `[2, 3]`：`client/test/app/app_router_group_test.dart:70-107`。
- Cubit 层尝试取消固定成员后选择仍为 `{2}`：`client/modules/flash_im_group/test/create_group_cubit_test.dart:9-18`。
- Widget 层验证锁定图标：`client/modules/flash_im_group/test/create_group_page_test.dart:60-80`。

执行命令：宿主路由测试命令见 Harness `:230-237`；群包命令见 `:203-210`，均为 PASS。该链本身未在 Harness 之后修改。

### 3. 查看自己的群聊列表：PASS

Spec：`analysis.md:45-58`、`client/design.md:127-142`。

实现证据：

- `GroupListCubit` 固定以 `type: 1` 分页，并支持刷新、加载更多和失败态：`client/modules/flash_im_group/lib/src/logic/group_list_cubit.dart:16-74`。
- 本地按群名过滤：`client/modules/flash_im_group/lib/src/logic/group_list_state.dart:21-32`。
- 页面具有搜索、空态、错误重试、下拉刷新、分页和点击返回群会话：`client/modules/flash_im_group/lib/src/view/my_groups_page.dart:29-105`。
- 服务端只返回当前用户 `is_deleted=false` 的会话并支持 type 过滤：`server/modules/im-conversation/src/repository.rs:24-53,102-117`。

对应测试：

- `loads group pages with type filter and searches locally`：`client/modules/flash_im_group/test/group_list_cubit_test.dart:7-25`。
- `load error is recoverable by refresh`：同文件 `:27-37`。
- `lists, searches and returns selected group`、`shows list error with retry action`：`client/modules/flash_im_group/test/my_groups_page_test.dart:10-61`。
- API 链的创建、列表、详情均 PASS：`api/group/doc/00_link.md:9-11`；列表响应确含当前群、owner 与组合头像：`api/group/doc/03_list_groups.md:13-55`。

执行命令：群包 `flutter test --coverage` 12 项通过（Harness `:203-210`）；服务端 `cargo test -p im-conversation` 14/14 通过（`server-attempt-5/summary.md:13-23`）。

### 4. 群聊消息收发完全复用已有链路：实现/API PASS，当前客户端执行证据 INCOMPLETE

Spec：`analysis.md:60-72,131-175`、`server/design.md:161-171`、`client/design.md:74-82,189-196`。

实现证据：

- `git diff --quiet HEAD -- server/modules/im-message server/modules/im-ws server/modules/im-gateway` 返回 0；服务端消息协议、MessageService 和 WS 生产链未修改。
- `git diff --quiet HEAD -- client/modules/flash_im_chat/lib/src/logic/chat_cubit.dart client/modules/flash_im_chat/lib/src/data/message_repository.dart client/modules/flash_im_chat/lib/src/view/bubble` 返回 0；客户端发送、ACK、历史和气泡链未分叉。
- 群 ChatPage 仍使用同一个 `ChatCubit` 与 `MessageBubble`：`client/modules/flash_im_chat/lib/src/view/chat_page.dart:43-60,146-157,178-200`。
- 既有 Cubit 以 12 秒 Timer 将无 ACK 消息置失败，并在 ACK 时置 sent：`client/modules/flash_im_chat/lib/src/logic/chat_cubit.dart:44-45,326-340,386-408,448-465`。
- API/WS 链证明现有帧完成发送、ACK、接收、发送者资料、未读和历史回放：`api/group/doc/11_group_message_ws.md:1-22`、`12_group_message_history.md:1-32`。

对应测试：

- attempt 4 已执行 `sendText appends sending message`、`message ack marks first pending message as sent`、当前会话接收与其他会话忽略：`client/modules/flash_im_chat/test/chat_cubit_test.dart:77-179`（行号按当前文件；Harness 运行时对应测试已通过）。
- 新增 `text message without ACK becomes failed after 12 seconds`：同文件 `:47-75`，精准覆盖 `analysis.md:164,175`，但其修改晚于 attempt 4 Harness。
- 群 ChatPage 加载群消息：`client/modules/flash_im_chat/test/chat_page_test.dart:81-118`。

attempt 4 执行命令：`flutter test test/chat_page_test.dart test/chat_cubit_test.dart --coverage`，当时 14 项通过，见 Harness `:212-219`。由于 12 秒测试后来才加入，需重新执行后才能完成本验收项。

非阻断增强建议：群 ChatPage 测试目前只断言消息正文和群聊不显示详情按钮，未直接断言他人昵称/头像；可在该用例增加 `朱红` 和 `AvatarWidget` 断言，或把相应 `message_bubble_test.dart` 纳入新 Harness 命令。

### 5. 权限、输入和错误边界：PASS（有补测建议）

Spec：`analysis.md:80-85,166-175`、`server/design.md:73-132`。

实现证据：

- 服务端校验 `type=group`、trim 后 1～100 字、邀请人数 2～199、本人和重复 ID：`server/modules/im-conversation/src/service.rs:40-67`。
- 好友关系校验、群/成员写入、创建结果读取均在同一事务内，最后才提交：`server/modules/im-conversation/src/repository.rs:144-200`。
- 列表与详情只允许有效成员；非成员详情返回 404：`server/modules/im-conversation/src/repository.rs:48-50,96-99,202-213`。
- 客户端将 Dio 错误转换为领域异常并读取服务端 `message`，其他错误使用中文兜底：`client/modules/flash_im_conversation/lib/src/data/conversation_repository.dart:67-90`、`client/modules/flash_im_group/lib/src/logic/create_group_cubit.dart:86-114`。
- 创建失败保留选择：`client/modules/flash_im_group/test/create_group_cubit_test.dart:50-66`。

对应测试/API 链：

- 服务端输入单测覆盖 101 字拒绝、少于 2 人、本人、重复以及 199 人接受：`server/modules/im-conversation/src/service.rs:291-338`。
- 真实数据库 service 往返覆盖创建、列表与非好友拒绝：同文件 `:340-440`。
- API 链 12/12 PASS，覆盖 401、成员不足、重复、本人、非好友、非法 type、非成员详情，以及消息 WS/历史：`api/group/doc/00_link.md:6-19`。
- 客户端 Repository 领域错误映射测试：`client/modules/flash_im_conversation/test/conversation_test.dart:275-290`。

执行命令：服务端格式、14/14 测试、Clippy 与 llvm-cov 均通过，变更生产代码覆盖率 94.04%（363/386）：`server-attempt-5/summary.md:11-23`。API/WS 链 12/12 结果见 `api/group/doc/00_link.md:6-19`。

非阻断增强建议：增加服务端“正好 100 字接受、200 位受邀者拒绝”相邻边界用例；增加客户端 `ConversationRequestException(serverMessage)` 经过 Cubit 后展示服务端文案的组合测试。

### 6. 回归：PASS

Spec：`client/tasks.md:218-234`。

- 群会话组合头像及群名：`client/modules/flash_im_conversation/test/conversation_test.dart:122-170`，conversation 包命令 20 项通过（Harness `:193-201`）。
- 消息页创建、会话点击、未读清除、通讯录群聊入口及好友点击：`client/test/features/main_shell/presentation/main_shell_page_test.dart:85-137`，宿主命令通过（Harness `:230-237`）。
- 好友申请 pending badge 在打开“群聊”后仍为 `1`，好友点击/发消息继续工作：`client/modules/flash_im_friend/test/contacts_page_test.dart:30-69,86-104`；`flutter test test/contacts_page_test.dart --coverage` 1 项通过（Harness `:221-228`）。
- 私聊发送、ACK、当前会话接收及其他会话隔离由 `chat_cubit_test.dart` 覆盖；attempt 4 chat 命令通过（Harness `:212-219`）。

## Harness 与静态门禁

- 客户端 attempt 4 报告状态 PASS：`harness-check-client-attempt-4.json:1-7`。
- 当时 changed-scope 覆盖率 87.40%（978/1119），阈值 80%，无未测量变更生产文件：同报告 `:294-302,585-586`。
- conversation、group、chat、friend 和宿主五组静态分析全部 PASS：同报告 `:588-635`。
- 服务端 attempt 5 为 PASS，覆盖率 94.04%，14/14 测试及 Clippy 通过：`server-attempt-5/summary.md:1-23`。
- API 文档中的 Bearer 值均为 `<redacted>`；`api/group/doc` 未发现未脱敏 JWT。
- `git diff --check HEAD --` 对本功能生产代码、测试相关模块、服务端与功能文档返回 0。

但客户端 attempt 4 在当前两个测试文件变更之前生成，所以这些 PASS 数字不能作为当前工作树的最终 Harness 门禁。重新生成新 attempt 后，若新增测试、覆盖率和静态分析全部 PASS，且 diff 未再变化，本 Test Agent 可进入下一轮 PASS 复验。

## 文档一致性提示

`client/tasks.md:18-27,31-236` 仍将客户端任务标为进行中/待处理，和当前实现及 Harness 状态不一致。该问题不代表运行时功能缺陷，但在最终工作流交付前应由编码/编排阶段更新；Test Agent 按规则不修改任务文档。
