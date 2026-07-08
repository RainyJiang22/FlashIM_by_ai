# IM Core v0.0.3 — 客户端任务清单

基于 [design.md](./design.md) 设计，拆分 `client/` 侧聊天页、消息收发、会话列表联动和共享头像组件的实现步骤。目标是让用户从会话列表进入聊天页，加载历史消息，通过 WebSocket 发送/接收文本消息，并让会话列表和底部消息角标实时更新。

全局约束：
- 本清单只覆盖客户端文本消息闭环：聊天页、历史消息查询、`CHAT_MESSAGE` 发送/接收、`MESSAGE_ACK` 状态确认、`CONVERSATION_UPDATE` 会话列表联动、进入聊天页本地清零未读数。
- 不实现设计文档“暂不实现”范围：图片/文件/语音消息、消息撤回、已读回执、消息搜索、本地 SQLite 缓存、新消息浮层、消息发送失败重试、消息长按菜单。
- 状态管理继续使用 Cubit，不引入 Event 模式。
- 网络请求继续复用主 app 的认证 Dio：`DioFactory.create(baseUrl: config.apiBaseUrl)` + Bearer token 拦截器。
- Protobuf 源文件继续以项目根目录 `proto/` 为准，生成的 Dart 文件提交在 `client/modules/flash_im_core/lib/src/data/proto/`；不要在 client 模块复制一份 proto 源文件。
- `flash_im_chat` 和 `flash_im_conversation` 通过 `flash_shared` 使用头像组件，不再直接依赖 `flash_session`。
- 当前后端 `MESSAGE_ACK` 不返回 `client_id`，客户端需要按发送顺序匹配本地 sending 消息；不要把 `client_id` 去重或 ACK 精确匹配做成本版本依赖。
- server patch1 已提供 `GET /conversations/{id}`；未加载会话收到 `CONVERSATION_UPDATE` 时先插入骨架会话，再异步按 id 补全，不能阻塞帧处理。
- 参考现有文件：`client/modules/flash_im_core/lib/src/logic/ws_client.dart` 的连接认证流程、`client/modules/flash_im_conversation/*` 的 package 分层、`client/lib/app/flash_im_app.dart` 的依赖注入、`client/lib/features/home/presentation/main_shell_page.dart` 的 WebSocket 生命周期。

---

## 执行顺序

1. ✅ 任务 1 — `client/modules/flash_shared/` 新建共享 UI package（无依赖）
   - ✅ 1.1 创建 package 结构
   - ✅ 1.2 配置基础依赖和 lint
2. ✅ 任务 2 — `client/modules/flash_shared/lib/src/identicon_avatar.dart` 抽出 identicon 头像（依赖任务 1）
   - ✅ 2.1 迁移 `IdenticonAvatar`
   - ✅ 2.2 公开 `IdenticonPainter`
3. ✅ 任务 3 — `client/modules/flash_shared/lib/src/avatar_widget.dart` 新增统一头像入口（依赖任务 2）
   - ✅ 3.1 支持 `identicon:` 格式
   - ✅ 3.2 支持 `http(s)://` 图片
   - ✅ 3.3 支持空头像占位
4. ✅ 任务 4 — `client/modules/flash_shared/lib/flash_shared.dart` 新增 barrel 导出（依赖任务 2、3）
   - ✅ 4.1 导出头像组件
5. ✅ 任务 5 — `client/modules/flash_im_conversation/pubspec.yaml` 改为依赖 `flash_shared`（依赖任务 4）
   - ✅ 5.1 移除 `flash_session`
   - ✅ 5.2 新增 `flash_shared`
6. ✅ 任务 6 — `client/modules/flash_im_conversation/lib/src/view/conversation_tile.dart` 改用 `AvatarWidget` 并支持未读红点（依赖任务 5）
   - ✅ 6.1 替换头像实现
   - ✅ 6.2 渲染未读数
   - ✅ 6.3 保持点击回调
7. ✅ 任务 7 — `client/modules/flash_im_conversation/lib/src/data/conversation.dart` 支持会话更新和骨架会话（依赖任务 6）
   - ✅ 7.1 增加 `copyWith`
   - ✅ 7.2 增加 `placeholder`
   - ✅ 7.3 增加本地未读清零 helper
8. ✅ 任务 8 — `client/modules/flash_im_conversation/lib/src/logic/conversation_list_state.dart` 增加 totalUnread（依赖任务 7）
   - ✅ 8.1 新增 `totalUnread`
   - ✅ 8.2 保持 Equatable props
9. ✅ 任务 9 — `client/modules/flash_im_conversation/lib/src/logic/conversation_list_cubit.dart` 支持 CONVERSATION_UPDATE 和本地清零（依赖任务 8）
   - ✅ 9.1 订阅会话更新流
   - ✅ 9.2 更新或插入会话
   - ✅ 9.3 进入聊天页后清零当前会话未读
10. ✅ 任务 10 — `client/modules/flash_im_conversation/lib/src/view/conversation_list_page.dart` 暴露点击和 Cubit 复用入口（依赖任务 9）
    - ✅ 10.1 支持外部传入 `ConversationListCubit`
    - ✅ 10.2 支持 `onConversationTap`
11. ✅ 任务 11 — `scripts/proto/gen.ps1` 支持生成 ws + message Dart Protobuf（依赖 server 侧 proto 文件）
    - ✅ 11.1 编译 `proto/ws.proto`
    - ✅ 11.2 编译 `proto/message.proto`
12. ✅ 任务 12 — `client/modules/flash_im_core/lib/src/data/proto/*` 重新生成消息协议 Dart 文件（依赖任务 11）
    - ✅ 12.1 更新 `ws.pb*.dart`
    - ✅ 12.2 新增 `message.pb*.dart`
13. ✅ 任务 13 — `client/modules/flash_im_core/lib/src/logic/ws_client.dart` 增加 typed 帧分发（依赖任务 12）
    - ✅ 13.1 增加 `chatMessageStream`
    - ✅ 13.2 增加 `messageAckStream`
    - ✅ 13.3 增加 `conversationUpdateStream`
    - ✅ 13.4 增加 `sendChatMessage`
