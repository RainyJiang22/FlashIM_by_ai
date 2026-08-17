# 群聊 v0.0.1 测试 Agent 门禁报告 — attempt 3

## 结论

**FAIL**

Harness 本身为 PASS，但 Spec 验收不通过，必须退回客户端编码阶段。服务端创建/查询、权限边界、群消息既有链路复用和“我的群聊”主路径有充分证据；客户端仍有 3 个明确行为偏差，并缺少单聊建群整链和既有红点/消息链的本轮回归证据。

本 Agent 遵守只读约束，没有重新执行会产生构建或覆盖率文件的测试命令；以下测试结果来自指定的新鲜 Harness/API 证据。除本报告外未修改任何文件。

## 输入与门禁证据

- Spec：`analysis.md`、`server/design.md`、`server/tasks.md`、`client/design.md`、`client/tasks.md`。
- 实现：核对 `git diff HEAD` 中全部群聊相关已跟踪变更，并逐文件核对未跟踪的 `flash_im_group` 包、`GroupAvatar` 和宿主路由测试；确认 `im-message`、`im-ws`、protobuf、客户端 `ChatCubit`、`MessageRepository`、消息实体和消息气泡生产代码没有本次变更。
- 客户端 Harness：`harness-check-client-attempt-3.json:2` 为 PASS；变更生产代码覆盖率 84.29%（923/1095，阈值 80%），见该文件 290-299 行；五组 Flutter 测试均 PASS，见 189-233 行；五组 analyze 均 PASS，见 584-630 行；生成时间见 636 行。
- 服务端 Harness：`server-attempt-4/summary.md:3-27` 为 PASS；定向测试 14/14、真实数据库 Axum 路由 1/1、Clippy PASS、变更生产代码覆盖率 96.55%（364/377）。
- API/WS 链：`api/group/doc/00_link.md:6-19` 的 12 个步骤全部 PASS，生成时间见 4 行。

## 验收逐条核对

### 1. 从好友中选人创建群聊 — FAIL

已通过部分：

- `CreateGroupPage` 从 `FriendRepository` 加载好友、按字母分组、搜索、选择和完成提交，见 `client/modules/flash_im_group/lib/src/view/create_group_page.dart:20-27,46-90,117-160`。
- 少于 2 人不发请求，创建期间不能重复提交；固定选择、搜索、失败保留选择由 `CreateGroupCubit` 实现，见 `create_group_state.dart:25-39`、`create_group_cubit.dart:49-88`。
- Repository 使用 `POST /conversations`，body 固定为 `type=group/name/member_ids`，见 `client/modules/flash_im_conversation/lib/src/data/conversation_repository.dart:56-74`；请求契约测试见 `conversation_test.dart:194-227`。
- 页面成功后返回 `Conversation`，宿主刷新会话列表并打开现有 Chat，见 `create_group_page.dart:50-68`、`client/lib/features/home/presentation/main_shell_page.dart:165-173`。
- Harness 中 `selects two friends and returns created conversation`、Repository 请求测试均通过，见客户端 Harness 191-205 行。

阻断偏差：

1. Spec 要求“已选头像横条点击可取消”（`analysis.md:17`），但 `selected_friend_strip.dart:23-43` 只有 `Tooltip + AvatarWidget`，没有点击或移除回调；调用处 `create_group_page.dart:86-89` 也未传入移除动作。
   - 最小修复：给 `SelectedFriendStrip` 增加 `ValueChanged<FriendUser> onRemove` 和锁定 ID；普通已选头像用 `InkWell/GestureDetector` 调用 `toggleFriend`，锁定成员禁止取消；补 Widget 测试断言头像点击后数量减少、锁定头像不减少。
2. Spec 规定超过 3 人的群名为“前三个名字 + 等”（`analysis.md:17`、`client/design.md:89`），但 `create_group_cubit.dart:91-94` 生成的是 `等N人`，契约不一致；现有 `create_group_cubit_test.dart:25-48` 仅覆盖 2 人命名。
   - 最小修复：后缀改为单独的 `等`，新增 4 人命名和 100 字截断测试。
