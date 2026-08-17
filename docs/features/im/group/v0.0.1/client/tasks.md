# 群聊 v0.0.1 — 客户端任务清单

基于 [design.md](./design.md) 设计。仅在服务端 API、服务端测试和 API 链路验证完成后开始本清单。

全局约束：

- 使用 Cubit，不引入 Event 模式；创建状态与群列表状态分离。
- 消息收发完全复用现有 `ChatPage`、`ChatCubit`、`MessageRepository`、`WsClient` 和消息气泡。
- `flash_im_group` 不依赖宿主 `client/lib`；宿主负责认证、路由、刷新会话列表和打开聊天。
- 大页面的选择行、已选头像、空态和错误态拆到同级 `widgets/`。
- 保留现有好友申请、红点、通讯录字母索引、会话分页、未读和导航行为。
- 不执行 Gradle/Android 或 Xcode/iOS 构建；只执行定向 Dart/Flutter 检查和测试。

---

## 执行顺序

1. ✅ 任务 1 — 扩展会话模型/API 与测试（无依赖）
2. ✅ 任务 2 — 增加群组合头像并适配会话列表（依赖任务 1）
3. ✅ 任务 3 — 创建 `flash_im_group` 包配置与导出（依赖任务 1）
4. ✅ 任务 4 — 实现创建群聊 Cubit/状态（依赖任务 1、3）
5. ✅ 任务 5 — 实现我的群聊 Cubit/状态（依赖任务 1、3）
6. ✅ 任务 6 — 实现选人、我的群聊和单聊详情页面（依赖任务 2、4、5）
7. ✅ 任务 7 — 给聊天页增加可选详情入口（依赖任务 6）
8. ✅ 任务 8 — 接入消息页、通讯录、路由和宿主导航（依赖任务 6、7）
9. ✅ 任务 9 — 增加模型、Repository、Cubit、Widget 和宿主回归测试（依赖任务 1-8）
10. ✅ 最后 — 客户端 Harness Check：格式、测试、新鲜覆盖率 ≥80%、静态扫描（依赖任务 1-9）

---

## 任务 1：会话模型与 Repository — 群字段、筛选和创建 `✅ 已完成`

文件：

- `client/modules/flash_im_conversation/lib/src/data/conversation.dart`
- `client/modules/flash_im_conversation/lib/src/data/conversation_repository.dart`
- `client/modules/flash_im_conversation/test/conversation_test.dart`
- `client/modules/flash_im_conversation/test/conversation_api_test.dart`

改动类型：`修改文件`

### 1.1 扩展 `Conversation` `✅`

新增 `avatar`、`ownerId`、不可变 `memberAvatars`；`copyWith`、props 和 JSON 解析同步更新，`isGroupChat => type == 1`。

### 1.2 扩展 Repository 接口 `✅`

```dart
Future<List<Conversation>> getList({int limit = 20, int offset = 0, int? type});

Future<Conversation> createGroup({
  required String name,
  required List<int> memberIds,
});
```

`createGroup` 调用 `POST /conversations`，body 固定 `type: group`；列表仅在 type 非空时附带查询参数。

### 1.3 覆盖解析和请求测试 `✅`

验证群字段、空数组兼容、type query、创建 body、异常 JSON。

## 任务 2：群组合头像与会话列表适配 `✅ 已完成`

文件：

- `client/modules/flash_im_conversation/lib/src/view/group_avatar.dart`
- `client/modules/flash_im_conversation/lib/src/view/conversation_tile.dart`
- `client/modules/flash_im_conversation/lib/flash_im_conversation.dart`
- `client/modules/flash_im_conversation/test/conversation_tile_test.dart`

改动类型：`新建 + 修改文件`

### 2.1 实现 `GroupAvatar` `✅`

使用最多 4 个 `AvatarWidget` 以 1/2/4 格布局组合；头像为空时以会话 ID 生成稳定 identicon。

### 2.2 会话列表按类型选择头像 `✅`

私聊保持 `peerAvatar`；群聊使用 `memberAvatars` 与 `GroupAvatar`，名称继续走 `displayName`。

## 任务 3：创建 `flash_im_group` 包 `✅ 已完成`

文件：

- `client/modules/flash_im_group/pubspec.yaml`
- `client/modules/flash_im_group/analysis_options.yaml`
- `client/modules/flash_im_group/lib/flash_im_group.dart`

改动类型：`新建文件`

### 3.1 声明依赖 `✅`

声明 flutter、dio、equatable、flutter_bloc、flash_im_friend、flash_im_conversation、flash_shared。

### 3.2 公共导出 `✅`

仅导出创建/群列表 Cubit 状态与三个页面，不导出私有 widgets。

## 任务 4：创建群聊状态与 Cubit `✅ 已完成`

文件：

- `client/modules/flash_im_group/lib/src/logic/create_group_state.dart`
- `client/modules/flash_im_group/lib/src/logic/create_group_cubit.dart`
- `client/modules/flash_im_group/test/create_group_cubit_test.dart`

改动类型：`新建文件`

### 4.1 定义选择状态 `✅`

保存 friends、selectedIds、lockedIds、query、loading/creating/error；派生过滤列表、完成按钮可用性与选择数量。

### 4.2 实现业务动作 `✅`

```dart
Future<void> loadFriends();
void updateQuery(String value);
void toggleFriend(FriendUser friend);
Future<Conversation?> createGroup();
```

固定成员不能取消；创建失败保留选择；群名按分析规则生成并截断到 100 字。

### 4.3 覆盖 Cubit 测试 `✅`

