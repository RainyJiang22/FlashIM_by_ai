# im-core v0.0.2 — 客户端任务清单

基于 [design.md](./design.md) 设计，拆分 `client/` 侧会话列表模块、数据访问、Cubit 状态、消息 Tab 接入和测试步骤。目标是让登录后的消息 Tab 从占位页切换为真实 `GET /conversations?limit=20&offset=0` 会话列表，并支持下拉刷新与滚动分页。

全局约束：
- 本清单只覆盖客户端会话列表闭环：模型解析、仓储请求、Cubit 加载/刷新/分页、列表 UI、主应用依赖注入、消息 Tab 接入。
- 设计文档中“创建私聊会话”流程、创建/删除相关测试与“暂不实现”存在范围冲突；本清单以 `暂不实现` 为准，不实现创建会话入口、`POST /conversations`、删除会话、左滑删除或置顶。
- 不实现点击会话进入聊天页、未读数红点展示、WebSocket 实时会话更新；`unreadCount` 只在模型中保留，不在 UI 高亮显示。
- 状态管理使用 Cubit，不引入 Event 模式。
- 网络请求复用主 app 已有 `DioFactory.create(baseUrl: config.apiBaseUrl)`，由现有 token 注入链路负责认证。
- 当前真实接入点是 `client/lib/app/flash_im_app.dart`、`client/lib/features/home/presentation/main_shell_page.dart` 和 `client/lib/features/messages/presentation/messages_placeholder_page.dart`，不是单独的裸 `HomePage`。
- 当前已有旧 playground 会话 demo 使用 `GET /conversation` 假数据；本版本新增真实 `GET /conversations`，不复用 playground DTO。
- 新模块 package 名为 `flash_im_conversation`，路径为 `client/modules/flash_im_conversation`。

---

## 执行顺序

1. ✅ 任务 1 — `client/modules/flash_im_conversation/` 新建 Flutter package（无依赖）
   - ✅ 1.1 使用 package 结构创建模块
   - ✅ 1.2 配置 analysis 与基础目录
2. ✅ 任务 2 — `client/modules/flash_im_conversation/pubspec.yaml` 配置依赖（依赖任务 1）
   - ✅ 2.1 添加运行依赖
   - ✅ 2.2 添加测试依赖
3. ✅ 任务 3 — `client/modules/flash_im_conversation/lib/src/data/conversation.dart` 新增会话模型（依赖任务 2）
   - ✅ 3.1 定义字段
   - ✅ 3.2 实现 `fromJson`
   - ✅ 3.3 实现显示字段辅助
4. ✅ 任务 4 — `client/modules/flash_im_conversation/lib/src/data/conversation_repository.dart` 新增仓储（依赖任务 3）
   - ✅ 4.1 定义抽象接口
   - ✅ 4.2 实现 Dio 请求
   - ✅ 4.3 校验响应格式
5. ✅ 任务 5 — `client/modules/flash_im_conversation/lib/src/logic/conversation_list_state.dart` 新增状态定义（依赖任务 3）
   - ✅ 5.1 定义 initial/loading/loaded/error
   - ✅ 5.2 保留刷新与加载更多标记
6. ✅ 任务 6 — `client/modules/flash_im_conversation/lib/src/logic/conversation_list_cubit.dart` 新增列表 Cubit（依赖任务 4、5）
   - ✅ 6.1 实现首屏加载
   - ✅ 6.2 实现下拉刷新
   - ✅ 6.3 实现加载更多与并发锁
   - ✅ 6.4 实现错误处理
7. ✅ 任务 7 — `client/modules/flash_im_conversation/lib/src/view/conversation_tile.dart` 新增单条会话组件（依赖任务 3）
   - ✅ 7.1 渲染头像
   - ✅ 7.2 渲染昵称、预览和时间
   - ✅ 7.3 保持点击占位但不进入聊天页
8. ✅ 任务 8 — `client/modules/flash_im_conversation/lib/src/view/conversation_list_page.dart` 新增列表页（依赖任务 6、7）
   - ✅ 8.1 提供 Cubit 并触发首屏加载
   - ✅ 8.2 渲染 loading/empty/error/loaded 状态
   - ✅ 8.3 实现下拉刷新和滚动加载更多