14. ✅ 任务 14 — `client/modules/flash_im_core/lib/flash_im_core.dart` 导出消息协议和 typed stream API（依赖任务 13）
    - ✅ 14.1 导出 Protobuf 类型
    - ✅ 14.2 导出 WsClient 新方法
15. ✅ 任务 15 — `client/modules/flash_im_chat/` 新建 Flutter package（依赖任务 4、14）
    - ✅ 15.1 创建 package 结构
    - ✅ 15.2 配置 analysis 与目录
16. ✅ 任务 16 — `client/modules/flash_im_chat/pubspec.yaml` 配置聊天模块依赖（依赖任务 15）
    - ✅ 16.1 添加运行依赖
    - ✅ 16.2 添加测试依赖
17. ✅ 任务 17 — `client/modules/flash_im_chat/lib/src/data/message.dart` 新增消息模型（依赖任务 16）
    - ✅ 17.1 定义 `Message`
    - ✅ 17.2 定义 `MessageStatus`
    - ✅ 17.3 实现 HTTP/Protobuf 转换
18. ✅ 任务 18 — `client/modules/flash_im_chat/lib/src/data/message_repository.dart` 新增历史消息仓储（依赖任务 17）
    - ✅ 18.1 定义接口
    - ✅ 18.2 实现 Dio 请求
    - ✅ 18.3 处理 `before_seq` 分页
19. ✅ 任务 19 — `client/modules/flash_im_chat/lib/src/logic/chat_state.dart` 新增聊天状态（依赖任务 17）
    - ✅ 19.1 定义 initial/loading/loaded/error
    - ✅ 19.2 支持分页和发送状态
20. ✅ 任务 20 — `client/modules/flash_im_chat/lib/src/logic/chat_cubit.dart` 新增聊天业务逻辑（依赖任务 13、18、19）
    - ✅ 20.1 加载历史消息
    - ✅ 20.2 发送消息乐观更新
    - ✅ 20.3 ACK 更新 sending -> sent
    - ✅ 20.4 接收对方消息
    - ✅ 20.5 生命周期取消订阅
21. ✅ 任务 21 — `client/modules/flash_im_chat/lib/src/view/message_bubble.dart` 新增消息气泡（依赖任务 17）
    - ✅ 21.1 自己/对方布局
    - ✅ 21.2 sending/failed 状态图标
22. ✅ 任务 22 — `client/modules/flash_im_chat/lib/src/view/chat_input.dart` 新增输入框（依赖任务 20）
    - ✅ 22.1 文本输入
    - ✅ 22.2 发送按钮状态
23. ✅ 任务 23 — `client/modules/flash_im_chat/lib/src/view/chat_page.dart` 新增聊天页（依赖任务 20、21、22）
    - ✅ 23.1 加载骨架屏
    - ✅ 23.2 reverse 列表和上拉加载历史
    - ✅ 23.3 消息不足一屏靠顶显示
24. ✅ 任务 24 — `client/modules/flash_im_chat/lib/flash_im_chat.dart` 新增 barrel 导出（依赖任务 17-23）
    - ✅ 24.1 导出模型/仓储/Cubit/页面
25. ✅ 任务 25 — `client/pubspec.yaml` 接入 `flash_shared` 和 `flash_im_chat`（依赖任务 24）
    - ✅ 25.1 添加 path 依赖
26. ✅ 任务 26 — `client/lib/app/flash_im_app.dart` 注入 `MessageRepository` 并调整主题（依赖任务 18、25）
    - ✅ 26.1 创建认证 Dio 消息仓储
    - ✅ 26.2 支持测试注入
    - ✅ 26.3 按设计更新全局主题
27. ✅ 任务 27 — `client/lib/app/app_router.dart` 新增聊天页路由（依赖任务 23、26）
    - ✅ 27.1 定义 `AppRoutes.chat`
    - ✅ 27.2 定义路由参数
    - ✅ 27.3 创建 `ChatPage`
28. ✅ 任务 28 — `client/lib/features/messages/presentation/messages_placeholder_page.dart` 接入会话点击进入聊天（依赖任务 10、27）
    - ✅ 28.1 传入 `onConversationTap`
    - ✅ 28.2 保留当前用户 header 和连接状态
29. ✅ 任务 29 — `client/lib/features/home/presentation/main_shell_page.dart` 提供全局 ConversationListCubit（依赖任务 9、28）
    - ✅ 29.1 在 MainShell 生命周期创建/关闭 Cubit
    - ✅ 29.2 传给消息页
    - ✅ 29.3 进入聊天页前清零未读
30. ✅ 任务 30 — `client/lib/features/home/presentation/widgets/home_navigation_bar.dart` 显示消息 Tab 未读角标（依赖任务 29）
    - ✅ 30.1 新增 `messageUnreadCount`
    - ✅ 30.2 使用 Badge 展示总未读
31. ✅ 任务 31 — 测试覆盖聊天和会话联动（依赖任务 1-30）
    - ✅ 31.1 `flash_shared` 头像测试
    - ✅ 31.2 `flash_im_core` 帧分发测试
    - ✅ 31.3 `flash_im_chat` 模型/仓储/Cubit/widget 测试
    - ✅ 31.4 主壳层聊天路由和未读角标测试
32. ✅ 最后 — 依赖安装、格式化、分析和测试验证（依赖任务 1-31）
    - ✅ 32.1 `cd client/modules/flash_shared && flutter pub get && flutter analyze && flutter test`
    - ✅ 32.2 `pwsh scripts/proto/gen.ps1 && cd client/modules/flash_im_core && dart format lib test && flutter analyze && flutter test`
    - ✅ 32.3 `cd client/modules/flash_im_conversation && flutter pub get && dart format lib test && flutter analyze && flutter test`
    - ✅ 32.4 `cd client/modules/flash_im_chat && flutter pub get && dart format lib test && flutter analyze && flutter test`
    - ✅ 32.5 `cd client && flutter pub get && dart format lib test && flutter analyze lib test`
    - ✅ 32.6 `cd client && flutter test test/features/main_shell/presentation/main_shell_page_test.dart`

