# im-core v0.0.1 — 客户端任务清单

基于 [design.md](./design.md) 设计，拆分 `client/` 侧 IM Core 实现步骤。目标是在 `flash_im_core` package 中实现 Protobuf WebSocket 管理器、IM 配置、连接状态指示器，并在当前主应用结构中完成登录后连接、退出后断开和消息页顶部状态展示。

全局约束：
- 本清单只覆盖客户端 IM Core 最小连接能力：AUTH 帧认证、PING/PONG 心跳、断线重连、连接状态 UI、主应用接入。
- 不实现消息相关事件流、会话更新流、好友事件流、多端登录管理；`WsClient` 只暴露原始 `frameStream`。
- `WsClient` 不依赖 UI，不依赖 `SessionCubit`；通过 `TokenProvider` 闭包获取 token。
- 当前仓库真实接入点不是裸 `main.dart`，而是 `client/lib/app/flash_im_app.dart` 与 `client/lib/features/home/presentation/main_shell_page.dart`。
- `flash_im_core` 已有 `proto/ws.*.dart` 生成代码，本版本不重新生成 proto。
- 主 app 当前已有 `web_socket_channel` 依赖，但 `flash_im_core` package 需要声明自己的 package 依赖。
- `authenticated` 状态下 `WsStatusIndicator` 必须隐藏且不占空间。

---

## 执行顺序

1. ✅ 任务 1 — `client/modules/flash_im_core/pubspec.yaml` 增加 WebSocket 依赖（无依赖）
   - ✅ 1.1 添加 `web_socket_channel`
2. ✅ 任务 2 — `client/modules/flash_im_core/lib/src/data/im_config.dart` 定义 IM 配置（依赖任务 1）
   - ✅ 2.1 定义 `ImConfig`
   - ✅ 2.2 提供 `fromApiBaseUrl`
   - ✅ 2.3 提供默认心跳与重连参数
3. ✅ 任务 3 — `client/modules/flash_im_core/lib/src/logic/ws_client.dart` 实现 WebSocket 管理器（依赖任务 2）
   - ✅ 3.1 定义 `WsConnectionState` 与 `TokenProvider`
   - ✅ 3.2 支持注入 `WebSocketChannel` 创建函数
   - ✅ 3.3 实现 `connect` / AUTH 帧发送 / AUTH_RESULT 处理
   - ✅ 3.4 实现 PING/PONG 心跳与超时计数
   - ✅ 3.5 实现断线指数退避重连
   - ✅ 3.6 暴露 `stateStream`、`frameStream`、`sendFrame`、`disconnect`、`dispose`
4. ✅ 任务 4 — `client/modules/flash_im_core/lib/src/view/ws_status_indicator.dart` 实现连接状态指示器（依赖任务 3）
   - ✅ 4.1 监听 `WsClient.stateStream`
   - ✅ 4.2 `disconnected` / `connecting` / `authenticating` 展示提示条
   - ✅ 4.3 `authenticated` 隐藏不占位
   - ✅ 4.4 点击断开状态触发 `connect`
5. ✅ 任务 5 — `client/modules/flash_im_core/lib/flash_im_core.dart` 更新 barrel 导出（依赖任务 2-4）
   - ✅ 5.1 导出 `ImConfig`
   - ✅ 5.2 导出 `WsClient` / `WsConnectionState`
   - ✅ 5.3 导出 `WsStatusIndicator`
6. ✅ 任务 6 — `client/pubspec.yaml` 接入 `flash_im_core` 主应用依赖（依赖任务 5）
   - ✅ 6.1 新增 path 依赖
7. ✅ 任务 7 — `client/lib/app/flash_im_app.dart` 创建并提供 `WsClient`（依赖任务 6）
   - ✅ 7.1 增加可注入 `WsClient`
   - ✅ 7.2 从 `LocalAppConfig.apiBaseUrl` 构造 `ImConfig`
   - ✅ 7.3 用 `SessionCubit.state.session?.token` 作为 tokenProvider
   - ✅ 7.4 `MultiRepositoryProvider` 提供 `WsClient`
   - ✅ 7.5 dispose 默认 `WsClient`
