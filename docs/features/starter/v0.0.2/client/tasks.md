# flash_starter — client 任务清单

基于 design.md 设计，列出将 `flash_starter` 从 `flash_session` 直接依赖中解耦的具体实施步骤。

全局约束：
- 只处理 `client/modules/flash_starter` 与宿主 `client/lib/app` 的启动边界，不改登录、资料、密码、IM 业务逻辑。
- `flash_starter` 不得 import `package:flash_session/flash_session.dart`，也不得在 `pubspec.yaml` 依赖 `flash_session`。
- `flash_starter` 不再通过 `BuildContext.read<SessionCubit>()` 触发恢复，而是通过 `AppStarterOptions.controller`。
- 宿主 App 负责把 `SessionCubit` 适配成 `AppStarterController`。
- 保留现有行为：首帧后恢复、已登录进 `/home`、未登录延迟进 `/login`、失败展示重试。
- 不实现 `design.md` 中暂不实现内容：不改会话业务、不改登录页、不引入新路由库、不做启动 UI 扩展。

---

## 执行顺序

1. ✅ 任务 1 — `client/modules/flash_starter/lib/src/domain/app_starter_state.dart` 新增 starter 自有状态模型（无依赖）
   - ✅ 1.1 定义 `AppStarterStatus`
   - ✅ 1.2 定义 `AppStarterState`
2. ✅ 任务 2 — `client/modules/flash_starter/lib/src/domain/app_starter_controller.dart` 新增启动控制器协议（依赖任务 1）
   - ✅ 2.1 定义 `AppStarterController`
   - ✅ 2.2 明确 `restore()`、`state`、`stream` 契约
3. ✅ 任务 3 — `client/modules/flash_starter/lib/src/domain/app_starter_options.dart` 注入 controller（依赖任务 2）
   - ✅ 3.1 新增必传 `controller`
   - ✅ 3.2 保留现有品牌、路由、延迟和失败文案配置
4. ✅ 任务 4 — `client/modules/flash_starter/lib/flash_starter.dart` 更新导出面（依赖任务 1、任务 2）
   - ✅ 4.1 导出 starter 状态模型
   - ✅ 4.2 导出 controller 协议
5. ✅ 任务 5 — `client/modules/flash_starter/lib/src/presentation/app_starter_page.dart` 改为订阅 controller（依赖任务 3、任务 4）
   - ✅ 5.1 移除 `flash_session` 与 `flutter_bloc` import
   - ✅ 5.2 首帧后调用 `controller.restore()`
   - ✅ 5.3 订阅 `controller.stream` 并映射页面阶段与路由
   - ✅ 5.4 `dispose()` 取消 stream subscription 和未登录 timer
6. ✅ 任务 6 — `client/modules/flash_starter/pubspec.yaml` 移除 session/bloc 依赖（依赖任务 5）
   - ✅ 6.1 删除 `flash_session`
   - ✅ 6.2 删除 `flutter_bloc`
7. ✅ 任务 7 — `client/lib/app/session_app_starter_controller.dart` 新增宿主适配器（依赖任务 2）
   - ✅ 7.1 接收 `SessionCubit`
   - ✅ 7.2 映射 `SessionStatus` 到 `AppStarterStatus`
   - ✅ 7.3 转发 `restore()` 到 `restoreSession()`
8. ✅ 任务 8 — `client/lib/app/flash_im_app.dart` 创建并提供 starter controller（依赖任务 7）
   - ✅ 8.1 增加可注入的 `AppStarterController?`
   - ✅ 8.2 默认用 `SessionAppStarterController(sessionCubit)`
   - ✅ 8.3 生命周期与现有 App 级依赖保持一致
9. ✅ 任务 9 — `client/lib/app/app_router.dart` 传入 controller（依赖任务 8）
   - ✅ 9.1 从 Provider 或参数边界读取 `AppStarterController`
   - ✅ 9.2 构建 `AppStarterOptions(controller: ...)`
