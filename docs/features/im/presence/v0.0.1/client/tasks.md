# 在线状态与已读回执 — 客户端任务清单

基于 [design.md](./design.md) 执行。状态管理继续使用现有 Cubit；在线集合跟随应用级 `WsClient`，列表项只接收展示参数；不实现最后在线时间、隐私开关、后台推送或逐像素可见曝光。

---

## 执行顺序

1. ✅ 任务 1 — 生成并导出客户端 protobuf（依赖服务端任务 1）
2. ✅ 任务 2 — 扩展 WsClient 在线集合与回执流（依赖任务 1）
3. ✅ 任务 3 — 扩展消息模型和已读详情 Repository（依赖服务端接口）
4. ✅ 任务 4 — ChatCubit 防抖上报和回执合并（依赖任务 2、3）
5. ✅ 任务 5 — 聊天页在线状态与已读 UI（依赖任务 3、4）
6. ✅ 任务 6 — 单聊会话在线绿点（依赖任务 2）
7. ✅ 任务 7 — 通讯录在线绿点（依赖任务 2）
8. ✅ 任务 8 — App/MainShell 接线（依赖任务 5～7）
9. ✅ 任务 9 — Flutter 单元与 Widget 测试（依赖任务 1～8）
10. ✅ 任务 10 — Harness Check、覆盖率与静态扫描（依赖全部任务）

---

## 任务 1：`flash_im_core` protobuf — 生成新协议 `✅ 已完成`

文件：`client/modules/flash_im_core/lib/src/data/proto/*.dart`、`client/modules/flash_im_core/lib/flash_im_core.dart`；改动类型：新建 + 修改。

### 1.1 生成文件 `✅`

使用仓库根 `proto/ws.proto`、`proto/message.proto`、`proto/presence.proto` 生成 Dart 文件，不手改 wire 编解码逻辑。

### 1.2 公共导出 `✅`

导出 `UserPresenceEvent`、`OnlineUserList`、`ReadReceipt` 和新增帧枚举。

## 任务 2：`ws_client.dart` — typed streams 与在线集合 `✅ 已完成`

文件：`client/modules/flash_im_core/lib/src/logic/ws_client.dart`；改动类型：修改。

### 2.1 Stream 与发送 API `✅`

```dart
Stream<UserPresenceEvent> get userPresenceStream;
Stream<OnlineUserList> get onlineListStream;
Stream<ReadReceipt> get readReceiptStream;
bool sendReadReceipt({required String conversationId, required int readSeq});
```

### 2.2 在线集合 `✅`

以 `ValueNotifier<Set<int>>` 保存在线用户；列表替换、事件增删、断开清空，所有 Set 对外不可变。

## 任务 3：消息模型与 Repository `✅ 已完成`

文件：`client/modules/flash_im_chat/lib/src/data/message.dart`、`client/modules/flash_im_chat/lib/src/data/read_receipt.dart`、`client/modules/flash_im_chat/lib/src/data/message_repository.dart`、`client/modules/flash_im_chat/lib/flash_im_chat.dart`；改动类型：新建 + 修改。

### 3.1 消息字段 `✅`

`Message` 增加 `readCount`，从历史 JSON 和实时 protobuf 解析，`copyWith` 可更新。

### 3.2 详情 DTO 与接口 `✅`

定义 `ReadStatusMember/MessageReadStatus`，Repository 调用 read-status HTTP 并严格校验响应。

## 任务 4：`chat_cubit.dart` — 已读上报与合并 `✅ 已完成`

文件：`client/modules/flash_im_chat/lib/src/logic/chat_cubit.dart`；改动类型：修改。

### 4.1 防抖上报 `✅`

历史成功和当前会话新消息上屏后，取最大正数 seq，重置 1 秒 Timer；只有 `sendReadReceipt=true` 才推进 `_lastReportedReadSeq`。

### 4.2 重连重试与清理 `✅`