9. ✅ 任务 9 — `client/modules/flash_im_conversation/lib/flash_im_conversation.dart` 新增 barrel 导出（依赖任务 3-8）
   - ✅ 9.1 导出模型与仓储
   - ✅ 9.2 导出 Cubit 与页面组件
10. ✅ 任务 10 — `client/pubspec.yaml` 接入 `flash_im_conversation` 主应用依赖（依赖任务 9）
    - ✅ 10.1 添加 path 依赖
11. ✅ 任务 11 — `client/lib/app/flash_im_app.dart` 创建并注入会话仓储（依赖任务 10）
    - ✅ 11.1 添加可测试注入参数
    - ✅ 11.2 用 `DioFactory` 创建仓储
    - ✅ 11.3 通过 `RepositoryProvider` 提供仓储
12. ✅ 任务 12 — `client/lib/features/messages/presentation/messages_placeholder_page.dart` 替换为真实会话列表入口（依赖任务 11）
    - ✅ 12.1 引入 `ConversationListPage`
    - ✅ 12.2 保留顶部当前用户与连接状态 header
    - ✅ 12.3 用列表替换“消息页暂未开放”
13. ✅ 任务 13 — `client/test/features/main_shell/presentation/main_shell_page_test.dart` 更新主壳层测试（依赖任务 12）
    - ✅ 13.1 注入 fake 会话仓储
    - ✅ 13.2 验证消息 Tab 渲染会话列表
14. ✅ 任务 14 — `client/modules/flash_im_conversation/test/conversation_test.dart` 新增模型测试（依赖任务 3）
    - ✅ 14.1 验证 JSON 字段映射
    - ✅ 14.2 验证显示名与时间回退
15. ✅ 任务 15 — `client/modules/flash_im_conversation/test/conversation_list_cubit_test.dart` 新增 Cubit 测试（依赖任务 6）
    - ✅ 15.1 验证首屏加载状态
    - ✅ 15.2 验证分页与错误保留已有数据
16. ✅ 任务 16 — `client/modules/flash_im_conversation/test/conversation_api_test.dart` 新增真实 API 集成测试（依赖任务 4）
    - ✅ 16.1 读取测试 token
    - ✅ 16.2 验证第一页、分页、超出范围
17. ✅ 任务 17 — `client/test/login_for_test.dart` 与 `client/test/test_env.dart` 新增测试环境工具（依赖任务 16）
    - ✅ 17.1 登录朱红生成 `.env`
    - ✅ 17.2 读取 baseUrl/token
18. ✅ 最后 — 依赖安装、格式化、分析与测试验证（依赖任务 1-17）
    - ✅ 18.1 `cd client/modules/flash_im_conversation && flutter pub get`
    - ✅ 18.2 `cd client/modules/flash_im_conversation && dart format lib test`
    - ✅ 18.3 `cd client/modules/flash_im_conversation && flutter analyze`
    - ✅ 18.4 `cd client/modules/flash_im_conversation && flutter test`
    - ✅ 18.5 `cd client && flutter pub get`
    - ✅ 18.6 `cd client && dart format lib test`
    - ✅ 18.7 `cd client && flutter analyze lib test`
    - ✅ 18.8 `cd client && flutter test test/features/main_shell/presentation/main_shell_page_test.dart`

---

## 任务 1：`client/modules/flash_im_conversation/` — 新建 Flutter package `✅ 已完成`

文件：`client/modules/flash_im_conversation/`

改动类型：`新建`

### 1.1 创建 package 结构 `✅`

命令骨架：

```bash
cd client/modules
flutter create --template=package flash_im_conversation
```

目标结构：

```text
client/modules/flash_im_conversation/
├── lib/
│   ├── flash_im_conversation.dart
│   └── src/
│       ├── data/
│       ├── logic/
│       └── view/
└── test/
```

### 1.2 清理默认示例文件 `✅`

说明：
- 删除或替换 `lib/flash_im_conversation.dart` 中的模板代码。
- 保留 package 自带 `analysis_options.yaml`，风格对齐 `flash_im_core` / `flash_session`。

---

## 任务 2：`client/modules/flash_im_conversation/pubspec.yaml` — 配置依赖 `✅ 已完成`

文件：`client/modules/flash_im_conversation/pubspec.yaml`

改动类型：`配置修改`

### 2.1 添加运行依赖 `✅`

关键配置骨架：

```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.9.0
  equatable: ^2.0.7
  flutter_bloc: ^9.1.1
  flash_session:
    path: ../flash_session
```