8. ✅ 任务 8 — `client/lib/features/home/presentation/main_shell_page.dart` 绑定会话与 WebSocket 生命周期（依赖任务 7）
   - ✅ 8.1 登录态进入 `authenticated` 时连接
   - ✅ 8.2 退出或未登录时断开
   - ✅ 8.3 body 顶部增加 `WsStatusIndicator`
9. ✅ 任务 9 — `client/lib/features/messages/presentation/messages_placeholder_page.dart` 展示头像、昵称与连接状态圆点（依赖任务 8）
   - ✅ 9.1 使用 `SessionCubit` 当前 user 渲染消息页头部
   - ✅ 9.2 头像使用 `IdenticonAvatar` 或网络图
   - ✅ 9.3 使用 `WsClient.stateStream` 渲染连接状态圆点
10. ✅ 任务 10 — `client/lib/features/home/presentation/widgets/home_navigation_bar.dart` 对齐自定义底部导航样式（依赖任务 8）
    - ✅ 10.1 保持白色背景与顶部细线
    - ✅ 10.2 使用主色高亮选中项
11. ✅ 任务 11 — `client/modules/flash_im_core/test/` 增加核心包测试（依赖任务 3-5）
    - ✅ 11.1 `im_config_test.dart`
    - ✅ 11.2 `ws_client_test.dart`
    - ✅ 11.3 `ws_status_indicator_test.dart`
12. ✅ 任务 12 — `client/test/features/main_shell/presentation/main_shell_page_test.dart` 更新主壳层测试（依赖任务 8-10）
    - ✅ 12.1 注入 fake `WsClient`
    - ✅ 12.2 验证登录态连接与退出断开
    - ✅ 12.3 验证状态条和消息页头部渲染
13. ✅ 最后 — 依赖安装、格式化、分析与测试验证（依赖任务 1-12）
    - ✅ 13.1 `cd client/modules/flash_im_core && flutter pub get`
    - ✅ 13.2 `cd client/modules/flash_im_core && dart format lib test`
    - ✅ 13.3 `cd client/modules/flash_im_core && flutter analyze`
    - ✅ 13.4 `cd client/modules/flash_im_core && flutter test`
    - ✅ 13.5 `cd client && flutter pub get`
    - ✅ 13.6 `cd client && dart format lib test`
    - ✅ 13.7 `cd client && flutter analyze lib test`
    - ✅ 13.8 `cd client && flutter test test/features/main_shell/presentation/main_shell_page_test.dart`

---

## 任务 1：`client/modules/flash_im_core/pubspec.yaml` — 增加 WebSocket 依赖 `✅ 已完成`

文件：`client/modules/flash_im_core/pubspec.yaml`

改动类型：`配置修改`

### 1.1 添加 `web_socket_channel` `✅`

关键配置骨架：

```yaml
dependencies:
  flutter:
    sdk: flutter
  protobuf: ^6.0.0
  web_socket_channel: ^3.0.3
```

说明：
- 主 app 已有该依赖，但 `flash_im_core` 是独立 package，必须声明自己的依赖。

---

## 任务 2：`client/modules/flash_im_core/lib/src/data/im_config.dart` — 定义 IM 配置 `✅ 已完成`

文件：`client/modules/flash_im_core/lib/src/data/im_config.dart`

改动类型：`新建`

### 2.1 定义 `ImConfig` 字段 `✅`

关键代码骨架：

```dart
class ImConfig {
  ImConfig({
    required this.wsUrl,
    this.heartbeatInterval = const Duration(seconds: 30),
    this.heartbeatTimeout = 3,
    this.reconnectBaseDelay = const Duration(seconds: 1),
    this.reconnectMaxDelay = const Duration(seconds: 30),
  });

  final String wsUrl;
  final Duration heartbeatInterval;
  final int heartbeatTimeout;
  final Duration reconnectBaseDelay;
  final Duration reconnectMaxDelay;
}
```

### 2.2 提供 `fromApiBaseUrl` `✅`

关键代码骨架：