3. Spec 的入口是“点击 + 后选择发起群聊”（`analysis.md:17`，`client/tasks.md:202-204`），当前 `messages_placeholder_page.dart:115-120` 的 `IconButton` 直接调用建群回调，没有选择菜单。
   - 最小修复：将入口改为 `PopupMenuButton`（首项“发起群聊”）再触发 `onCreateGroup`；更新宿主 Widget 测试先打开菜单再选择该项。

### 2. 从单聊拉人创建新群 — INCOMPLETE

实现链存在：

- 私聊且回调存在时显示更多按钮，群聊不显示，见 `client/modules/flash_im_chat/lib/src/view/chat_page.dart:67-96`。
- Chat 路由构造对端 `FriendUser`、打开详情，详情页再打开带 `initialMembers` 的创建页，创建成功后返回并以新群 Chat 替换当前 Chat，见 `client/lib/app/app_router.dart:120-165,180-202`。
- 初始单聊对象进入 `selectedIds` 和 `lockedIds`，不能取消，见 `create_group_cubit.dart:8-24,53-61`；详情页展示对端并提供邀请入口，见 `private_chat_details_page.dart:15-54`。

证据缺口：

- `create_group_page_test.dart:55-75` 只验证“完成(1)”和锁图标；`100-115` 只验证详情回调被调用。
- `app_router_group_test.dart:31-81` 只分别构建三个页面，没有验证“私聊更多 → 详情 → 创建页 → 原对端锁定 → 再选 1 人 → POST → 当前 Chat 被群 Chat 替换”。
- `client/tasks.md:230-232` 明确把该整链列为验收回归；当前 Harness 输出 200-205、227-233 行没有对应整链用例。

最小修复：增加一个宿主 Widget 导航测试，使用可记录请求的假 Repository，从 `ChatPage` 的 `chat-details-action` 开始走完整交互，断言原对端不能取消、请求成员包含原对端和新好友、最终只显示新群 Chat 标题且旧私聊 Chat 已被替换。

### 3. 查看自己的群聊列表 — PASS

- Repository 以 `type=1/limit/offset` 查询，见 `conversation_repository.dart:27-44`。
- `GroupListCubit` 首屏、分页、本地搜索、刷新和初始错误状态实现见 `group_list_cubit.dart:16-63`、`group_list_state.dart:21-31`。
- 通讯录“群聊”入口见 `client/modules/flash_im_friend/lib/src/view/contacts_page.dart:269-273,468-491`；我的群聊页提供搜索、组合头像列表、下拉刷新、分页、空态、错误重试和点击返回，见 `my_groups_page.dart:29-104`。
- 页面与 Cubit 测试覆盖 type filter、offset、本地搜索、错误重试、选择群返回，见 `group_list_cubit_test.dart:7-37`、`my_groups_page_test.dart:10-61`；Harness 200-205 行记录 11/11 群包测试通过。
- API 链对创建者和两位成员逐一查询列表并断言新群存在，脚本见 `api/group/request/group.py:533-543`；非成员详情为 404，见 `api/group/doc/10_non_member_detail.md:1-10`。

非阻断风险：`GroupListCubit.loadMore` 在失败时设置“更多群聊加载失败”（`group_list_cubit.dart:38-58`），但 `MyGroupsPage` 仅在列表为空时展示 `errorMessage`（`my_groups_page.dart:51-58`），已有数据时加载更多失败没有可见反馈；建议增加底部错误/重试项及测试。

### 4. 群聊消息收发完全复用已有链路 — PASS