说明：
- `flash_session` 用于复用 `IdenticonAvatar`。
- 如果实现最终不用 `equatable`，可删掉该依赖，但状态值比较测试需要等价替代。

### 2.2 添加测试依赖 `✅`

关键配置骨架：

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  bloc_test: ^10.0.0
  flutter_lints: ^6.0.0
  mocktail: ^1.0.4
```

---

## 任务 3：`client/modules/flash_im_conversation/lib/src/data/conversation.dart` — 新增会话模型 `✅ 已完成`

文件：`client/modules/flash_im_conversation/lib/src/data/conversation.dart`

改动类型：`新建`

### 3.1 定义 Conversation 字段 `✅`

关键代码骨架：

```dart
class Conversation {
  const Conversation({
    required this.id,
    required this.type,
    required this.unreadCount,
    required this.createdAt,
    this.name,
    this.peerUserId,
    this.peerNickname,
    this.peerAvatar,
    this.lastMessageAt,
    this.lastMessagePreview,
  });

  final String id;
  final int type;
  final String? name;
  final String? peerUserId;
  final String? peerNickname;
  final String? peerAvatar;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final int unreadCount;
  final DateTime createdAt;
}
```

### 3.2 实现 fromJson `✅`

关键代码骨架：

```dart
factory Conversation.fromJson(Map<String, dynamic> json) {
  return Conversation(
    id: json['id'] as String,
    type: (json['type'] as num?)?.toInt() ?? 0,
    name: json['name'] as String?,
    peerUserId: json['peer_user_id']?.toString(),
    peerNickname: json['peer_nickname'] as String?,
    peerAvatar: json['peer_avatar'] as String?,
    lastMessageAt: _parseNullableDateTime(json['last_message_at']),
    lastMessagePreview: json['last_message_preview'] as String?,
    unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    createdAt: _parseDateTime(json['created_at']),
  );
}
```

说明：
- 后端字段是 snake_case，Dart 字段是 camelCase。
- `created_at` 缺失或非法时抛出 `FormatException`。

### 3.3 实现显示字段辅助 `✅`

关键代码骨架：

```dart
extension ConversationDisplay on Conversation {
  String get displayName;
  String get displayPreview;
  DateTime get displayTime;
  String get avatarSeed;
  bool get isPrivateChat => type == 0;
}
```

说明：
- 单聊优先显示 `peerNickname`。
- 群聊预留显示 `name`。
- 最后消息为空时显示“暂无消息”。

---

## 任务 4：`client/modules/flash_im_conversation/lib/src/data/conversation_repository.dart` — 新增仓储 `✅ 已完成`

文件：`client/modules/flash_im_conversation/lib/src/data/conversation_repository.dart`

改动类型：`新建`

### 4.1 定义抽象接口 `✅`

关键代码骨架：

```dart
abstract interface class ConversationRepository {
  Future<List<Conversation>> getList({
    int limit = 20,
    int offset = 0,
  });
}
```

### 4.2 实现 Dio 请求 `✅`

关键代码骨架：

```dart
class DioConversationRepository implements ConversationRepository {
  DioConversationRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<List<Conversation>> getList({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _dio.get<dynamic>(
      '/conversations',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return _parseConversationList(response.data);
  }
}
```

### 4.3 校验响应格式 `✅`

关键函数骨架：

```dart
List<Conversation> _parseConversationList(dynamic payload) {
  if (payload is! List) {
    throw const FormatException('Conversation payload is not a list.');
  }
  return payload.map((dynamic item) {
    if (item is! Map) {
      throw const FormatException('Conversation item is not a JSON object.');
    }
    return Conversation.fromJson(Map<String, dynamic>.from(item));
  }).toList(growable: false);
}
```

---

## 任务 5：`client/modules/flash_im_conversation/lib/src/logic/conversation_list_state.dart` — 新增状态定义 `✅ 已完成`

文件：`client/modules/flash_im_conversation/lib/src/logic/conversation_list_state.dart`

改动类型：`新建`

### 5.1 定义列表状态 `✅`

关键代码骨架：

```dart
sealed class ConversationListState extends Equatable {
  const ConversationListState();
}

final class ConversationListInitial extends ConversationListState {}

final class ConversationListLoading extends ConversationListState {}

final class ConversationListLoaded extends ConversationListState {
  const ConversationListLoaded({
    required this.conversations,
    required this.hasMore,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<Conversation> conversations;
  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreError;
}

final class ConversationListError extends ConversationListState {
  const ConversationListError(this.message);

  final String message;
}
```

### 5.2 保留刷新与加载更多标记 `✅`

说明：
- 首屏 loading 使用 `ConversationListLoading`。
- 已有数据的加载更多使用 `ConversationListLoaded.isLoadingMore`，避免整页闪烁。
- 加载更多失败用 `loadMoreError`，不丢弃已有列表。

---

## 任务 6：`client/modules/flash_im_conversation/lib/src/logic/conversation_list_cubit.dart` — 新增列表 Cubit `✅ 已完成`

文件：`client/modules/flash_im_conversation/lib/src/logic/conversation_list_cubit.dart`

改动类型：`新建`

### 6.1 实现首屏加载 `✅`

关键代码骨架：

```dart
class ConversationListCubit extends Cubit<ConversationListState> {
  ConversationListCubit({
    required ConversationRepository repository,
    int pageSize = 20,
  }) : _repository = repository,
       _pageSize = pageSize,
       super(ConversationListInitial());

  final ConversationRepository _repository;
  final int _pageSize;
  bool _isLoadingMore = false;

  Future<void> loadConversations() async {
    emit(ConversationListLoading());
    // getList(limit: _pageSize, offset: 0)
    // emit loaded/error
  }
}
```

### 6.2 实现下拉刷新 `✅`

关键函数骨架：

```dart
Future<void> refresh() async {
  final conversations = await _repository.getList(
    limit: _pageSize,
    offset: 0,
  );
  emit(ConversationListLoaded(
    conversations: conversations,
    hasMore: conversations.length == _pageSize,
  ));
}
```

说明：
- 刷新失败可以 emit `ConversationListError`，如果当前已有数据也可保持 loaded 并暴露错误提示；实现时需测试覆盖。

### 6.3 实现加载更多与并发锁 `✅`

关键函数骨架：

```dart
Future<void> loadMore() async {
  final current = state;
  if (current is! ConversationListLoaded ||
      !current.hasMore ||
      _isLoadingMore) {
    return;
  }

  _isLoadingMore = true;
  emit(current.copyWith(isLoadingMore: true, loadMoreError: null));
  // offset = current.conversations.length
  // append next page
  _isLoadingMore = false;
}
```

### 6.4 实现错误处理 `✅`

关键函数骨架：

```dart
String _readErrorMessage(Object error) {
  if (error is DioException) {
    return '会话列表加载失败，请稍后重试';
  }
  if (error is FormatException) {
    return '会话数据格式异常';
  }
  return '会话列表加载失败';
}
```

说明：
- 错误文案保持简短，不暴露 token 或后端内部异常。

---

## 任务 7：`client/modules/flash_im_conversation/lib/src/view/conversation_tile.dart` — 新增单条会话组件 `✅ 已完成`

文件：`client/modules/flash_im_conversation/lib/src/view/conversation_tile.dart`

改动类型：`新建`

### 7.1 渲染头像 `✅`

关键 Widget 骨架：

```dart
class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    this.onTap,
  });

  final Conversation conversation;
  final VoidCallback? onTap;
}
```

头像逻辑：

```dart
Widget _buildAvatar() {
  final avatar = conversation.peerAvatar;
  if (avatar != null && avatar.startsWith('http')) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(avatar, width: 48, height: 48, fit: BoxFit.cover),
    );
  }
  return IdenticonAvatar(seed: conversation.avatarSeed, size: 48);
}
```

### 7.2 渲染昵称、预览和时间 `✅`

关键 Widget 骨架：

```dart
ListTile(
  leading: _buildAvatar(),
  title: Text(conversation.displayName, maxLines: 1),
  subtitle: Text(conversation.displayPreview, maxLines: 1),
  trailing: Text(_formatConversationTime(conversation.displayTime)),
)
```

说明：
- 时间格式优先简单稳定：今天显示 `HH:mm`，非今天显示 `MM/dd`。
- 不显示未读红点，符合本版本“未读数显示暂不实现”。

### 7.3 保留点击占位 `✅`

说明：
- `onTap` 可传入但默认不做跳转。
- 不新增聊天页路由。

---

## 任务 8：`client/modules/flash_im_conversation/lib/src/view/conversation_list_page.dart` — 新增列表页 `✅ 已完成`

文件：`client/modules/flash_im_conversation/lib/src/view/conversation_list_page.dart`

改动类型：`新建`

### 8.1 提供 Cubit 并触发首屏加载 `✅`

关键 Widget 骨架：

```dart
class ConversationListPage extends StatelessWidget {
  const ConversationListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ConversationListCubit(
        repository: context.read<ConversationRepository>(),
      )..loadConversations(),
      child: const ConversationListView(),
    );
  }
}
```

### 8.2 渲染各状态 `✅`

关键 Widget 骨架：

```dart
BlocBuilder<ConversationListCubit, ConversationListState>(
  builder: (context, state) {
    return switch (state) {
      ConversationListInitial() || ConversationListLoading() => const Center(
        child: CircularProgressIndicator(),
      ),
      ConversationListError(:final message) => _ErrorView(message: message),
      ConversationListLoaded(:final conversations) when conversations.isEmpty =>
        const _EmptyView(),
      ConversationListLoaded() => _ConversationListBody(state: state),
    };
  },
)
```

### 8.3 实现刷新和滚动加载更多 `✅`

关键逻辑骨架：

```dart
NotificationListener<ScrollNotification>(
  onNotification: (notification) {
    if (notification.metrics.extentAfter < 200) {
      context.read<ConversationListCubit>().loadMore();
    }
    return false;
  },
  child: RefreshIndicator(
    onRefresh: context.read<ConversationListCubit>().refresh,
    child: ListView.builder(
      itemCount: conversations.length + (state.hasMore ? 1 : 0),
      itemBuilder: ...
    ),
  ),
)
```

说明：
- 尾部 loading 只在 `hasMore` 或 `isLoadingMore` 时出现。
- 空态也需要可下拉刷新，可用 `AlwaysScrollableScrollPhysics`。

---

## 任务 9：`client/modules/flash_im_conversation/lib/flash_im_conversation.dart` — 新增 barrel 导出 `✅ 已完成`

文件：`client/modules/flash_im_conversation/lib/flash_im_conversation.dart`

改动类型：`修改`

### 9.1 导出模型与仓储 `✅`

关键代码骨架：

```dart
library;

