# 群聊详情与成员邀请 — 客户端任务清单

基于 [design.md](./design.md) 实现 `flash_im_group` v0.0.2。

全局约束：

- 使用 Cubit，不引入 Event 模式；页面增长部分拆到同级 `widgets/`。
- `flash_im_group` 不依赖 `flash_im_chat` 或宿主；邀请卡片接受通过 callback 上抛。
- 群主增删、解散和邀请确认都以服务端响应为准；失败保留页面并提供中文反馈。
- 保留 v0.0.1 建群、群列表、私聊详情、好友红点、消息发送和媒体预览行为。
- 不实现拒绝邀请、群主转让、成员主动退出、管理员、群公告或邀请链接。
- 不运行 Gradle/Android 或 Xcode/iOS 构建；使用定向 Dart/Flutter 检查和测试。

---

## 执行顺序

1. ✅ 任务 1 — 群详情模型与 Repository（无依赖）
2. ✅ 任务 2 — 群详情 Cubit/State（依赖任务 1）
3. ✅ 任务 3 — 群成员网格、群名编辑与详情页（依赖任务 2）
4. ✅ 任务 4 — 群成员好友选择页（依赖任务 1、3）
5. ✅ 任务 5 — 群包依赖、导出和宿主 Repository 注入（依赖任务 1-4）
6. ✅ 任务 6 — 邀请卡片消息模型和气泡（依赖任务 1）
7. ✅ 任务 7 — ChatPage 群详情入口与标题热更新（依赖任务 6）
8. ✅ 任务 8 — 群详情/邀请接受路由与首页刷新（依赖任务 5、7）
9. ✅ 任务 9 — 首页可扩展锚点快捷菜单（无业务依赖）
10. ✅ 任务 10 — Repository、Cubit、Widget 与宿主回归测试（依赖任务 1-9）
11. ✅ 最后 — 客户端 Harness Check：格式、测试、新鲜覆盖率 ≥80%、静态扫描（依赖任务 1-10）

---

## 任务 1：群详情模型与 Repository `✅ 已完成`

文件：

- `client/modules/flash_im_group/lib/src/data/group_detail.dart`
- `client/modules/flash_im_group/lib/src/data/group_repository.dart`

改动类型：`新建文件`

### 1.1 定义不可变群模型 `✅`

实现 `GroupMember`、`GroupDetail`、`GroupDetailsResult` 和 JSON 解析；ID 接受字符串或数字，成员列表不可变。

### 1.2 实现 REST 契约 `✅`

```dart
getDetail/updateName/updateSettings/addMembers/removeMember/inviteMembers/acceptInvitation/dissolveGroup
```

统一把 Dio 响应 message 包装为 `GroupRequestException`，供 Cubit 显示。

## 任务 2：群详情状态 `✅ 已完成`

文件：

- `client/modules/flash_im_group/lib/src/logic/group_detail_state.dart`
- `client/modules/flash_im_group/lib/src/logic/group_detail_cubit.dart`

改动类型：`新建文件`

### 2.1 定义服务端快照状态 `✅`

保存 detail、loading/saving/deleteMode/error/dissolved；派生 `isOwner`。

### 2.2 实现加载、改名、设置、增删和解散 `✅`

每次成功直接使用服务端最新 `GroupDetail`；设置失败自动恢复；解散成功发出 dissolved 状态。

## 任务 3：群详情页面与 widgets `✅ 已完成`

文件：

- `client/modules/flash_im_group/lib/src/view/group_details_page.dart`
- `client/modules/flash_im_group/lib/src/view/widgets/group_member_grid.dart`
- `client/modules/flash_im_group/lib/src/view/widgets/group_member_tile.dart`
- `client/modules/flash_im_group/lib/src/view/widgets/group_name_editor.dart`

改动类型：`新建文件`

### 3.1 微信式成员网格 `✅`

成员头像/昵称后追加 `+`；群主再追加 `−`。删除模式为非 owner 成员显示删除角标并二次确认。

### 3.2 群资料设置 `✅`

群名行仅 owner 可编辑；邀请确认开关仅 owner 可操作，普通成员只读展示。

### 3.3 解散危险操作 `✅`

仅 owner 显示红色“解散群聊”，对话框明确后果，成功 `pop(GroupDetailsResult.dissolved)`。

## 任务 4：群成员好友选择页 `✅ 已完成`

文件：`client/modules/flash_im_group/lib/src/view/group_member_picker_page.dart`

改动类型：`新建文件`

### 4.1 复用好友选择视觉 `✅`

加载 `FriendRepository.getFriends()`，过滤已有成员，支持搜索、勾选和已选头像；至少选择 1 人才可提交。

### 4.2 按权限选择提交接口 `✅`

owner 或无需确认调用 `addMembers`；普通成员且需确认调用 `inviteMembers`，成功提示“邀请卡片已发送”。

## 任务 5：群包配置、导出与注入 `✅ 已完成`

文件：

- `client/modules/flash_im_group/pubspec.yaml`
- `client/modules/flash_im_group/lib/flash_im_group.dart`
- `client/lib/app/flash_im_app.dart`