---

## 任务 1：`client/modules/flash_shared/` — 新建共享 UI package `✅ 已完成`

文件：`client/modules/flash_shared/`

改动类型：`新建`

### 1.1 创建 package 结构 `✅`

命令骨架：

```bash
cd client/modules
flutter create --template=package flash_shared
```

目标结构：

```text
client/modules/flash_shared/
├── lib/
│   ├── flash_shared.dart
│   └── src/
│       ├── identicon_avatar.dart
│       └── avatar_widget.dart
└── test/
```

### 1.2 配置 package 元信息 `✅`

关键 YAML 骨架：

```yaml
name: flash_shared
description: "Flash IM shared UI package."
publish_to: none
environment:
  sdk: ^3.11.5
  flutter: ">=1.17.0"
dependencies:
  flutter:
    sdk: flutter
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

说明：
- `flash_shared` 只放跨业务 UI，不引用 `flash_session`、`flash_im_chat` 或 `flash_im_conversation`。

---

## 任务 2：`client/modules/flash_shared/lib/src/identicon_avatar.dart` — 抽出 identicon 头像 `✅ 已完成`

文件：`client/modules/flash_shared/lib/src/identicon_avatar.dart`

改动类型：`新建`

### 2.1 迁移 IdenticonAvatar `✅`

参考文件：`client/modules/flash_session/lib/src/view/widget/identicon_avatar.dart`

关键 Dart 骨架：

```dart
class IdenticonAvatar extends StatelessWidget {
  const IdenticonAvatar({
    super.key,
    required this.seed,
    this.size = 48,
    this.borderRadius,
  });

  final String seed;
  final double size;
  final BorderRadius? borderRadius;
}
```

### 2.2 公开 IdenticonPainter `✅`

关键 Dart 骨架：

```dart
class IdenticonPainter extends CustomPainter {
  const IdenticonPainter(this.seed);

  final String seed;

  @override
  void paint(Canvas canvas, Size size);

  @override
  bool shouldRepaint(covariant IdenticonPainter oldDelegate);
}
```

说明：
- 当前 `flash_session` 中的 `_IdenticonPainter` 是私有类，迁移到 shared 后改为公开类，便于组件测试和复用。

---

## 任务 3：`client/modules/flash_shared/lib/src/avatar_widget.dart` — 新增统一头像入口 `✅ 已完成`

文件：`client/modules/flash_shared/lib/src/avatar_widget.dart`

改动类型：`新建`

### 3.1 定义 AvatarWidget `✅`

关键 Dart 骨架：

```dart
class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    required this.avatar,
    required this.seed,
    this.size = 48,
    this.borderRadius,
  });

  final String? avatar;
  final String seed;
  final double size;
  final BorderRadius? borderRadius;
}
```

### 3.2 支持三类头像 `✅`

逻辑步骤：
1. `avatar == null || avatar.trim().isEmpty`：显示 `IdenticonAvatar(seed: seed)`。
2. `avatar.startsWith('identicon:')`：截取后缀作为 seed，显示 `IdenticonAvatar`。
3. `avatar.startsWith('http://') || avatar.startsWith('https://')`：显示 `Image.network`，失败回退 identicon。
4. 其他字符串：作为 seed 显示 identicon。

说明：
- `ConversationTile` 和 `MessageBubble` 都使用该组件，避免重复头像判断。

---

## 任务 4：`client/modules/flash_shared/lib/flash_shared.dart` — 新增 barrel 导出 `✅ 已完成`

文件：`client/modules/flash_shared/lib/flash_shared.dart`

改动类型：`新建`

### 4.1 导出共享组件 `✅`

关键 Dart 骨架：

```dart
library;

export 'src/avatar_widget.dart' show AvatarWidget;
export 'src/identicon_avatar.dart' show IdenticonAvatar, IdenticonPainter;
```

---

## 任务 5：`client/modules/flash_im_conversation/pubspec.yaml` — 改为依赖 flash_shared `✅ 已完成`

文件：`client/modules/flash_im_conversation/pubspec.yaml`

改动类型：`配置修改`

### 5.1 替换业务依赖 `✅`

关键 YAML 骨架：

```yaml
dependencies:
  flash_shared:
    path: ../flash_shared
```

说明：
- 删除 `flash_session` 依赖。
- `flash_im_conversation` 不应再 import `package:flash_session/flash_session.dart`。

---

## 任务 6：`client/modules/flash_im_conversation/lib/src/view/conversation_tile.dart` — 改用 AvatarWidget 并支持未读红点 `✅ 已完成`

文件：`client/modules/flash_im_conversation/lib/src/view/conversation_tile.dart`

改动类型：`修改`

### 6.1 替换头像实现 `✅`

关键 Dart 骨架：

```dart
import 'package:flash_shared/flash_shared.dart';

AvatarWidget(
  avatar: conversation.peerAvatar,
  seed: conversation.avatarSeed,
  size: 48,
  borderRadius: BorderRadius.circular(8),
)
```

### 6.2 渲染未读数 `✅`

关键 Widget 骨架：

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.end,
  children: [
    Text(_formatConversationTime(conversation.displayTime)),
    if (conversation.unreadCount > 0)
      _UnreadBadge(count: conversation.unreadCount),
  ],
)
```

说明：
- 99 以上显示 `99+`。
- 未读数为 0 时不占位。

---

## 任务 7：`client/modules/flash_im_conversation/lib/src/data/conversation.dart` — 支持会话更新和骨架会话 `✅ 已完成`

文件：`client/modules/flash_im_conversation/lib/src/data/conversation.dart`

改动类型：`修改`

### 7.1 增加 copyWith `✅`

关键 Dart 骨架：

```dart
Conversation copyWith({
  int? unreadCount,
  DateTime? lastMessageAt,
  String? lastMessagePreview,
  String? peerNickname,
  String? peerAvatar,
});
```