订阅 `WsConnectionState.authenticated` 重试；close 时取消 Timer 和新增订阅。

### 4.3 实时回执 `✅`

按 `previous_read_seq < seq <= read_seq` 增加本人已发送消息 readCount，忽略当前用户自己的回执和其他会话。

## 任务 5：聊天在线状态与已读 UI `✅ 已完成`

文件：`client/modules/flash_im_chat/lib/src/view/chat_page.dart`、`client/modules/flash_im_chat/lib/src/view/bubble/message_bubble.dart`、`client/modules/flash_im_chat/lib/src/view/message_read_status_sheet.dart`；改动类型：新建 + 修改。

### 5.1 单聊标题 `✅`

单聊标题使用 `ValueListenableBuilder<Set<int>>` 显示“在线/离线”；群聊保持原标题。

### 5.2 消息回执 `✅`

本人已发送的单聊消息在 `readCount > 0` 时显示“已读”；群聊始终显示“{N} 人已读”并可点击。

### 5.3 详情 BottomSheet `✅`

双 Tab 展示已读/未读成员，包含加载、错误重试和空状态；通过 `MessageRepository.getReadStatus` 回源。

## 任务 6：会话列表在线绿点 `✅ 已完成`

文件：`client/modules/flash_im_conversation/lib/src/view/conversation_list_page.dart`、`client/modules/flash_im_conversation/lib/src/view/conversation_tile.dart`；改动类型：修改。

### 6.1 参数下发 `✅`

页面接收在线 ID Set，单聊使用 `peerUserId` 命中；群聊永不显示。

### 6.2 视觉 `✅`

头像右下角 12px `0xFF07C160` 绿点，2px 白边。

## 任务 7：通讯录在线绿点 `✅ 已完成`

文件：`client/modules/flash_im_friend/lib/src/view/contacts_page.dart`、`client/modules/flash_im_friend/lib/src/view/widgets/friend_avatar_tile.dart`；改动类型：修改。

### 7.1 参数下发与视觉 `✅`

通讯录页面接收在线 Set，FriendAvatarTile 接收 `isOnline` 并复用 12px 绿点规范。

## 任务 8：App/MainShell 接线 `✅ 已完成`

文件：`client/lib/features/home/presentation/main_shell_page.dart`、`client/lib/app/app_router.dart`；改动类型：修改。

### 8.1 首页监听 `✅`

使用应用级 `WsClient.onlineUserIds` 页面级监听，将 Set 传给消息与通讯录页面。

### 8.2 聊天路由 `✅`

ChatPage 复用同一 WsClient 的在线集合与已读流，不创建第二个连接或状态实例。

## 任务 9：客户端测试 `✅ 已完成`

文件：`client/modules/flash_im_core/test/ws_client_test.dart`、`client/modules/flash_im_chat/test/{message,chat_cubit,message_bubble,chat_page}_test.dart`、`client/modules/flash_im_conversation/test/conversation_test.dart`、`client/modules/flash_im_friend/test/*`、`client/test/features/main_shell/presentation/main_shell_page_test.dart`；改动类型：修改。

### 9.1 单元测试 `✅`

覆盖在线列表替换、上下线幂等、断开清空、回执发送、历史 readCount 解析、Timer 防抖、重连重试和回执区间更新。

### 9.2 Widget 测试 `✅`

覆盖好友/会话绿点、单聊标题、单聊已读、群聊人数、详情双 Tab 和错误重试。

## 任务 10：客户端质量门禁 `✅ 已完成`

文件：`docs/features/im/presence/v0.0.1/quality/`；改动类型：新建报告。

### 10.1 验证命令 `✅`

```bash
flutter test modules/flash_im_core/test
flutter test modules/flash_im_chat/test
flutter test modules/flash_im_conversation/test
flutter test modules/flash_im_friend/test
flutter analyze
```

### 10.2 Harness `✅`

运行新 attempt 的客户端测试、fresh changed-production coverage（阈值 80%）与静态扫描，并记录报告路径。