10. ✅ 任务 10 — `client/modules/flash_starter/test/app_starter_test.dart` 改为 fake controller 测试（依赖任务 5、任务 6）
    - ✅ 10.1 删除 `flash_session` fake repository
    - ✅ 10.2 使用可控 stream 验证未登录跳转
    - ✅ 10.3 增加失败重试或已登录跳转覆盖
11. ✅ 任务 11 — 宿主启动测试更新（依赖任务 8、任务 9）
    - ✅ 11.1 `client/test/features/startup/presentation/startup_page_test.dart` 保持行为断言
    - ✅ 11.2 `client/test/widget_test.dart` 注入或验证默认适配链路
12. ✅ 最后 — 依赖安装、格式化、分析与测试验证（依赖任务 1-11）
    - ✅ 12.1 `cd client/modules/flash_starter && flutter pub get`
    - ✅ 12.2 `cd client && flutter pub get`
    - ✅ 12.3 `dart format` 目标文件
    - ✅ 12.4 `cd client/modules/flash_starter && flutter analyze && flutter test`
    - ✅ 12.5 `cd client && flutter analyze lib test && flutter test test/features/startup/presentation/startup_page_test.dart test/widget_test.dart`

---

## 任务 1：app_starter_state.dart — 新增 starter 自有状态模型 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_starter/lib/src/domain/app_starter_state.dart`

改动类型：`新建`

### 1.1 定义启动状态枚举 `✅`

关键代码骨架：

```dart
enum AppStarterStatus {
  initial,
  restoring,
  authenticated,
  unauthenticated,
  failure,
}
```

### 1.2 定义启动状态值对象 `✅`

关键代码骨架：

```dart
class AppStarterState {
  const AppStarterState({
    required this.status,
    this.errorMessage,
  });

  const AppStarterState.initial() : this(status: AppStarterStatus.initial);

  final AppStarterStatus status;
  final String? errorMessage;
}
```

---

## 任务 2：app_starter_controller.dart — 新增启动控制器协议 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_starter/lib/src/domain/app_starter_controller.dart`

改动类型：`新建`

### 2.1 定义 controller 接口 `✅`

关键代码骨架：

```dart
import 'app_starter_state.dart';

abstract interface class AppStarterController {
  AppStarterState get state;
  Stream<AppStarterState> get stream;
  Future<void> restore();
}
```

### 2.2 保持接口只表达启动语义 `✅`

不要在该接口中暴露 token、用户资料、密码状态、`SessionCubit` 或 `SessionRepository`。

---

## 任务 3：app_starter_options.dart — 注入 controller `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_starter/lib/src/domain/app_starter_options.dart`

改动类型：`修改`

### 3.1 新增必传 controller `✅`

关键代码骨架：

```dart
import 'app_starter_branding.dart';
import 'app_starter_controller.dart';
import 'app_starter_routes.dart';

class AppStarterOptions {
  const AppStarterOptions({
    required this.routes,
    required this.branding,
    required this.controller,
    this.unauthenticatedDelay = const Duration(seconds: 3),
    this.failureMessage = '启动失败，请重试',
    this.retryLabel = '重试',
  });

  final AppStarterController controller;
}
```

### 3.2 保留现有配置语义 `✅`

`routes`、`branding`、`unauthenticatedDelay`、`failureMessage`、`retryLabel` 的行为和默认值不变。

---

## 任务 4：flash_starter.dart — 更新 package 导出面 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_starter/lib/flash_starter.dart`

改动类型：`修改`

### 4.1 导出新增协议 `✅`

关键代码骨架：

```dart
export 'src/domain/app_starter_controller.dart';
export 'src/domain/app_starter_state.dart';
```

### 4.2 保留既有导出 `✅`

继续导出：

```dart
export 'src/domain/app_starter_branding.dart';
export 'src/domain/app_starter_options.dart';
export 'src/domain/app_starter_routes.dart';
export 'src/domain/app_starter_stage.dart';
export 'src/presentation/app_starter_page.dart';
```

---

## 任务 5：app_starter_page.dart — 改为订阅 controller `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_starter/lib/src/presentation/app_starter_page.dart`

改动类型：`修改`

### 5.1 移除具体 session 依赖 `✅`

删除：

```dart
import 'package:flash_session/flash_session.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
```