export 'src/data/conversation.dart' show Conversation, ConversationDisplay;
export 'src/data/conversation_repository.dart'
    show ConversationRepository, DioConversationRepository;
```

### 9.2 导出 Cubit 与页面组件 `✅`

关键代码骨架：

```dart
export 'src/logic/conversation_list_cubit.dart' show ConversationListCubit;
export 'src/logic/conversation_list_state.dart'
    show
        ConversationListError,
        ConversationListInitial,
        ConversationListLoaded,
        ConversationListLoading,
        ConversationListState;
export 'src/view/conversation_list_page.dart' show ConversationListPage;
export 'src/view/conversation_tile.dart' show ConversationTile;
```

---

## 任务 10：`client/pubspec.yaml` — 接入主应用依赖 `✅ 已完成`

文件：`client/pubspec.yaml`

改动类型：`配置修改`

### 10.1 添加 path 依赖 `✅`

关键配置骨架：

```yaml
dependencies:
  flash_im_conversation:
    path: modules/flash_im_conversation
```

---

## 任务 11：`client/lib/app/flash_im_app.dart` — 创建并注入会话仓储 `✅ 已完成`

文件：`client/lib/app/flash_im_app.dart`

改动类型：`修改`

### 11.1 添加可测试注入参数 `✅`

关键代码骨架：

```dart
class FlashImApp extends StatefulWidget {
  const FlashImApp({
    super.key,
    this.appConfig,
    this.authRepository,
    this.sessionRepository,
    this.conversationRepository,
    this.sessionCubit,
    this.wsClient,
  });