- 本次生产 diff 未修改服务端 `im-message`、`im-ws`、protobuf，也未修改客户端 `ChatCubit`、`MessageRepository`、消息模型和消息气泡；客户端只在 `ChatPage` 增加可选详情按钮。
- 群会话仍直接创建现有 `ChatCubit`，标题使用 `conversation.displayName`，见 `chat_page.dart:35-61,84-96`。
- 既有 `MessageBubble` 对他人消息左侧展示头像、昵称在气泡上方，对自己消息靠右，见 `client/modules/flash_im_chat/lib/src/view/bubble/message_bubble.dart:33-42,62-103`。
- API/WS 实测使用现有二进制 `CHAT_MESSAGE`：发送者收到 `MESSAGE_ACK`，接收成员收到 `CHAT_MESSAGE` 和 `CONVERSATION_UPDATE`，发送者昵称/头像与未读数均存在，见 `api/group/doc/11_group_message_ws.md:1-22`；历史接口可查到同一消息，见 `12_group_message_history.md:1-32`。
- Flutter `renders loaded message list` 通过且群聊没有私聊详情按钮，见 `chat_page_test.dart:81-118` 和 Harness 209-215 行。

测试缺口：当前群聊页面测试只断言消息文本，没有断言发送者昵称/头像位置，也没有在本轮运行 `chat_cubit_test.dart` 的乐观发送、ACK、12 秒失败态回归。API 链足以证明后端复用，但客户端回归仍应补入最终 Harness。

### 5. 权限、校验、事务与错误边界 — PASS

- 服务端校验 type、trim 后群名 1～100 字、邀请人数 2～199、本人和重复 ID，见 `server/modules/im-conversation/src/service.rs:40-67`。
- 好友计数、会话和成员写入处于同一 SQLx 事务，非好友在写入前回滚，见 `server/modules/im-conversation/src/repository.rs:119-180` 及后续 commit；列表/详情均要求当前成员 `is_deleted=false`，见同文件 48-52、96-99 行。
- API 链覆盖未认证 401、人数不足、重复、本人、非好友、非法列表 type 和非成员详情，12/12 PASS，见 `api/group/doc/00_link.md:8-19`。
- 真实数据库路由与 service/repository round-trip 通过，证据见 `server-attempt-4/summary.md:14-27`。

建议补充但不改变本项结论：增加恰好 100 字/101 字、199/200 人、成员不存在、失败前后会话计数不变、非成员群列表不包含新群的自动化断言。当前 API 文档对“无半成品”的文字说明没有直接记录前后计数。

### 6. 兼容与回归 — INCOMPLETE

- 私聊列表头像仍走 `peerAvatar`，群聊才走 `GroupAvatar`，见 `conversation_tile.dart:85-104`；模型/请求/组合头像用例通过，见 Harness 191-197 行。
- 通讯录群聊入口没有改动 `pendingRequestCount` 的计算链；联系人点击回调在 `contacts_page_test.dart:45-61` 仍通过。
- 但 `client/tasks.md:234` 明确要求“现有私聊消息、好友申请红点和通讯录好友点击行为不回归”。本轮 Harness 对 chat 仅执行 `chat_page_test.dart`（Harness 209-215 行），没有执行既有 `chat_cubit_test.dart`；对 contacts 仅执行一个 pending 请求为空的用例（`contacts_page_test.dart:85-96`，Harness 218-224 行），没有非零红点断言。因此当前证据不能完成该条验收。

最小修复：把 chat 包的既有消息 Cubit/气泡测试和一个 pending request count 非零的通讯录/主导航红点测试纳入 Harness；同时保留现有好友点击断言。

## 必须修复后重验

1. 实现已选头像点击取消，锁定成员保持不可取消，并补 Widget 测试。
2. 将 4 人以上自动群名修正为“前三 + 等”，补 4 人及 100 字测试。
3. 按 Spec 给消息页“+”增加“发起群聊”选择菜单，并更新入口测试。
4. 补单聊拉人建群到 Chat 替换的完整宿主测试。
5. 将私聊发送/ACK/失败态与好友申请红点非零回归纳入下一次 Harness。

修复后必须生成新的 Harness attempt；PASS 后重新运行测试 Agent 与架构 Agent，不能复用本报告或 attempt 3 的结论。