新增：

```dart
import '../domain/app_starter_state.dart';
```

### 5.2 首帧后调用 controller.restore `✅`

关键代码骨架：

```dart
@override
void initState() {
  super.initState();
  _starterStateSubscription = widget.options.controller.stream.listen(
    _handleStarterState,
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    widget.options.controller.restore();
  });
}
```

### 5.3 映射 starter 状态到 UI 与路由 `✅`

关键代码骨架：

```dart
void _handleStarterState(AppStarterState state) {
  switch (state.status) {
    case AppStarterStatus.initial:
      break;
    case AppStarterStatus.restoring:
      _loginRouteTimer?.cancel();
      setState(() => _stage = AppStarterStage.loading);
      break;
    case AppStarterStatus.authenticated:
      _loginRouteTimer?.cancel();
      setState(() => _stage = AppStarterStage.ready);
      _goToRoute(widget.options.routes.homeRouteName);
      break;
    case AppStarterStatus.unauthenticated:
      setState(() => _stage = AppStarterStage.ready);
      _scheduleLoginRoute();
      break;
    case AppStarterStatus.failure:
      _loginRouteTimer?.cancel();
      setState(() {
        _stage = AppStarterStage.failed;
        _errorMessage = state.errorMessage ?? widget.options.failureMessage;
      });
      break;
  }
}
```

### 5.4 清理订阅与重试逻辑 `✅`

关键代码骨架：

```dart
StreamSubscription<AppStarterState>? _starterStateSubscription;

void _retryRestore() {
  widget.options.controller.restore();
}

@override
void dispose() {
  _starterStateSubscription?.cancel();
  _loginRouteTimer?.cancel();
  super.dispose();
}
```

---

## 任务 6：flash_starter/pubspec.yaml — 移除 session/bloc 依赖 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_starter/pubspec.yaml`

改动类型：`配置修改`

### 6.1 删除 `flash_session` `✅`

删除：

```yaml
  flash_session:
    path: ../flash_session
```

### 6.2 删除 `flutter_bloc` `✅`

删除：

```yaml
  flutter_bloc: ^9.1.1
```

`flash_starter` 本期只保留 Flutter UI 依赖。

---

## 任务 7：session_app_starter_controller.dart — 新增宿主适配器 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/app/session_app_starter_controller.dart`

改动类型：`新建`

### 7.1 接收 SessionCubit `✅`

关键代码骨架：

```dart
import 'package:flash_session/flash_session.dart';
import 'package:flash_starter/flash_starter.dart';

class SessionAppStarterController implements AppStarterController {
  SessionAppStarterController(this._sessionCubit);

  final SessionCubit _sessionCubit;
}
```

### 7.2 映射状态 `✅`

关键代码骨架：

```dart
AppStarterState _map(SessionState state) {
  return AppStarterState(
    status: switch (state.status) {
      SessionStatus.initial => AppStarterStatus.initial,
      SessionStatus.restoring => AppStarterStatus.restoring,
      SessionStatus.authenticated => AppStarterStatus.authenticated,
      SessionStatus.unauthenticated => AppStarterStatus.unauthenticated,
      SessionStatus.failure => AppStarterStatus.failure,
    },
    errorMessage: state.errorMessage,
  );
}
```

### 7.3 转发 restore 与 stream `✅`

关键代码骨架：

```dart
@override
AppStarterState get state => _map(_sessionCubit.state);

@override
Stream<AppStarterState> get stream => _sessionCubit.stream.map(_map);

@override
Future<void> restore() => _sessionCubit.restoreSession();
```

---

## 任务 8：flash_im_app.dart — 创建并提供 starter controller `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/app/flash_im_app.dart`

改动类型：`修改`

### 8.1 增加可注入 controller `✅`

关键代码骨架：

```dart
class FlashImApp extends StatefulWidget {
  const FlashImApp({
    super.key,
    this.appStarterController,
  });

  final AppStarterController? appStarterController;
}
```

### 8.2 默认创建 Session 适配器 `✅`

关键代码骨架：

```dart
final appStarterController =
    widget.appStarterController ??
    SessionAppStarterController(sessionCubit);
```