```dart
factory ImConfig.fromApiBaseUrl(String apiBaseUrl) {
  final uri = Uri.parse(apiBaseUrl);
  final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
  return ImConfig(
    wsUrl: uri.replace(scheme: scheme, path: '/ws/im').toString(),
  );
}
```

说明：
- 保留 host / port / scheme，只把 path 改成 `/ws/im`。

### 2.3 参数校验 `✅`

关键逻辑骨架：

```dart
assert(heartbeatTimeout > 0);
assert(!heartbeatInterval.isNegative);
assert(!reconnectBaseDelay.isNegative);
assert(!reconnectMaxDelay.isNegative);
```

---

## 任务 3：`client/modules/flash_im_core/lib/src/logic/ws_client.dart` — 实现 WebSocket 管理器 `✅ 已完成`

文件：`client/modules/flash_im_core/lib/src/logic/ws_client.dart`

改动类型：`新建`

### 3.1 定义状态和依赖类型 `✅`

关键代码骨架：

```dart
typedef TokenProvider = FutureOr<String?> Function();
typedef WebSocketChannelFactory = WebSocketChannel Function(Uri uri);

enum WsConnectionState {
  disconnected,
  connecting,
  authenticating,
  authenticated,
}
```

### 3.2 定义构造函数与流 `✅`

关键代码骨架：

```dart
class WsClient {
  WsClient({
    required ImConfig config,
    required TokenProvider tokenProvider,
    WebSocketChannelFactory? channelFactory,
  });

  Stream<WsConnectionState> get stateStream;
  Stream<WsFrame> get frameStream;
  WsConnectionState get state;
}
```

说明：
- `stateStream` 和 `frameStream` 使用 `StreamController.broadcast`。
- `channelFactory` 用于测试注入 fake channel。

### 3.3 实现连接与 AUTH 认证 `✅`

关键流程骨架：

```dart
Future<void> connect() async {
  // 1. 如果已主动 dispose，直接 return
  // 2. state = connecting
  // 3. channel = channelFactory(Uri.parse(config.wsUrl))
  // 4. state = authenticating
  // 5. token = await tokenProvider()
  // 6. send AUTH frame: AuthRequest(token).writeToBuffer()
  // 7. 监听 stream，收到 AUTH_RESULT success=true 后 state = authenticated
}
```

### 3.4 实现帧发送与接收 `✅`

关键代码骨架：

```dart
void sendFrame(WsFrame frame);

void _handleBinaryMessage(List<int> bytes) {
  final frame = WsFrame.fromBuffer(bytes);
  switch (frame.type) {
    case WsFrameType.AUTH_RESULT:
      // decode AuthResult
    case WsFrameType.PONG:
      // reset missed pong count
    default:
      _frameController.add(frame);
  }
}
```

说明：
- 只对 AUTH_RESULT / PONG 做连接层处理，其它帧原样进入 `frameStream`。

### 3.5 实现心跳 `✅`

关键代码骨架：

```dart
void _startHeartbeat() {
  _heartbeatTimer = Timer.periodic(config.heartbeatInterval, (_) {
    _missedPongCount += 1;
    sendFrame(WsFrame(type: WsFrameType.PING));
    if (_missedPongCount >= config.heartbeatTimeout) {
      _handleDisconnected(allowReconnect: true);
    }
  });
}
```

### 3.6 实现指数退避重连 `✅`

关键代码骨架：

```dart
void _scheduleReconnect() {
  final delay = _nextReconnectDelay();
  _reconnectTimer = Timer(delay, connect);
}

Duration _nextReconnectDelay() {
  // 1s -> 2s -> 4s ... max 30s
}
```

说明：
- 用户主动 `disconnect()` 时不触发重连。

### 3.7 实现释放能力 `✅`

关键代码骨架：

```dart
Future<void> disconnect();
Future<void> dispose();
```

说明：
- `disconnect()` 关闭 channel 与 timer，但不关闭 stream controller。
- `dispose()` 关闭 channel、timer、stream controller。

---