覆盖普通入口最少 2 人、单聊固定成员、搜索、锁定取消保护、重复提交、成功和失败状态。

## 任务 5：我的群聊状态与 Cubit `✅ 已完成`

文件：

- `client/modules/flash_im_group/lib/src/logic/group_list_state.dart`
- `client/modules/flash_im_group/lib/src/logic/group_list_cubit.dart`
- `client/modules/flash_im_group/test/group_list_cubit_test.dart`

改动类型：`新建文件`

### 5.1 加载与本地搜索 `✅`

通过 `ConversationRepository.getList(type: 1)` 分页加载；搜索只过滤已加载群名，不改变原始列表。

### 5.2 覆盖加载、搜索、刷新、错误测试 `✅`

## 任务 6：群业务页面与 widgets `✅ 已完成`

文件：

- `client/modules/flash_im_group/lib/src/view/create_group_page.dart`
- `client/modules/flash_im_group/lib/src/view/my_groups_page.dart`
- `client/modules/flash_im_group/lib/src/view/private_chat_details_page.dart`
- `client/modules/flash_im_group/lib/src/view/widgets/selected_friend_strip.dart`
- `client/modules/flash_im_group/lib/src/view/widgets/selectable_friend_tile.dart`
- `client/modules/flash_im_group/lib/src/view/widgets/group_feedback_view.dart`
- `client/modules/flash_im_group/test/create_group_page_test.dart`
- `client/modules/flash_im_group/test/my_groups_page_test.dart`

改动类型：`新建文件`

### 6.1 创建群聊页 `✅`

AppBar 完成按钮 + 搜索框 + 已选头像横条 + 按字母分组好友选择；成功后 `Navigator.pop(context, conversation)`。

### 6.2 我的群聊页 `✅`

搜索框 + `ConversationTile` 列表 + 下拉刷新/加载/空态/错误态；点击后返回 `Conversation`。

### 6.3 单聊详情页 `✅`

展示对端头像与昵称、邀请更多人按钮；回调由宿主打开带锁定成员的创建页。

## 任务 7：聊天页详情入口 `✅ 已完成`

文件：

- `client/modules/flash_im_chat/lib/src/view/chat_page.dart`
- `client/modules/flash_im_chat/test/chat_page_test.dart`

改动类型：`修改文件`

### 7.1 新增可选回调 `✅`

```dart
final Future<void> Function()? onDetailsTap;
```

仅私聊且回调非空时显示 AppBar 更多按钮；消息列表、输入和 Cubit 创建保持不变。

## 任务 8：宿主入口、路由与导航接线 `✅ 已完成`

文件：

- `client/pubspec.yaml`
- `client/lib/app/app_router.dart`
- `client/lib/features/messages/presentation/messages_placeholder_page.dart`
- `client/lib/features/home/presentation/main_shell_page.dart`
- `client/modules/flash_im_friend/lib/src/view/contacts_page.dart`
- `client/modules/flash_im_friend/lib/flash_im_friend.dart`

改动类型：`配置 + 修改文件`

### 8.1 消息页入口 `✅`

消息头部新增“+”菜单和“发起群聊”；创建成功后由 `MainShellPage` 刷新会话列表并调用现有 `_openChat`。

### 8.2 通讯录群聊入口 `✅`

在“新的朋友”附近增加“群聊”入口，回调交给宿主打开我的群聊页；不得改变好友申请红点计算。

### 8.3 路由接线 `✅`

增加创建群聊、我的群聊、单聊详情的 typed arguments；从单聊创建成功后把当前 Chat 路由替换为新群 Chat 路由。

### 8.4 package 接入 `✅`

宿主 `pubspec.yaml` 增加 `flash_im_group` path 依赖；不新增 Repository 注入。

## 任务 9：客户端回归测试 `✅ 已完成`

文件：

- `client/modules/flash_im_friend/test/contacts_page_test.dart`
- `client/test/features/main_shell/presentation/main_shell_page_test.dart`
- 任务 1～7 中列出的新增/修改测试文件

改动类型：`新增 + 修改测试`

### 9.1 验收覆盖 `✅`

- 从消息页创建并打开群聊。
- 从单聊打开详情、锁定原对端、再选好友创建新群。
- 通讯录进入我的群聊、搜索并打开群聊。
- 群会话显示组合头像和群名。
- 现有私聊消息、好友申请红点和通讯录好友点击行为不回归。

## 最后：客户端 Harness Check `✅ 已完成`

### 10.1 格式、测试、覆盖率与静态扫描 `✅`

按模块执行小批量命令，避免依赖解析长时间占用：

```bash
cd client/modules/flash_im_conversation && dart format --set-exit-if-changed lib test && flutter test --coverage && flutter analyze
cd client/modules/flash_im_group && dart format --set-exit-if-changed lib test && flutter test --coverage && flutter analyze
cd client/modules/flash_im_chat && flutter test test/chat_page_test.dart --coverage && flutter analyze
cd client/modules/flash_im_friend && flutter test test/contacts_page_test.dart --coverage && flutter analyze
cd client && flutter test test/features/main_shell/presentation/main_shell_page_test.dart --coverage && flutter analyze
```

### 10.2 Harness 报告 `✅`

最终结果：客户端最终 Harness attempt 6 `PASS`，变更生产代码覆盖率 87.40%；测试 Agent 与架构 Agent attempt 5 均 `PASS`。

- 每次 attempt 使用新目录并记录变更清单、测试输出、lcov 与 analyze 输出。
- 合并本次客户端变更生产代码覆盖率，阈值不得低于 80%；报告缺失或过期均为 `INCOMPLETE`。
