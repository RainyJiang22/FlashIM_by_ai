# 搜索加群与入群审批 — 客户端任务清单

基于 [design.md](./design.md) 实现 `flash_im_group` v0.0.3。

全局约束：使用 Cubit；`flash_im_friend` 不依赖 group；宿主负责 callback/Repository/WsClient 接线；复用 GroupDetailsPage；群聊 UI 参考 `/Users/rainyjiang/Downloads/群聊设计图` 的信息层级并使用当前 Flash IM 主题/组件；不运行 Gradle/Android 或 Xcode/iOS 构建。

## 执行顺序

1. ✅ 任务 1 — 生成客户端 protobuf 并扩展 WsClient（无依赖）
2. ✅ 任务 2 — 群搜索/申请模型与 Repository（依赖任务 1）
3. ✅ 任务 3 — 搜索状态与页面（依赖任务 2）
4. ✅ 任务 4 — 群通知状态与页面（依赖任务 1、2）
5. ✅ 任务 5 — friend 模块入口参数（依赖任务 3、4）
6. ✅ 任务 6 — 宿主生命周期和路由接线（依赖任务 3-5）
7. ✅ 任务 7 — 既有群详情文案扩展（依赖任务 2）
8. ✅ 任务 8 — Core/Group/Friend/Host 测试（依赖任务 1-7）
9. 🟨 最后 — Harness Check：测试、新鲜覆盖率 ≥80%、format/analyze（依赖任务 8；执行中被用户叫停）

## 任务 1：客户端协议与 WsClient `✅ 已完成`

文件：`client/modules/flash_im_core/lib/src/data/proto/group.pb*.dart`、`ws.pb*.dart`、`client/modules/flash_im_core/lib/src/logic/ws_client.dart`、`flash_im_core.dart`；改动类型：生成 + 修改。

### 1.1 生成并导出协议 `✅`

从仓库 `proto/group.proto`、`proto/ws.proto` 生成 Dart 文件，保留既有字段编号。

### 1.2 分发入群事件 `✅`

增加 broadcast controller/getter/dispose，`GROUP_JOIN_REQUEST` 解码为 `GroupJoinRequestNotification`。

## 任务 2：模型与 Repository `✅ 已完成`

文件：`client/modules/flash_im_group/lib/src/data/group_discovery.dart`、`group_repository.dart`、`flash_im_group.dart`、`pubspec.yaml`；改动类型：新建 + 修改配置。

### 2.1 不可变模型和 JSON `✅`

定义 `GroupSearchItem`、`JoinGroupResult`、`GroupJoinRequestStatus`、`GroupJoinRequest`、`GroupJoinRequestList`。

### 2.2 REST 方法 `✅`

实现 `searchGroups/joinGroup/getJoinRequests/handleJoinRequest`，统一复用 GroupRequestException。

## 任务 3：搜索 Cubit 与页面 `✅ 已完成`

文件：`client/modules/flash_im_group/lib/src/logic/group_search_{state,cubit}.dart`、`lib/src/view/search_group_page.dart`、`lib/src/view/widgets/group_search_result_tile.dart`；改动类型：新建。

### 3.1 防乱序搜索状态 `✅`

请求带 generation，旧响应不得覆盖新关键词；加入成功只更新目标 item。

### 3.2 四态 UI 与对话框 `✅`

300ms Timer 防抖；空关键词显示引导；结果行按参考图排列群头像、群名、人数/群号与右侧状态；已加入/已申请禁用；加入为主题色实心按钮、申请为 warning 描边按钮。申请 Dialog 按参考图展示群摘要、留言、`字符数/200` 和取消/发送申请；直接加入使用简化确认框。

## 任务 4：通知 Cubit 与页面 `✅ 已完成`

文件：`client/modules/flash_im_group/lib/src/logic/group_notification_{state,cubit}.dart`、`lib/src/view/group_notifications_page.dart`、`lib/src/view/widgets/group_join_request_tile.dart`；改动类型：新建。

### 4.1 HTTP 回源 + WS 增量 `✅`