## 任务 4：`client/modules/flash_im_core/lib/src/view/ws_status_indicator.dart` — 实现连接状态指示器 `✅ 已完成`

文件：`client/modules/flash_im_core/lib/src/view/ws_status_indicator.dart`

改动类型：`新建`

### 4.1 定义组件输入 `✅`

关键代码骨架：

```dart
class WsStatusIndicator extends StatelessWidget {
  const WsStatusIndicator({
    super.key,
    required this.client,
  });

  final WsClient client;
}
```

### 4.2 监听连接状态 `✅`

关键代码骨架：

```dart
StreamBuilder<WsConnectionState>(
  stream: client.stateStream,
  initialData: client.state,
  builder: (context, snapshot) {
    final state = snapshot.data ?? WsConnectionState.disconnected;
    // ...
  },
)
```

### 4.3 authenticated 隐藏不占位 `✅`

关键代码骨架：

```dart
if (state == WsConnectionState.authenticated) {
  return const SizedBox.shrink();
}
```

### 4.4 状态文案和点击重连 `✅`

关键映射：

```dart
switch (state) {
  case WsConnectionState.disconnected:
    // 红色条：连接已断开，正在重连...
  case WsConnectionState.connecting:
    // 橙色条：正在连接...
  case WsConnectionState.authenticating:
    // 橙色条：正在认证...
  case WsConnectionState.authenticated:
    // hidden
}
```

说明：
- `disconnected` 状态点击调用 `client.connect()`。

---

## 任务 5：`client/modules/flash_im_core/lib/flash_im_core.dart` — 更新 barrel 导出 `✅ 已完成`

文件：`client/modules/flash_im_core/lib/flash_im_core.dart`

改动类型：`修改`

### 5.1 导出 data `✅`

关键代码骨架：

```dart
export 'src/data/im_config.dart' show ImConfig;
```

### 5.2 导出 logic `✅`

关键代码骨架：

```dart
export 'src/logic/ws_client.dart' show TokenProvider, WsClient, WsConnectionState;
```

### 5.3 导出 view `✅`

关键代码骨架：

```dart
export 'src/view/ws_status_indicator.dart' show WsStatusIndicator;
```

---

## 任务 6：`client/pubspec.yaml` — 接入 `flash_im_core` 主应用依赖 `✅ 已完成`

文件：`client/pubspec.yaml`

改动类型：`配置修改`

### 6.1 新增 path 依赖 `✅`

关键配置骨架：

```yaml
dependencies:
  flash_im_core:
    path: modules/flash_im_core
```

说明：
- 不删除主 app 已有 `web_socket_channel` 依赖，避免影响 playground。

---

## 任务 7：`client/lib/app/flash_im_app.dart` — 创建并提供 `WsClient` `✅ 已完成`

文件：`client/lib/app/flash_im_app.dart`

改动类型：`修改`

### 7.1 增加可注入 `WsClient` `✅`

关键代码骨架：

```dart
class FlashImApp extends StatefulWidget {
  const FlashImApp({
    super.key,
    this.wsClient,
    // existing args...
  });

  final WsClient? wsClient;
}
```

### 7.2 创建默认 `WsClient` `✅`

关键代码骨架：

```dart
late final WsClient _defaultWsClient;

final wsClient = widget.wsClient ?? (_defaultWsClient ??= WsClient(
  config: ImConfig.fromApiBaseUrl(config.apiBaseUrl),
  tokenProvider: () => sessionCubit.state.session?.token,
));
```

说明：
- 实现时注意当前类字段不能用 `late final` 搭配条件初始化冲突，可沿用 `_defaultSessionCubit` 的 nullable 缓存模式。

### 7.3 提供到 widget tree `✅`

关键代码骨架：

```dart
MultiRepositoryProvider(
  providers: [
    RepositoryProvider<WsClient>.value(value: wsClient),
    // existing providers...
  ],
)
```

### 7.4 dispose 默认实例 `✅`

关键代码骨架：

```dart
@override
void dispose() {
  _defaultWsClient?.dispose();
  _defaultSessionCubit?.close();
  super.dispose();
}
```

---