  final ConversationRepository? conversationRepository;
}
```

### 11.2 用 DioFactory 创建默认仓储 `✅`

关键代码骨架：

```dart
ConversationRepository? _defaultConversationRepository;

final conversationRepository =
    widget.conversationRepository ??
    (_defaultConversationRepository ??= DioConversationRepository(
      dio: DioFactory.create(baseUrl: config.apiBaseUrl),
    ));
```

说明：
- `DioFactory` 已负责 baseUrl；token 注入如需依赖 `SessionCubit`，实现时要与现有 `DioFactory` 能力对齐，不能在会话仓储里硬编码 token。

### 11.3 通过 RepositoryProvider 提供仓储 `✅`

关键代码骨架：

```dart
MultiRepositoryProvider(
  providers: [
    RepositoryProvider<AuthRepository>.value(value: authRepository),
    RepositoryProvider<SessionRepository>.value(value: sessionRepository),
    RepositoryProvider<ConversationRepository>.value(
      value: conversationRepository,
    ),
    RepositoryProvider<WsClient>.value(value: wsClient),
  ],
  child: ...
)
```

---

## 任务 12：`client/lib/features/messages/presentation/messages_placeholder_page.dart` — 接入会话列表 `✅ 已完成`

文件：`client/lib/features/messages/presentation/messages_placeholder_page.dart`

改动类型：`修改`

### 12.1 引入 ConversationListPage `✅`

关键代码骨架：

```dart
import 'package:flash_im_conversation/flash_im_conversation.dart';
```

### 12.2 保留顶部 header `✅`

说明：
- 保留当前用户头像、昵称、签名和 WebSocket 连接状态展示。
- `_MessagesHeader` 可继续留在当前文件，避免扩大主壳层改动范围。

### 12.3 替换占位正文 `✅`

关键代码骨架：

```dart
return Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    _MessagesHeader(...),
    const Expanded(child: ConversationListPage()),
  ],
);
```

说明：
- 删除或不再显示 `消息页暂未开放`。
- 只替换消息 Tab 内容，不改通讯录和我的 Tab。

---

## 任务 13：`client/test/features/main_shell/presentation/main_shell_page_test.dart` — 更新主壳层测试 `✅ 已完成`

文件：`client/test/features/main_shell/presentation/main_shell_page_test.dart`

改动类型：`修改`

### 13.1 注入 fake 会话仓储 `✅`

关键代码骨架：

```dart
MultiRepositoryProvider(
  providers: [
    RepositoryProvider<WsClient>.value(value: wsClient),
    RepositoryProvider<ConversationRepository>.value(
      value: _FakeConversationRepository(),
    ),
  ],
  child: ...
)
```

fake 仓储骨架：

```dart
class _FakeConversationRepository implements ConversationRepository {
  @override
  Future<List<Conversation>> getList({int limit = 20, int offset = 0}) async {
    return [
      Conversation(
        id: 'conversation-1',
        type: 0,
        peerUserId: '10002',
        peerNickname: '橘橙',
        unreadCount: 0,
        createdAt: DateTime(2026, 3, 29),
        lastMessageAt: DateTime(2026, 3, 29, 9, 12),
        lastMessagePreview: '今天的接口联调先看会话列表。',
      ),
    ];
  }
}
```

### 13.2 验证消息 Tab 渲染列表 `✅`

关键断言骨架：

```dart
expect(find.text('Rainy'), findsOneWidget);
expect(find.text('已连接'), findsOneWidget);
expect(find.text('橘橙'), findsOneWidget);
expect(find.text('今天的接口联调先看会话列表。'), findsOneWidget);
expect(find.text('消息页暂未开放'), findsNothing);
```

---

## 任务 14：`client/modules/flash_im_conversation/test/conversation_test.dart` — 新增模型测试 `✅ 已完成`

文件：`client/modules/flash_im_conversation/test/conversation_test.dart`

改动类型：`新建`

### 14.1 验证 JSON 字段映射 `✅`

关键测试骨架：

```dart
test('Conversation.fromJson maps backend snake_case payload', () {
  final conversation = Conversation.fromJson({
    'id': 'uuid-1',
    'type': 0,
    'name': null,
    'peer_user_id': '3',
    'peer_nickname': '橘橙',
    'peer_avatar': 'identicon:3',
    'last_message_at': '2026-03-29T09:12:00Z',
    'last_message_preview': '你好',
    'unread_count': 0,
    'created_at': '2026-03-29T08:00:00Z',
  });

  expect(conversation.peerNickname, '橘橙');
});
```

### 14.2 验证显示名与时间回退 `✅`

关键测试骨架：

```dart
test('display fields fallback for empty private conversation', () {
  final conversation = Conversation(...);
  expect(conversation.displayName, isNotEmpty);
  expect(conversation.displayPreview, '暂无消息');
  expect(conversation.displayTime, conversation.createdAt);
});
```

---

## 任务 15：`client/modules/flash_im_conversation/test/conversation_list_cubit_test.dart` — 新增 Cubit 测试 `✅ 已完成`

文件：`client/modules/flash_im_conversation/test/conversation_list_cubit_test.dart`

改动类型：`新建`

### 15.1 验证首屏加载状态 `✅`

关键测试骨架：

```dart
blocTest<ConversationListCubit, ConversationListState>(
  'loadConversations emits loading then loaded',
  build: () => ConversationListCubit(
    repository: _FakeConversationRepository(firstPage: conversations),
  ),
  act: (cubit) => cubit.loadConversations(),
  expect: () => [
    isA<ConversationListLoading>(),
    isA<ConversationListLoaded>(),
  ],
);
```

### 15.2 验证分页与错误保留已有数据 `✅`

关键测试用例：
- 返回条数 `< pageSize` 时 `hasMore=false`。
- 返回条数 `== pageSize` 时 `hasMore=true`。
- `loadMore` 追加列表并使用当前长度作为 offset。
- `hasMore=false` 时不再请求。
- `loadMore` 失败时仍保留已有 conversations。

---

## 任务 16：`client/modules/flash_im_conversation/test/conversation_api_test.dart` — 新增真实 API 集成测试 `✅ 已完成`

文件：`client/modules/flash_im_conversation/test/conversation_api_test.dart`

改动类型：`新建`

### 16.1 读取测试 token `✅`

关键代码骨架：

```dart
import '../../../test/test_env.dart' as test_env;