改动类型：`配置 + 修改`

### 5.1 声明 Dio 并导出公共 API `✅`

导出 GroupRepository/DioGroupRepository、模型、Cubit 和页面，不导出私有 widgets。

### 5.2 注入 GroupRepository `✅`

与现有 Dio 实例同生命周期注入 RepositoryProvider，禁止页面自行创建网络客户端。

## 任务 6：群邀请消息和气泡 `✅ 已完成`

文件：

- `client/modules/flash_im_chat/lib/src/data/message.dart`
- `client/modules/flash_im_chat/lib/src/view/bubble/group_invitation_bubble.dart`
- `client/modules/flash_im_chat/lib/src/view/bubble/message_bubble.dart`

改动类型：`新增 + 修改`

### 6.1 解析 `MessageType.groupInvitation` `✅`

数值 4 映射邀请类型，定义安全解析的 `GroupInvitationExtra`；mapToProtoType 保持对称。

### 6.2 展示可操作邀请卡片 `✅`

卡片显示群图标、群名、邀请人和“同意加入”；加载、防重复点击、成功“已加入”和失败重试由卡片本地状态管理。

## 任务 7：ChatPage 群详情和标题更新 `✅ 已完成`

文件：`client/modules/flash_im_chat/lib/src/view/chat_page.dart`

改动类型：`修改文件`

### 7.1 所有会话可按回调显示详情入口 `✅`

`onDetailsTap` 存在即显示右上角，群聊与私聊共用入口视觉。

### 7.2 同群热更新标题 `✅`

详情 callback 返回同 ID Conversation 时只更新 AppBar 展示，不重建 `ChatCubit`。

### 7.3 上抛邀请接受 `✅`

增加 `Future<void> Function(String invitationId)? onAcceptGroupInvitation` 并传给消息列表/气泡。

## 任务 8：路由与首页刷新 `✅ 已完成`

文件：

- `client/lib/app/app_router.dart`
- `client/lib/features/home/presentation/main_shell_page.dart`

改动类型：`修改文件`

### 8.1 注册群详情路由 `✅`

群聊详情返回 updated/dissolved；updated 更新当前聊天标题，dissolved 关闭聊天。

### 8.2 接受邀请后进入群聊 `✅`

调用 `GroupRepository.acceptInvitation`，成功 push 群 ChatPage；重复接受由服务端返回稳定结果或提示。

### 8.3 返回首页刷新会话 `✅`

Chat 路由返回后刷新 `ConversationListCubit`，确保解散群从列表消失。

## 任务 9：首页锚点快捷菜单 `✅ 已完成`

文件：

- `client/lib/features/messages/presentation/messages_placeholder_page.dart`
- `client/lib/features/messages/presentation/widgets/message_quick_actions_menu.dart`

改动类型：`新增 + 修改`

### 9.1 数据化 action 模型 `✅`

```dart
class MessageQuickAction { id, label, icon, onTap }
```

### 9.2 `MenuAnchor` 正下方菜单 `✅`

使用白色圆角、细边框、轻阴影和紧凑行高；以“+”按钮锚定并在下方 8px 展开，当前 action 仅“发起群聊”。

## 任务 10：客户端测试 `✅ 已完成`

文件：

- `client/modules/flash_im_group/test/group_repository_test.dart`
- `client/modules/flash_im_group/test/group_detail_cubit_test.dart`
- `client/modules/flash_im_group/test/group_details_page_test.dart`
- `client/modules/flash_im_group/test/group_member_picker_page_test.dart`
- `client/modules/flash_im_chat/test/message_test.dart`
- `client/modules/flash_im_chat/test/message_bubble_test.dart`
- `client/modules/flash_im_chat/test/chat_page_test.dart`
- `client/test/app/app_router_group_test.dart`
- `client/test/features/main_shell/presentation/main_shell_page_test.dart`

改动类型：`新增 + 修改测试`

### 10.1 Repository/Cubit 覆盖 `✅`

覆盖 JSON、REST 方法/请求体、权限分支、失败回退、删除保护和解散结果。

### 10.2 Widget/路由覆盖 `✅`

覆盖成员网格末尾 +/−、群主编辑/设置/解散、普通成员邀请、邀请卡片同意、群详情标题更新、解散返回首页。

### 10.3 首页菜单回归 `✅`

断言菜单相对入口位于下方、视觉容器和数据化“发起群聊”入口可点击；保留连接状态和原有建群导航。

## 最后：客户端 Harness Check `✅ 已完成`

```bash
cd client/modules/flash_im_group && dart format --set-exit-if-changed lib test && flutter test --coverage && flutter analyze
cd client/modules/flash_im_chat && dart format --set-exit-if-changed lib test && flutter test --coverage && flutter analyze
cd client && dart format --set-exit-if-changed lib test && flutter test --coverage && flutter analyze
```

使用新 attempt 目录记录变更生产代码、新鲜 lcov、测试和 analyze 输出；本次变更生产代码覆盖率必须不低于 80%。