## 任务 8：`client/lib/features/home/presentation/main_shell_page.dart` — 绑定会话与 WebSocket 生命周期 `✅ 已完成`

文件：`client/lib/features/home/presentation/main_shell_page.dart`

改动类型：`修改`

### 8.1 登录态连接 `✅`

关键逻辑骨架：

```dart
final wsClient = context.read<WsClient>();

if (state.status == SessionStatus.authenticated) {
  await wsClient.connect();
}
```

### 8.2 退出态断开 `✅`

关键逻辑骨架：

```dart
if (state.status == SessionStatus.unauthenticated) {
  await context.read<WsClient>().disconnect();
  Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
}
```

### 8.3 顶部增加状态指示器 `✅`

关键 widget 骨架：

```dart
body: SafeArea(
  child: Column(
    children: [
      WsStatusIndicator(client: context.read<WsClient>()),
      Expanded(child: _pages[_currentIndex]),
    ],
  ),
),
```

说明：
- `WsStatusIndicator` 在 authenticated 时返回 `SizedBox.shrink()`，不会占顶部空间。

---

## 任务 9：`client/lib/features/messages/presentation/messages_placeholder_page.dart` — 展示消息页头部 `✅ 已完成`

文件：`client/lib/features/messages/presentation/messages_placeholder_page.dart`

改动类型：`修改`

### 9.1 使用 `SessionCubit` 渲染用户信息 `✅`

关键 widget 骨架：

```dart
BlocBuilder<SessionCubit, SessionState>(
  builder: (context, state) {
    final user = state.user;
    return Column(
      children: [
        _MessagesHeader(user: user),
        const Expanded(child: Center(child: Text('消息页暂未开放'))),
      ],
    );
  },
)
```

### 9.2 头像与昵称 `✅`

关键 widget 骨架：

```dart
CircleAvatar(
  child: user == null
      ? const Icon(Icons.person)
      : IdenticonAvatar(seed: user.identiconSeed, size: 36),
)

Text(user?.nickname.isNotEmpty == true ? user!.nickname : 'Flash IM')
```

说明：
- 复用 `flash_session` 的 `IdenticonAvatar`，不要重新实现头像绘制。

### 9.3 连接状态圆点 `✅`

关键 widget 骨架：

```dart
StreamBuilder<WsConnectionState>(
  stream: context.read<WsClient>().stateStream,
  initialData: context.read<WsClient>().state,
  builder: (context, snapshot) {
    final connected = snapshot.data == WsConnectionState.authenticated;
    return _StatusDot(connected: connected);
  },
)
```

---

## 任务 10：`client/lib/features/home/presentation/widgets/home_navigation_bar.dart` — 对齐底部导航样式 `✅ 已完成`

文件：`client/lib/features/home/presentation/widgets/home_navigation_bar.dart`

改动类型：`修改`

### 10.1 增加顶部细线 `✅`

关键 widget 骨架：

```dart
return DecoratedBox(
  decoration: const BoxDecoration(
    color: Colors.white,
    border: Border(top: BorderSide(color: Color(0xFFE8EAF0))),
  ),
  child: BottomNavigationBar(...),
);
```

### 10.2 保持主色高亮 `✅`

关键配置骨架：

```dart
selectedItemColor: const Color(0xFF07C160),
unselectedItemColor: const Color(0xFF6A7B92),
```

---

## 任务 11：`client/modules/flash_im_core/test/` — 增加核心包测试 `✅ 已完成`

文件：
- `client/modules/flash_im_core/test/im_config_test.dart`
- `client/modules/flash_im_core/test/ws_client_test.dart`
- `client/modules/flash_im_core/test/ws_status_indicator_test.dart`

改动类型：`新建`

### 11.1 `im_config_test.dart` `✅`

关键测试骨架：

```dart
test('fromApiBaseUrl maps http to ws im endpoint', () {
  final config = ImConfig.fromApiBaseUrl('http://127.0.0.1:9600');
  expect(config.wsUrl, 'ws://127.0.0.1:9600/ws/im');
});
```

### 11.2 `ws_client_test.dart` `✅`