void main() {
  final env = test_env.readTestEnvOrSkip();
  final dio = DioFactory.create(baseUrl: env.baseUrl);
  dio.options.headers['Authorization'] = 'Bearer ${env.token}';
}
```

说明：
- 如果跨 package 相对 import 不稳定，可在 `flash_im_conversation/test/` 下复制轻量读取函数，但 token 文件仍放在 `client/test/.env`。

### 16.2 验证列表分页 `✅`

关键测试骨架：

```dart
test('fetches first page conversations', () async {
  final repository = DioConversationRepository(dio: dio);
  final conversations = await repository.getList(limit: 20, offset: 0);
  expect(conversations, hasLength(20));
  expect(conversations.first.peerNickname, isNotEmpty);
});

test('fetches all seeded conversations without duplicate ids', () async {
  final first = await repository.getList(limit: 20, offset: 0);
  final second = await repository.getList(limit: 20, offset: 20);
  final third = await repository.getList(limit: 20, offset: 40);
  final ids = [...first, ...second, ...third].map((e) => e.id).toSet();
  expect(ids.length, 51);
});
```

说明：
- 不写创建会话幂等和删除会话测试。

---

## 任务 17：`client/test/login_for_test.dart` 与 `client/test/test_env.dart` — 新增测试环境工具 `✅ 已完成`

文件：`client/test/login_for_test.dart`、`client/test/test_env.dart`、`client/test/.env`

改动类型：`新建`

### 17.1 登录朱红生成 .env `✅`

关键脚本骨架：

```dart
Future<void> main() async {
  const baseUrl = String.fromEnvironment(
    'FLASH_IM_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:9600',
  );
  // POST /auth/login with phone 13800010001 and password 111111
  // write client/test/.env:
  // FLASH_IM_API_BASE_URL=...
  // FLASH_IM_TOKEN=...
}
```

### 17.2 读取 baseUrl/token `✅`

关键代码骨架：

```dart
class TestEnv {
  const TestEnv({required this.baseUrl, required this.token});