### 7.2 增加 placeholder `✅`

关键 Dart 骨架：

```dart
factory Conversation.placeholder({
  required String id,
  required String lastMessagePreview,
  required DateTime lastMessageAt,
  required int unreadCount,
}) {
  return Conversation(
    id: id,
    type: 0,
    unreadCount: unreadCount,
    createdAt: lastMessageAt,
    lastMessageAt: lastMessageAt,
    lastMessagePreview: lastMessagePreview,
  );
}
```

说明：
- 用于未加载到内存的会话收到 `CONVERSATION_UPDATE` 时先插入骨架。

---

## 任务 8：`client/modules/flash_im_conversation/lib/src/logic/conversation_list_state.dart` — 增加 totalUnread `✅ 已完成`

文件：`client/modules/flash_im_conversation/lib/src/logic/conversation_list_state.dart`

改动类型：`修改`

### 8.1 给 Loaded 状态增加总未读 `✅`

关键 Dart 骨架：

```dart
final class ConversationListLoaded extends ConversationListState {
  const ConversationListLoaded({
    required this.conversations,
    required this.hasMore,
    this.totalUnread = 0,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final int totalUnread;
}
```

说明：
- `totalUnread` 由 `conversations.fold<int>(0, ...)` 计算，避免调用方重复计算。

---

## 任务 9：`client/modules/flash_im_conversation/lib/src/logic/conversation_list_cubit.dart` — 支持 CONVERSATION_UPDATE 和本地清零 `✅ 已完成`

文件：`client/modules/flash_im_conversation/lib/src/logic/conversation_list_cubit.dart`

改动类型：`修改`

### 9.1 注入 WsClient 并订阅会话更新 `✅`

关键 Dart 骨架：

```dart
ConversationListCubit({
  required ConversationRepository repository,
  WsClient? wsClient,
  int pageSize = 20,
}) : _wsClient = wsClient,
     super(const ConversationListInitial()) {
  _conversationUpdateSubscription =
      _wsClient?.conversationUpdateStream.listen(applyConversationUpdate);
}

StreamSubscription<ConversationUpdate>? _conversationUpdateSubscription;
```

### 9.2 更新或插入会话 `✅`

关键 Dart 骨架：

```dart
void applyConversationUpdate(ConversationUpdate update) {
  // 1. 当前不是 Loaded 时忽略或缓存
  // 2. 找到 conversationId 则 copyWith preview/time/unread
  // 3. 找不到则 Conversation.placeholder(...)
  // 4. 按 displayTime DESC 重新排序
}
```

### 9.3 本地清零未读 `✅`

关键 Dart 骨架：

```dart
void markConversationReadLocally(String conversationId) {
  // 1. 找到目标会话
  // 2. unreadCount 置 0
  // 3. 重新计算 totalUnread
}
```

### 9.4 关闭订阅 `✅`

关键 Dart 骨架：

```dart
@override
Future<void> close() async {
  await _conversationUpdateSubscription?.cancel();
  return super.close();
}
```

---

## 任务 10：`client/modules/flash_im_conversation/lib/src/view/conversation_list_page.dart` — 暴露点击和 Cubit 复用入口 `✅ 已完成`

文件：`client/modules/flash_im_conversation/lib/src/view/conversation_list_page.dart`

改动类型：`修改`

### 10.1 支持外部 Cubit `✅`

关键 Dart 骨架：

```dart
class ConversationListPage extends StatelessWidget {
  const ConversationListPage({
    super.key,
    this.cubit,
    this.onConversationTap,
  });

  final ConversationListCubit? cubit;
  final ValueChanged<Conversation>? onConversationTap;
}
```

### 10.2 传递点击事件 `✅`

关键 Dart 骨架：

```dart
ConversationTile(
  conversation: conversations[index],
  onTap: () => onConversationTap?.call(conversations[index]),
)
```

说明：
- 如果外部没有传入 Cubit，保留现有内部创建 Cubit 的能力，方便 package 独立测试。

---

## 任务 11：`scripts/proto/gen.ps1` — 支持生成 ws + message Dart Protobuf `✅ 已完成`

文件：`scripts/proto/gen.ps1`

改动类型：`修改`

### 11.1 编译多个 proto 文件 `✅`

关键 PowerShell 骨架：

```powershell
$ProtoFiles = @(
  (Join-Path $RepoRoot "proto/ws.proto"),
  (Join-Path $RepoRoot "proto/message.proto")
)

& $Protoc `
  --proto_path=$ProtoDir `
  --dart_out=$OutDir `
  $ProtoFiles