构造时订阅 stream；load 获取 pendingCount；pending 事件按 id 去重插入；close 取消订阅。

### 4.2 审批 UI `✅`

按参考图用扁平列表行展示申请者头像、申请加入的群、留言；pending 显示文字拒绝和主题色同意按钮，请求中禁用；成功以服务端 item 替换并减角标；已处理只读。

## 任务 5：friend 模块扩展 `✅ 已完成`

文件：`client/modules/flash_im_friend/lib/src/view/add_friend_page.dart`、`contacts_page.dart`；改动类型：修改。

### 5.1 搜索群入口 callback `✅`

`AddFriendPage` 标题改为“加好友/群”，新增 `onSearchGroups` callback 卡片，不导入 group 包。

### 5.2 群通知入口与角标 `✅`

`ContactsPage` 接收 `groupNotificationCount/onOpenGroupNotifications`，在“新的朋友”和“群聊”之间展示“群通知”。

## 任务 6：宿主接线 `✅ 已完成`

文件：`client/lib/features/home/presentation/main_shell_page.dart`；改动类型：修改。

### 6.1 生命周期 `✅`

创建 `GroupNotificationCubit(repository, wsClient)..load()`，dispose 时 close；通过 BlocProvider.value 暴露。

### 6.2 页面导航和会话刷新 `✅`

从 AddFriendPage push SearchGroupPage；直接加入成功后刷新会话；ContactsPage push GroupNotificationsPage 并显示 Cubit pendingCount。

## 任务 7：群详情语义 `✅ 已完成`

文件：`client/modules/flash_im_group/lib/src/view/group_details_page.dart`；改动类型：修改。

### 7.1 开关文案 `✅`

保留 key、权限、回滚和接口，按参考图增加“群号”只读行；标题改为“入群验证”，说明同时覆盖成员邀请和用户主动申请。成员网格、群名、危险操作仍沿用当前页面组件与间距。

## 任务 8：客户端测试 `✅ 已完成`

文件：

- `client/modules/flash_im_core/test/ws_client_test.dart`
- `client/modules/flash_im_group/test/group_{repository,search_cubit,search_page,notification_cubit,notifications_page}_test.dart`
- `client/modules/flash_im_friend/test/{add_friend_page,contacts_page}_test.dart`
- `client/test/features/main_shell/presentation/main_shell_page_test.dart`

改动类型：新增 + 修改测试。

### 8.1 协议/Repository/Cubit `✅`

覆盖帧解码、JSON、四接口、搜索乱序、四态变更、WS 去重、审批失败和 close 取消订阅。

### 8.2 Widget/宿主回归 `✅`

覆盖 300ms 防抖、确认/留言、审批按钮、角标、AddFriend callback、Contacts entry、MainShell Cubit 生命周期和加入后刷新；保留好友/群详情原行为。

## 最后：客户端 Harness Check `🟨 未完成（执行中被用户叫停）`

```bash
cd client/modules/flash_im_core && dart format --set-exit-if-changed lib test && flutter test --coverage && flutter analyze
cd client/modules/flash_im_group && dart format --set-exit-if-changed lib test && flutter test --coverage && flutter analyze
cd client/modules/flash_im_friend && dart format --set-exit-if-changed lib test && flutter test --coverage && flutter analyze
cd client && dart format --set-exit-if-changed lib test && flutter test --coverage && flutter analyze
```

每次使用新 attempt 目录汇总 changed coverage，要求本次生产代码不低于 80%。

## 验证记录

- ✅ Core 测试 13 项、Group 全量测试 28 项、Friend 测试 12 项、宿主路由/MainShell 定向测试 5 项通过。
- ✅ 后续新增的搜索异常/并发/WS 状态与群通知拒绝/加载态定向测试 8 项通过。
- ✅ Core、Group、Friend analyzer 无问题；宿主 analyzer 退出码为 0，仅保留 5 条既有 `flash_session` info。
- 🟨 Harness attempt-02 的静态检查通过，但 changed coverage 为 77.89%，未达到 80%；补测后的 attempt-03 被用户叫停，不能标记 Harness 通过。