  final String baseUrl;
  final String token;
}

TestEnv readTestEnvOrSkip() {
  // read client/test/.env
  // if missing token, return skip marker or throw SkipException pattern used by tests
}
```

说明：
- `client/test/.env` 必须加入 gitignore 或确认现有忽略规则覆盖，不能提交真实 token。

---

## 最后：依赖安装、格式化、分析与测试验证 `✅ 已完成`

依赖：任务 1-17

### 18.1 新 package 安装依赖 `✅`

命令：

```bash
cd client/modules/flash_im_conversation && flutter pub get
```

### 18.2 新 package 格式化 `✅`

命令：

```bash
cd client/modules/flash_im_conversation && dart format lib test
```

### 18.3 新 package 静态检查 `✅`

命令：

```bash
cd client/modules/flash_im_conversation && flutter analyze
```

### 18.4 新 package 测试 `✅`

命令：

```bash
cd client/modules/flash_im_conversation && flutter test
```

### 18.5 主 app 安装依赖 `✅`

命令：

```bash
cd client && flutter pub get
```

### 18.6 主 app 格式化 `✅`

命令：

```bash
cd client && dart format lib test
```

### 18.7 主 app 静态检查 `✅`

命令：

```bash
cd client && flutter analyze lib test
```

### 18.8 主壳层测试 `✅`

命令：

```bash
cd client && flutter test test/features/main_shell/presentation/main_shell_page_test.dart
```

### 18.9 手工验收路径 `✅`

前置条件：
- 后端已完成 `docs/features/im/core/v0.0.2/server/tasks.md`。
- 已导入会话种子数据。
- 使用朱红账号 `13800010001 / 111111` 登录。

验收点：
- 消息 Tab 顶部仍显示当前用户和连接状态。
- 列表首屏显示 20 条会话。
- 每条会话展示头像、昵称、最后消息预览、时间。
- 向下滚动接近底部会继续加载下一页。
- 51 条种子会话分 3 页加载完成。
- 下拉刷新回到第一页。
- 页面不出现“消息页暂未开放”。

---

## 执行结果

状态：`✅ 已完成`

实际改动：
- 新增 Flutter package：`client/modules/flash_im_conversation`
- 新增模型与显示辅助：`Conversation` / `ConversationDisplay`
- 新增 Dio 仓储：`DioConversationRepository` 请求 `GET /conversations`
- 新增 Cubit 状态与分页逻辑：首屏加载、下拉刷新、加载更多、错误保留已有数据
- 新增列表 UI：`ConversationListPage`、`ConversationTile`
- 主应用接入 path 依赖：`client/pubspec.yaml`
- `FlashImApp` 注入 `ConversationRepository`，默认 Dio 通过拦截器从 `SessionCubit` 注入 Bearer token
- 消息 Tab 保留当前用户与 WebSocket 状态 header，正文替换为真实会话列表
- 新增测试环境工具：`client/test/login_for_test.dart`、`client/test/test_env.dart`
- `client/test/.env` 已加入 `client/.gitignore`

实现说明：
- 未实现创建会话、删除会话、左滑删除、置顶、点击进入聊天页、未读红点和 WebSocket 实时更新，符合本清单范围约束。
- 任务骨架中的 `bloc_test ^9.1.7` 与当前 `flutter_bloc ^9.1.1` 依赖的 `bloc 9.x` 冲突，实际使用 `bloc_test ^10.0.0`。
- 真实 API 测试默认读取 `client/test/.env`；没有 token 时会跳过，运行 `cd client && dart test/login_for_test.dart` 可通过朱红账号 `13800010001 / 111111` 生成。

验证记录：
- `cd client/modules/flash_im_conversation && flutter pub get`：通过
- `cd client/modules/flash_im_conversation && dart format lib test`：通过
- `cd client/modules/flash_im_conversation && dart format --output=none --set-exit-if-changed lib test`：通过，0 个文件需修改
- `cd client/modules/flash_im_conversation && flutter analyze`：通过
- `cd client/modules/flash_im_conversation && flutter test`：通过，7 个单元测试通过，缺少 `.env` 时真实 API 测试按预期跳过
- `cd client && flutter pub get`：通过
- `cd client && dart format lib/app/flash_im_app.dart lib/features/messages/presentation/messages_placeholder_page.dart test/features/main_shell/presentation/main_shell_page_test.dart test/login_for_test.dart test/test_env.dart`：通过
- `cd client && dart format --output=none --set-exit-if-changed lib test`：通过，0 个文件需修改
- `cd client && flutter analyze lib test`：通过
- `cd client && flutter test test/features/main_shell/presentation/main_shell_page_test.dart`：通过
- `scripts/server/start_backend.sh`：临时启动后端用于真实 API 测试
- `cd client && dart test/login_for_test.dart`：通过，写入 `client/test/.env`
- `cd client/modules/flash_im_conversation && flutter test test/conversation_api_test.dart`：通过，验证第一页 20 条、三页合计 51 条、ID 不重复、超出范围为空
- 后端验证进程已停止，`lsof -tiTCP:9600 -sTCP:LISTEN` 无遗留监听