```

说明：
- 当前脚本只生成 `ws.proto`，本版本需要同时生成 `message.pb.dart`。

---

## 任务 12：`client/modules/flash_im_core/lib/src/data/proto/*` — 重新生成消息协议 Dart 文件 `✅ 已完成`

文件：
- `client/modules/flash_im_core/lib/src/data/proto/ws.pb.dart`
- `client/modules/flash_im_core/lib/src/data/proto/ws.pbenum.dart`
- `client/modules/flash_im_core/lib/src/data/proto/ws.pbjson.dart`
- `client/modules/flash_im_core/lib/src/data/proto/message.pb.dart`
- `client/modules/flash_im_core/lib/src/data/proto/message.pbenum.dart`
- `client/modules/flash_im_core/lib/src/data/proto/message.pbjson.dart`

改动类型：`生成/修改`

### 12.1 执行生成 `✅`

命令骨架：

```bash
pwsh scripts/proto/gen.ps1
```

说明：
- 生成代码不要手写。
- 如果本机缺少 `protoc-gen-dart`，按脚本提示执行 `dart pub global activate protoc_plugin`。

---

## 任务 13：`client/modules/flash_im_core/lib/src/logic/ws_client.dart` — 增加 typed 帧分发 `✅ 已完成`

文件：`client/modules/flash_im_core/lib/src/logic/ws_client.dart`

改动类型：`修改`

### 13.1 增加 typed StreamController `✅`

关键 Dart 骨架：

```dart
final _chatMessageController = StreamController<ChatMessage>.broadcast();
final _messageAckController = StreamController<MessageAck>.broadcast();
final _conversationUpdateController =
    StreamController<ConversationUpdate>.broadcast();

Stream<ChatMessage> get chatMessageStream => _chatMessageController.stream;
Stream<MessageAck> get messageAckStream => _messageAckController.stream;
Stream<ConversationUpdate> get conversationUpdateStream =>
    _conversationUpdateController.stream;
```

### 13.2 分发新增帧类型 `✅`

关键 Dart 骨架：

```dart
switch (frame.type) {
  case WsFrameType.CHAT_MESSAGE:
    _chatMessageController.add(ChatMessage.fromBuffer(frame.payload));
  case WsFrameType.MESSAGE_ACK:
    _messageAckController.add(MessageAck.fromBuffer(frame.payload));
  case WsFrameType.CONVERSATION_UPDATE:
    _conversationUpdateController.add(
      ConversationUpdate.fromBuffer(frame.payload),
    );
  // 保留 AUTH_RESULT/PONG/PING 现有处理
}
```

### 13.3 增加 sendChatMessage `✅`

关键 Dart 骨架：

```dart
void sendChatMessage(SendMessageRequest request) {
  sendFrame(
    WsFrame(
      type: WsFrameType.CHAT_MESSAGE,
      payload: request.writeToBuffer(),
    ),
  );
}
```

### 13.4 dispose 时关闭新 controller `✅`

关键 Dart 骨架：

```dart
await _chatMessageController.close();
await _messageAckController.close();
await _conversationUpdateController.close();
```

---

## 任务 14：`client/modules/flash_im_core/lib/flash_im_core.dart` — 导出消息协议和 typed stream API `✅ 已完成`

文件：`client/modules/flash_im_core/lib/flash_im_core.dart`

改动类型：`修改`

### 14.1 导出 Protobuf 消息类型 `✅`

关键 Dart 骨架：

```dart
export 'src/data/proto/message.pb.dart'
    show ChatMessage, ConversationUpdate, MessageAck, SendMessageRequest;
export 'src/data/proto/ws.pb.dart' show WsFrame, WsFrameType;
```

说明：
- `flash_im_chat` 不应 import `flash_im_core/src/...` 私有路径。

---

## 任务 15：`client/modules/flash_im_chat/` — 新建 Flutter package `✅ 已完成`

文件：`client/modules/flash_im_chat/`

改动类型：`新建`

### 15.1 创建 package 结构 `✅`

命令骨架：

```bash
cd client/modules
flutter create --template=package flash_im_chat
```

目标结构：

```text
client/modules/flash_im_chat/
├── lib/
│   ├── flash_im_chat.dart
│   └── src/
│       ├── data/
│       │   ├── message.dart
│       │   └── message_repository.dart
│       ├── logic/
│       │   ├── chat_cubit.dart
│       │   └── chat_state.dart
│       └── view/
│           ├── chat_page.dart
│           ├── message_bubble.dart
│           └── chat_input.dart
└── test/
```

---

## 任务 16：`client/modules/flash_im_chat/pubspec.yaml` — 配置聊天模块依赖 `✅ 已完成`

文件：`client/modules/flash_im_chat/pubspec.yaml`

改动类型：`配置修改`

### 16.1 添加运行依赖 `✅`

关键 YAML 骨架：

```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.9.0
  equatable: ^2.0.7
  flutter_bloc: ^9.1.1
  shimmer: ^3.0.0
  flash_im_core:
    path: ../flash_im_core
  flash_im_conversation:
    path: ../flash_im_conversation
  flash_shared:
    path: ../flash_shared
```

### 16.2 添加测试依赖 `✅`

关键 YAML 骨架：

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  bloc_test: ^10.0.0
  flutter_lints: ^6.0.0
  mocktail: ^1.0.4
```

---

## 任务 17：`client/modules/flash_im_chat/lib/src/data/message.dart` — 新增消息模型 `✅ 已完成`

文件：`client/modules/flash_im_chat/lib/src/data/message.dart`

改动类型：`新建`

### 17.1 定义 MessageStatus 和 Message `✅`

关键 Dart 骨架：

```dart
enum MessageStatus { sending, sent, failed }

class Message extends Equatable {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.seq,
    required this.content,
    required this.status,
    required this.createdAt,
    this.senderAvatar,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final int seq;
  final String content;
  final MessageStatus status;
  final DateTime createdAt;
}
```

### 17.2 实现转换方法 `✅`

关键 Dart 骨架：

```dart
factory Message.fromJson(Map<String, dynamic> json);
factory Message.fromChatMessage(ChatMessage message);
Message copyWith({String? id, int? seq, MessageStatus? status});
```

说明：
- HTTP 字段 `msg_type` 本版本只接受文本类型 `0`，其他类型可忽略或显示占位文案。
- 本地发送中的消息 `seq = 0`，`id = local:<timestamp>`。

---

## 任务 18：`client/modules/flash_im_chat/lib/src/data/message_repository.dart` — 新增历史消息仓储 `✅ 已完成`

文件：`client/modules/flash_im_chat/lib/src/data/message_repository.dart`

改动类型：`新建`

### 18.1 定义接口和 Dio 实现 `✅`

关键 Dart 骨架：

```dart
abstract interface class MessageRepository {
  Future<List<Message>> getMessages({
    required String conversationId,
    int? beforeSeq,
    int limit = 50,
  });
}

class DioMessageRepository implements MessageRepository {
  DioMessageRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;
}
```

### 18.2 请求历史消息 `✅`

关键 Dart 骨架：

```dart
final response = await _dio.get<List<dynamic>>(
  '/conversations/$conversationId/messages',
  queryParameters: {
    if (beforeSeq != null) 'before_seq': beforeSeq,
    'limit': limit,
  },
);
```

说明：
- 后端按 `seq DESC` 返回，Cubit 入状态前需要整理成按 `seq ASC` 展示。

---

## 任务 19：`client/modules/flash_im_chat/lib/src/logic/chat_state.dart` — 新增聊天状态 `✅ 已完成`

文件：`client/modules/flash_im_chat/lib/src/logic/chat_state.dart`

改动类型：`新建`

### 19.1 定义状态 `✅`

关键 Dart 骨架：

```dart
sealed class ChatState extends Equatable {
  const ChatState();
}

final class ChatInitial extends ChatState { const ChatInitial(); }
final class ChatLoading extends ChatState { const ChatLoading(); }

final class ChatLoaded extends ChatState {
  const ChatLoaded({
    required this.messages,
    required this.hasMore,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final List<Message> messages;
  final bool hasMore;
  final bool isLoadingMore;
  final String? errorMessage;
}

final class ChatError extends ChatState {
  const ChatError(this.message);
  final String message;
}
```

---

## 任务 20：`client/modules/flash_im_chat/lib/src/logic/chat_cubit.dart` — 新增聊天业务逻辑 `✅ 已完成`

文件：`client/modules/flash_im_chat/lib/src/logic/chat_cubit.dart`

改动类型：`新建`

### 20.1 构造依赖和订阅 `✅`

关键 Dart 骨架：

```dart
class ChatCubit extends Cubit<ChatState> {
  ChatCubit({
    required MessageRepository repository,
    required WsClient wsClient,
    required Conversation conversation,
    required String currentUserId,
  });

  StreamSubscription<ChatMessage>? _chatMessageSubscription;
  StreamSubscription<MessageAck>? _messageAckSubscription;
  final Queue<String> _pendingLocalIds = Queue<String>();
}
```

### 20.2 加载历史消息 `✅`

关键 Dart 骨架：

```dart
Future<void> loadMessages() async {
  // 1. emit ChatLoading
  // 2. repository.getMessages(conversationId)
  // 3. 按 seq ASC 排序
  // 4. emit ChatLoaded(messages, hasMore)
}
```

### 20.3 发送消息乐观更新 `✅`

关键 Dart 骨架：

```dart
void sendText(String content) {
  // 1. trim 空内容直接返回
  // 2. 创建 local Message(status: sending, seq: 0)
  // 3. 加入 _pendingLocalIds 队列
  // 4. emit 追加后的 ChatLoaded
  // 5. wsClient.sendChatMessage(SendMessageRequest(...))
  // 6. 启动 ACK 超时，超时标记 failed
}
```

说明：
- 本版本不做失败重试，但可以标记 `failed`。
- 由于 ACK 不带 `client_id`，按 `_pendingLocalIds.removeFirst()` 匹配最早一条 sending 消息。

### 20.4 处理 ACK 和对方消息 `✅`

关键 Dart 骨架：

```dart
void _handleAck(MessageAck ack) {
  // 找到最早 sending 消息，替换 id/seq/status=sent
}

void _handleIncomingMessage(ChatMessage message) {
  // 只处理当前 conversationId
  // senderId == currentUserId 时跳过，避免和 ACK 产生重复
  // 追加并按 seq ASC 排序
}
```

### 20.5 加载更多历史 `✅`

关键 Dart 骨架：

```dart
Future<void> loadMore() async {
  // beforeSeq = 当前最小非 0 seq
  // 获取更早消息后 prepend
}
```

---

## 任务 21：`client/modules/flash_im_chat/lib/src/view/message_bubble.dart` — 新增消息气泡 `✅ 已完成`

文件：`client/modules/flash_im_chat/lib/src/view/message_bubble.dart`

改动类型：`新建`

### 21.1 实现气泡布局 `✅`

关键 Widget 骨架：

```dart
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
  });

  final Message message;
  final bool isMine;
}
```

布局要求：
- 外层垂直间距 8。
- 自己发的消息右对齐，背景 `#3B82F6`，白色文字，右下角 4px。
- 对方消息左对齐，背景 `#F0F0F0`，黑色文字，左下角 4px。
- 对方消息显示昵称和 36px `AvatarWidget`。
- `sending` 显示 12px `CircularProgressIndicator`。
- `failed` 显示 14px 红色感叹号。

---

## 任务 22：`client/modules/flash_im_chat/lib/src/view/chat_input.dart` — 新增输入框 `✅ 已完成`

文件：`client/modules/flash_im_chat/lib/src/view/chat_input.dart`

改动类型：`新建`

### 22.1 实现输入框和发送按钮 `✅`

关键 Widget 骨架：

```dart
class ChatInput extends StatefulWidget {
  const ChatInput({super.key, required this.onSend});

  final ValueChanged<String> onSend;
}
```

布局要求：
- 底部白色背景，顶部 1px 分割线。
- `TextField` 支持多行，最多 4 行。
- 文本为空时发送按钮 disabled。
- 点击发送后清空输入框并调用 `onSend`。

---

## 任务 23：`client/modules/flash_im_chat/lib/src/view/chat_page.dart` — 新增聊天页 `✅ 已完成`

文件：`client/modules/flash_im_chat/lib/src/view/chat_page.dart`

改动类型：`新建`

### 23.1 定义页面参数 `✅`

关键 Dart 骨架：

```dart
class ChatPage extends StatelessWidget {
  const ChatPage({
    super.key,
    required this.conversation,
    required this.currentUserId,
  });

  final Conversation conversation;
  final String currentUserId;
}
```

### 23.2 构建页面结构 `✅`

关键 Widget 骨架：

```dart
Scaffold(
  appBar: AppBar(title: Text(conversation.displayName)),
  body: AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Container(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(child: _MessageList()),
          ChatInput(onSend: context.read<ChatCubit>().sendText),
        ],
      ),
    ),
  ),
)
```

### 23.3 消息列表规则 `✅`

实现要求：
- 使用 `ListView(reverse: true)`，视觉上最新消息在底部。
- 数据层按 `seq ASC` 保存，渲染时反转。
- 往上滚动接近顶部时触发 `loadMore()`。
- 消息数量 `<= 15` 时使用 `shrinkWrap + Align(alignment: Alignment.topCenter)`，避免消息少时贴底。
- loading 使用 shimmer 骨架，不使用全屏空白。

---

## 任务 24：`client/modules/flash_im_chat/lib/flash_im_chat.dart` — 新增 barrel 导出 `✅ 已完成`

文件：`client/modules/flash_im_chat/lib/flash_im_chat.dart`

改动类型：`新建`

### 24.1 导出模块 API `✅`

关键 Dart 骨架：

```dart
library;

export 'src/data/message.dart' show Message, MessageStatus;
export 'src/data/message_repository.dart'
    show DioMessageRepository, MessageRepository;
export 'src/logic/chat_cubit.dart' show ChatCubit;
export 'src/logic/chat_state.dart'
    show ChatError, ChatInitial, ChatLoaded, ChatLoading, ChatState;
export 'src/view/chat_page.dart' show ChatPage;
```

---

## 任务 25：`client/pubspec.yaml` — 接入 flash_shared 和 flash_im_chat `✅ 已完成`

文件：`client/pubspec.yaml`

改动类型：`配置修改`

### 25.1 添加 path 依赖 `✅`

关键 YAML 骨架：

```yaml
dependencies:
  flash_shared:
    path: modules/flash_shared
  flash_im_chat:
    path: modules/flash_im_chat
```

---

## 任务 26：`client/lib/app/flash_im_app.dart` — 注入 MessageRepository 并调整主题 `✅ 已完成`

文件：`client/lib/app/flash_im_app.dart`

改动类型：`修改`

### 26.1 增加 MessageRepository 注入 `✅`

关键 Dart 骨架：

```dart
class FlashImApp extends StatefulWidget {
  const FlashImApp({
    super.key,
    this.messageRepository,
  });

  final MessageRepository? messageRepository;
}
```

### 26.2 创建默认仓储并提供给子树 `✅`

关键 Dart 骨架：

```dart
final messageRepository =
    widget.messageRepository ??
    (_defaultMessageRepository ??= DioMessageRepository(
      dio: _createAuthenticatedDio(
        baseUrl: config.apiBaseUrl,
        sessionCubit: sessionCubit,
      ),
    ));

RepositoryProvider<MessageRepository>.value(value: messageRepository),
```

### 26.3 按设计更新全局主题 `✅`

关键主题骨架：

```dart
const appBackgroundColor = Color(0xFFEDEDED);
const appPrimaryColor = Color(0xFF3B82F6);

appBarTheme: const AppBarTheme(
  backgroundColor: appBackgroundColor,
  elevation: 0,
  scrolledUnderElevation: 0,
  surfaceTintColor: Colors.transparent,
  centerTitle: true,
  titleTextStyle: TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: Colors.black,
  ),
)
```

说明：
- 主题调整要检查现有登录、启动、我的页的可读性，不做无关 UI 重构。

---

## 任务 27：`client/lib/app/app_router.dart` — 新增聊天页路由 `✅ 已完成`

文件：`client/lib/app/app_router.dart`

改动类型：`修改`

### 27.1 定义路由和参数 `✅`

关键 Dart 骨架：

```dart
abstract final class AppRoutes {
  static const chat = '/chat';
}

class ChatRouteArguments {
  const ChatRouteArguments({
    required this.conversation,
    required this.currentUserId,
  });

  final Conversation conversation;
  final String currentUserId;
}
```

### 27.2 创建 ChatPage `✅`

关键 Dart 骨架：

```dart
case AppRoutes.chat:
  final args = settings.arguments! as ChatRouteArguments;
  return MaterialPageRoute<void>(
    builder: (_) => ChatPage(
      conversation: args.conversation,
      currentUserId: args.currentUserId,
    ),
    settings: settings,
  );
```

说明：
- `ChatPage` 内部读取 `MessageRepository` 和 `WsClient`，不在 route 中手动 new 仓储。

---

## 任务 28：`client/lib/features/messages/presentation/messages_placeholder_page.dart` — 接入会话点击进入聊天 `✅ 已完成`

文件：`client/lib/features/messages/presentation/messages_placeholder_page.dart`

改动类型：`修改`

### 28.1 增加参数 `✅`

关键 Dart 骨架：

```dart
class MessagesPlaceholderPage extends StatelessWidget {
  const MessagesPlaceholderPage({
    super.key,
    required this.conversationListCubit,
    required this.onConversationTap,
  });

  final ConversationListCubit conversationListCubit;
  final ValueChanged<Conversation> onConversationTap;
}
```

### 28.2 传给列表页 `✅`

关键 Dart 骨架：

```dart
Expanded(
  child: ConversationListPage(
    cubit: conversationListCubit,
    onConversationTap: onConversationTap,
  ),
)
```

说明：
- 保留当前 header 的用户昵称、签名和 WebSocket 连接状态展示。

---

## 任务 29：`client/lib/features/home/presentation/main_shell_page.dart` — 提供全局 ConversationListCubit `✅ 已完成`

文件：`client/lib/features/home/presentation/main_shell_page.dart`

改动类型：`修改`

### 29.1 创建和关闭 Cubit `✅`

关键 Dart 骨架：

```dart
late final ConversationListCubit _conversationListCubit;

@override
void initState() {
  super.initState();
  _conversationListCubit = ConversationListCubit(
    repository: context.read<ConversationRepository>(),
    wsClient: context.read<WsClient>(),
  )..loadConversations();
}

@override
void dispose() {
  _conversationListCubit.close();
  super.dispose();
}
```

### 29.2 点击进入聊天页并清零未读 `✅`

关键 Dart 骨架：

```dart
Future<void> _openChat(Conversation conversation) async {
  _conversationListCubit.markConversationReadLocally(conversation.id);
  await Navigator.of(context).pushNamed(
    AppRoutes.chat,
    arguments: ChatRouteArguments(
      conversation: conversation.copyWith(unreadCount: 0),
      currentUserId: '${context.read<SessionCubit>().state.session!.accountId}',
    ),
  );
}
```

说明：
- 本版本是本地清零，不调用已读回执接口。

### 29.3 页面构建使用动态消息页 `✅`

关键 Dart 骨架：

```dart
MessagesPlaceholderPage(
  conversationListCubit: _conversationListCubit,
  onConversationTap: _openChat,
)
```

说明：
- 当前 `_pages` 是 static const，需要改成 build 内动态创建或私有方法返回。

---

## 任务 30：`client/lib/features/home/presentation/widgets/home_navigation_bar.dart` — 显示消息 Tab 未读角标 `✅ 已完成`

文件：`client/lib/features/home/presentation/widgets/home_navigation_bar.dart`

改动类型：`修改`

### 30.1 增加 unread 入参 `✅`

关键 Dart 骨架：

```dart
class HomeNavigationBar extends StatelessWidget {
  const HomeNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    this.messageUnreadCount = 0,
  });

  final int messageUnreadCount;
}
```

### 30.2 包装消息 icon `✅`

关键 Widget 骨架：

```dart
Widget _messageIcon(IconData icon) {
  if (messageUnreadCount <= 0) {
    return Icon(icon, size: 30);
  }
  return Badge(
    label: Text(messageUnreadCount > 99 ? '99+' : '$messageUnreadCount'),
    child: Icon(icon, size: 30),
  );
}
```

说明：
- `MainShellPage` 用 `BlocBuilder<ConversationListCubit, ConversationListState>` 或 `ValueListenable` 等方式把 `totalUnread` 传入。

---

## 任务 31：测试覆盖聊天和会话联动 `✅ 已完成`

文件：
- `client/modules/flash_shared/test/avatar_widget_test.dart`
- `client/modules/flash_im_core/test/ws_client_test.dart`
- `client/modules/flash_im_core/test/proto_compile_test.dart`
- `client/modules/flash_im_conversation/test/conversation_list_cubit_test.dart`
- `client/modules/flash_im_chat/test/message_test.dart`
- `client/modules/flash_im_chat/test/message_repository_test.dart`
- `client/modules/flash_im_chat/test/chat_cubit_test.dart`
- `client/modules/flash_im_chat/test/chat_page_test.dart`
- `client/test/features/main_shell/presentation/main_shell_page_test.dart`

改动类型：`新建/修改`

### 31.1 flash_shared 测试 `✅`

关键测试骨架：

```dart
testWidgets('AvatarWidget renders identicon fallback', (tester) async {
  await tester.pumpWidget(const MaterialApp(
    home: AvatarWidget(avatar: null, seed: '10001'),
  ));
  expect(find.byType(CustomPaint), findsOneWidget);
});
```

### 31.2 WsClient 帧分发测试 `✅`

关键测试骨架：

```dart
test('dispatches message ack to typed stream', () async {
  final events = <MessageAck>[];
  final sub = client.messageAckStream.listen(events.add);
  channel.addFrame(WsFrame(
    type: WsFrameType.MESSAGE_ACK,
    payload: MessageAck(messageId: 'm1', seq: 1).writeToBuffer(),
  ));
  expect(events.single.seq, 1);
  await sub.cancel();
});
```

### 31.3 ChatCubit 测试 `✅`

覆盖点：
- 首屏历史加载成功。
- 发送消息立即出现 sending。
- 收到 ACK 后第一条 pending 消息变为 sent。
- 收到其他用户 `CHAT_MESSAGE` 后追加。
- 非当前会话消息被忽略。

### 31.4 主壳层测试 `✅`

覆盖点：
- 会话列表点击后 push `/chat`。
- 进入聊天页后当前会话未读数本地清零。
- 底部消息 Tab 角标随 `totalUnread` 更新。

---

## 最后：依赖安装、格式化、分析和测试验证 `✅ 已完成`

文件：`client/`、`client/modules/*`

改动类型：`验证`

### 32.1 共享模块验证 `✅`

执行命令：

```bash
cd client/modules/flash_shared
flutter pub get
dart format lib test
flutter analyze
flutter test
```

### 32.2 核心协议模块验证 `✅（代码验证通过，生成命令受本机工具链限制未执行）`

执行命令：

```bash
pwsh scripts/proto/gen.ps1
cd client/modules/flash_im_core
dart format lib test
flutter analyze
flutter test
```

### 32.3 会话模块验证 `✅`

执行命令：

```bash
cd client/modules/flash_im_conversation
flutter pub get
dart format lib test
flutter analyze
flutter test
```

### 32.4 聊天模块验证 `✅`

执行命令：

```bash
cd client/modules/flash_im_chat
flutter pub get
dart format lib test
flutter analyze
flutter test
```

### 32.5 主应用验证 `✅`

执行命令：

```bash
cd client
flutter pub get
dart format lib test
flutter analyze lib test
flutter test test/features/main_shell/presentation/main_shell_page_test.dart
```

验收结果记录：
- `cd client/modules/flash_shared && flutter analyze && flutter test`：通过，2 个测试通过。
- `pwsh scripts/proto/gen.ps1`：未执行成功，本机缺少 `pwsh`；同时 `command -v protoc` 为空，仅存在 `~/.pub-cache/bin/protoc-gen-dart`。已更新脚本输入范围，并提交 `message.pb*.dart` / `ws.pb*.dart` 侧改动，使用 core 测试验证协议编码和 typed frame 分发。
- `cd client/modules/flash_im_core && flutter pub get && dart format lib test && flutter analyze && flutter test`：通过，10 个测试通过。
- `cd client/modules/flash_im_conversation && flutter analyze && flutter test`：通过，11 个测试通过。
- `cd client/modules/flash_im_chat && dart format test/chat_cubit_test.dart && flutter analyze && flutter test`：通过，9 个测试通过。
- `cd client && flutter pub get && dart format lib test && flutter analyze lib test`：通过。
- `cd client && flutter test test/features/main_shell/presentation/main_shell_page_test.dart`：通过，1 个测试通过。