关键测试点：

```dart
test('connect sends auth frame and becomes authenticated on auth result', () async {});
test('ping resets missed pong count when pong is received', () async {});
test('disconnect does not schedule reconnect', () async {});
```

说明：
- 使用 fake `WebSocketChannel` 和短心跳间隔测试，不连接真实网络。

### 11.3 `ws_status_indicator_test.dart` `✅`

关键测试点：

```dart
testWidgets('hidden when authenticated', (tester) async {});
testWidgets('shows reconnect copy when disconnected', (tester) async {});
```

---

## 任务 12：`client/test/features/main_shell/presentation/main_shell_page_test.dart` — 更新主壳层测试 `✅ 已完成`

文件：`client/test/features/main_shell/presentation/main_shell_page_test.dart`

改动类型：`修改`

### 12.1 注入 fake `WsClient` `✅`

关键测试骨架：

```dart
RepositoryProvider<WsClient>.value(
  value: fakeWsClient,
  child: BlocProvider<SessionCubit>.value(
    value: sessionCubit,
    child: const MaterialApp(home: MainShellPage()),
  ),
)
```

### 12.2 验证登录态 connect 与退出 disconnect `✅`

关键断言：

```dart
expect(fakeWsClient.connectCallCount, 1);
expect(fakeWsClient.disconnectCallCount, 1);
```

### 12.3 验证状态展示 `✅`

关键断言：

```dart
expect(find.text('连接已断开，正在重连...'), findsOneWidget);
expect(find.text('消息页暂未开放'), findsOneWidget);
```

---

## 任务 13：依赖安装、格式化、分析与测试验证 `✅ 已完成`

文件：无单一目标文件，验证 `flash_im_core` package 与主 app 接入。

改动类型：`验证`

### 13.1 core package 依赖安装 `✅`

执行：

```bash
cd client/modules/flash_im_core && flutter pub get
```

### 13.2 core package 格式化 `✅`

执行：

```bash
cd client/modules/flash_im_core && dart format lib test
```

### 13.3 core package 静态分析 `✅`

执行：

```bash
cd client/modules/flash_im_core && flutter analyze
```

### 13.4 core package 测试 `✅`

执行：

```bash
cd client/modules/flash_im_core && flutter test
```

### 13.5 主 app 依赖安装 `✅`

执行：

```bash
cd client && flutter pub get
```

### 13.6 主 app 格式化 `✅`

执行：

```bash
cd client && dart format lib test
```

### 13.7 主 app 静态分析 `✅`

执行：

```bash
cd client && flutter analyze lib test
```

### 13.8 主壳层目标测试 `✅`

执行：

```bash
cd client && flutter test test/features/main_shell/presentation/main_shell_page_test.dart
```

---

## 本次执行结果

- ✅ `client/modules/flash_im_core` 已新增 `ImConfig`、`WsClient`、`WsStatusIndicator` 与 barrel 导出。
- ✅ 主应用已通过 `FlashImApp` 提供 `WsClient`，`MainShellPage` 已绑定登录连接、退出断开和顶部状态条。
- ✅ `MainShellPage` 已在认证态自动补拉当前用户信息，消息 tab 首屏不再依赖切到“我的”后刷新 profile。
- ✅ 消息页已展示当前用户头像/昵称兜底信息和 WebSocket 连接状态圆点。
- ✅ 消息页连接状态已从单独圆点补充为“圆点 + 文案”，可直接查看已连接、正在连接、正在认证、已断开。
- ✅ 底部导航已调整为白底、顶部细线、主色选中态。
- ✅ 已补充 core package 配置、WebSocket 管理器、状态条测试，以及主壳层接入测试。

验证通过：

```bash
cd client/modules/flash_im_core && flutter pub get
cd client/modules/flash_im_core && dart format lib test
cd client/modules/flash_im_core && flutter analyze
cd client/modules/flash_im_core && flutter test
cd client && flutter pub get
cd client && dart format lib test
cd client && flutter analyze lib test
cd client && flutter test test/features/main_shell/presentation/main_shell_page_test.dart
```