### 8.3 提供给路由层 `✅`

可选方案一：通过 `RepositoryProvider<AppStarterController>.value` 注入。

```dart
RepositoryProvider<AppStarterController>.value(
  value: appStarterController,
)
```

可选方案二：调整 `onGenerateAppRoute` 为闭包并捕获 controller。

选择其中一种即可，优先沿用当前 `MultiRepositoryProvider` 方式。

---

## 任务 9：app_router.dart — 传入 controller `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/app/app_router.dart`

改动类型：`修改`

### 9.1 获取宿主注入的 controller `✅`

如果任务 8 采用 Provider 方案，关键代码骨架：

```dart
final controller = context.read<AppStarterController>();
```

### 9.2 构建 AppStarterOptions `✅`

关键代码骨架：

```dart
AppStarterOptions(
  controller: controller,
  routes: const AppStarterRoutes(
    loginRouteName: AppRoutes.login,
    homeRouteName: AppRoutes.home,
  ),
  branding: AppStarterBranding(
    logo: Image.asset('assets/branding/flash_im_logo_alpha.png', width: 132),
    title: 'Flash IM',
    idleSubtitle: '轻量即时通讯',
    loadingSubtitle: '正在恢复登录状态...',
  ),
)
```

---

## 任务 10：flash_starter package 测试 — 使用 fake controller `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_starter/test/app_starter_test.dart`

改动类型：`修改`

### 10.1 删除 session fake `✅`

删除当前测试里对以下类型的依赖：

- `SessionCubit`
- `SessionRepository`
- `CachedAuthSession`
- `User`
- `AppSession`

### 10.2 新增 fake controller `✅`

关键代码骨架：

```dart
class _FakeAppStarterController implements AppStarterController {
  final _controller = StreamController<AppStarterState>.broadcast();
  AppStarterState _state = const AppStarterState.initial();

  @override
  AppStarterState get state => _state;

  @override
  Stream<AppStarterState> get stream => _controller.stream;

  @override
  Future<void> restore() async {
    emit(const AppStarterState(status: AppStarterStatus.unauthenticated));
  }

  void emit(AppStarterState state) {
    _state = state;
    _controller.add(state);
  }
}
```

### 10.3 覆盖行为不变 `✅`

至少保留：

- 导出模型测试。
- 未登录延迟跳 `/login`。
- 已登录跳 `/home` 或失败重试二选一，建议都覆盖。

---

## 任务 11：宿主启动测试 — 保持真实链路断言 `✅ 已完成`

文件：
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/test/features/startup/presentation/startup_page_test.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/test/widget_test.dart`

改动类型：`修改`

### 11.1 启动页测试继续用 SessionCubit 验证适配器 `✅`

测试仍可创建 fake `SessionRepository` 和 `SessionCubit`，但断言边界变为：

- 宿主创建 `SessionAppStarterController`。
- `AppStarterPage` 只接收 `AppStarterOptions.controller`。
- 最终仍跳登录、首页或失败态。

### 11.2 主 App 测试验证默认适配链路 `✅`

`FlashImApp` 测试继续验证缓存 session 可进入首页，确保默认 `SessionCubit -> SessionAppStarterController -> AppStarterPage` 链路有效。

---

## 任务 12：依赖安装、格式化、分析与测试验证 `✅ 已完成`

改动类型：`验证`

### 12.1 更新 package 依赖 `✅`

```bash
cd client/modules/flash_starter && flutter pub get
```

### 12.2 更新宿主依赖 `✅`

```bash
cd client && flutter pub get
```

### 12.3 格式化目标文件 `✅`

```bash
cd client && dart format \
  modules/flash_starter/lib \
  modules/flash_starter/test \
  lib/app \
  test/features/startup/presentation/startup_page_test.dart \
  test/widget_test.dart
```

### 12.4 package 验证 `✅`

```bash
cd client/modules/flash_starter && flutter analyze && flutter test
```

### 12.5 宿主验证 `✅`

```bash
cd client && flutter analyze lib test
cd client && flutter test test/features/startup/presentation/startup_page_test.dart test/widget_test.dart
```
