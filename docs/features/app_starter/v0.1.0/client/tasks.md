# app_starter — client 任务清单

基于 design.md 设计，列出需要创建/修改的具体细节。  
全局约束：
- `app_starter` 必须作为独立本地 package 落到 `client/modules/app_starter`，由宿主 `client` 通过 path dependency 接入。
- `app_starter` 只负责启动页 UI、启动流程驱动、失败态与跳转分流，不实现 token 存储、认证接口、认证仓库。
- 启动状态源继续复用 `flash_auth` 中的 `AppSessionCubit` / `AuthStatus`，不要再复制一套认证状态模型。
- package 不得直接 import 宿主 `client/lib/app/app_router.dart`、`assets/branding/...` 或宿主页面路径；路由名、品牌资源、文案统一由宿主传入。
- 以当前正式产品真实生效的启动链路为准，不把旧 `StartupCoordinator / AppBootstrapSnapshot / LaunchDestination` 体系继续作为主实现扩展。
- 不实现 `design.md` 中暂不实现内容：远端配置拉取、版本检查、引导页、复杂启动动画、脱离 `flash_auth` 再抽象一层 session protocol。

---

## 执行顺序

1. ✅ 任务 1 — `client/modules/app_starter/pubspec.yaml` 建立独立 package 依赖（无依赖）
   - ✅ 1.1 声明 `flutter_bloc`
   - ✅ 1.2 以 path 方式依赖 `../flash_auth`
2. ✅ 任务 2 — `client/modules/app_starter/lib/app_starter.dart` 定义对外导出面（依赖任务 1）
   - ✅ 2.1 导出 domain 配置模型
   - ✅ 2.2 导出 `AppStarterPage`
3. ✅ 任务 3 — `client/modules/app_starter/lib/src/domain/` 新建启动配置模型（依赖任务 1）
   - ✅ 3.1 新增 `app_starter_stage.dart`
   - ✅ 3.2 新增 `app_starter_routes.dart`
   - ✅ 3.3 新增 `app_starter_branding.dart`
   - ✅ 3.4 新增 `app_starter_options.dart`
4. ✅ 任务 4 — `client/modules/app_starter/lib/src/presentation/widgets/` 抽启动页局部 widget（依赖任务 3）
   - ✅ 4.1 新增品牌展示 widget
   - ✅ 4.2 新增失败态 widget
5. ✅ 任务 5 — `client/modules/app_starter/lib/src/presentation/app_starter_page.dart` 落正式启动页 package 实现（依赖任务 3、任务 4）
   - ✅ 5.1 首帧触发 `restoreSession()`
   - ✅ 5.2 监听 `AuthStatus` 并跳转
   - ✅ 5.3 处理未登录延迟与失败重试
6. ✅ 任务 6 — `client/pubspec.yaml` 接入 `app_starter` path dependency（依赖任务 1、任务 2）
   - ✅ 6.1 新增 `app_starter`
   - ✅ 6.2 保持现有 `flash_auth` 依赖不被顺手改动
7. ✅ 任务 7 — `client/lib/app/app_router.dart` 改为使用 package 启动页（依赖任务 5、任务 6）
   - ✅ 7.1 `/startup` 指向 `AppStarterPage`
   - ✅ 7.2 宿主传入路由名与品牌配置
8. ✅ 任务 8 — `client/lib/app/flash_im_app.dart` 维持宿主注入与品牌资源接入（依赖任务 6、任务 7）
   - ✅ 8.1 保持 `AppSessionCubit` 注入不变
   - ✅ 8.2 保持当前主题和背景风格
9. ✅ 任务 9 — `client/lib/features/startup/` 清理旧启动实现与残余抽象（依赖任务 7、任务 8）
   - ✅ 9.1 删除或迁移旧 `StartupPage`
   - ✅ 9.2 删除旧 `StartupCoordinator / AppBootstrapSnapshot / LaunchDestination / StartupStage`
10. ✅ 任务 10 — `client/test/features/startup/` 与 `client/test/widget_test.dart` 对齐 package 接入测试（依赖任务 5、任务 7、任务 8、任务 9）
    - ✅ 10.1 启动页跳转测试改到新 package 接口
    - ✅ 10.2 宿主应用恢复登录态测试继续通过
11. ✅ 任务 11 — `client/modules/app_starter/test/app_starter_test.dart` 新增 package 自测（依赖任务 5）
    - ✅ 11.1 配置模型导出测试
    - ✅ 11.2 基础页面渲染或行为测试
12. ✅ 最后 — 依赖安装、格式化、分析与测试验证（依赖任务 1-11）
    - ✅ 12.1 `cd client/modules/app_starter && flutter pub get`
    - ✅ 12.2 `cd client && flutter pub get`
    - ✅ 12.3 `dart format`
    - ✅ 12.4 `flutter analyze`
    - ✅ 12.5 `flutter test`

---

## 任务 1：app_starter/pubspec.yaml — 建立独立 package 依赖 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/app_starter/pubspec.yaml`

改动类型：`新建/修改`

### 1.1 声明 package 基础依赖 `✅`

关键代码片段：

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_bloc: ^9.1.1
  flash_auth:
    path: ../flash_auth
```

### 1.2 控制 package 责任范围 `✅`

本期不在 `app_starter` 中引入 `dio`、`shared_preferences`、`go_router` 等与启动页职责无关的依赖。

---

## 任务 2：app_starter.dart — 对外导出面 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/app_starter/lib/app_starter.dart`

改动类型：`新建/修改`

### 2.1 导出 package 对外表面 `✅`

关键代码片段：

```dart
library;

export 'src/domain/app_starter_branding.dart';
export 'src/domain/app_starter_options.dart';
export 'src/domain/app_starter_routes.dart';
export 'src/domain/app_starter_stage.dart';
export 'src/presentation/app_starter_page.dart';
```

---

## 任务 3：domain — 启动配置模型 `✅ 已完成`

文件：
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/app_starter/lib/src/domain/app_starter_stage.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/app_starter/lib/src/domain/app_starter_routes.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/app_starter/lib/src/domain/app_starter_branding.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/app_starter/lib/src/domain/app_starter_options.dart`

改动类型：`新建`

### 3.1 新增启动阶段枚举 `✅`

关键代码片段：

```dart
enum AppStarterStage {
  idle,
  loading,
  ready,
  failed,
}
```

### 3.2 新增路由与品牌模型 `✅`

关键代码片段：

```dart
class AppStarterRoutes {
  const AppStarterRoutes({
    required this.loginRouteName,
    required this.homeRouteName,
  });

  final String loginRouteName;
  final String homeRouteName;
}

class AppStarterBranding {
  const AppStarterBranding({
    required this.logo,
    required this.title,
    required this.idleSubtitle,
    required this.loadingSubtitle,
  });

  final Widget logo;
  final String title;
  final String idleSubtitle;
  final String loadingSubtitle;
}
```

### 3.3 新增启动配置聚合模型 `✅`

关键代码片段：

```dart
class AppStarterOptions {
  const AppStarterOptions({
    required this.routes,
    required this.branding,
    this.unauthenticatedDelay = const Duration(seconds: 3),
    this.failureMessage = '启动失败，请重试',
    this.retryLabel = '重试',
  });

  final AppStarterRoutes routes;
  final AppStarterBranding branding;
  final Duration unauthenticatedDelay;
  final String failureMessage;
  final String retryLabel;
}
```

---

## 任务 4：widgets — 启动页局部组件 `✅ 已完成`

文件：
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/app_starter/lib/src/presentation/widgets/starter_brand_panel.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/app_starter/lib/src/presentation/widgets/starter_failure_panel.dart`

改动类型：`新建`

### 4.1 新增品牌展示组件 `✅`

职责：
- 展示 `logo`
- 展示 `title`
- 根据阶段展示 `idleSubtitle` / `loadingSubtitle`

关键代码片段：

```dart
class StarterBrandPanel extends StatelessWidget {
  const StarterBrandPanel({
    super.key,
    required this.branding,
    required this.stage,
  });

  final AppStarterBranding branding;
  final AppStarterStage stage;
}
```

### 4.2 新增失败态组件 `✅`

职责：
- 展示错误文案
- 提供重试按钮

关键代码片段：

```dart
class StarterFailurePanel extends StatelessWidget {
  const StarterFailurePanel({
    super.key,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;
}
```

---

## 任务 5：app_starter_page.dart — 启动页 package 主实现 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/app_starter/lib/src/presentation/app_starter_page.dart`

改动类型：`新建`

### 5.1 首帧触发会话恢复 `✅`

关键代码片段：

```dart
class AppStarterPage extends StatefulWidget {
  const AppStarterPage({
    super.key,
    required this.options,
  });

  final AppStarterOptions options;
}

class _AppStarterPageState extends State<AppStarterPage> {
  AppStarterStage _stage = AppStarterStage.idle;
  String? _errorMessage;
  Timer? _loginRouteTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppSessionCubit>().restoreSession();
    });
  }
}
```

### 5.2 监听 `AuthStatus` 并完成分流 `✅`

关键代码片段：

```dart
BlocListener<AppSessionCubit, AppSessionState>(
  listenWhen: (previous, current) =>
      previous.status != current.status ||
      previous.errorMessage != current.errorMessage,
  listener: (context, state) {
    switch (state.status) {
      case AuthStatus.restoring: ...
      case AuthStatus.authenticated: ...
      case AuthStatus.unauthenticated: ...
      case AuthStatus.failure: ...
      case AuthStatus.initial:
        break;
    }
  },
  child: ...
)
```

### 5.3 处理延迟跳转与失败重试 `✅`

关键代码片段：

```dart
void _scheduleLoginRoute() { ... }

void _goToRoute(String routeName) {
  Navigator.of(context).pushNamedAndRemoveUntil(routeName, (route) => false);
}

@override
void dispose() {
  _loginRouteTimer?.cancel();
  super.dispose();
}
```

---

## 任务 6：client/pubspec.yaml — 宿主接入 app_starter `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/pubspec.yaml`

改动类型：`修改`

### 6.1 新增 path dependency `✅`

关键代码片段：

```yaml
dependencies:
  flutter:
    sdk: flutter
  flash_auth:
    path: modules/flash_auth
  app_starter:
    path: modules/app_starter
```

### 6.2 保持既有依赖稳定 `✅`

本期不顺手改动 `dio`、`shared_preferences`、`web_socket_channel` 等宿主现有依赖版本。

---

## 任务 7：app_router.dart — 使用 package 启动页 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/app/app_router.dart`

改动类型：`修改`

### 7.1 `/startup` 指向 `AppStarterPage` `✅`

关键代码片段：

```dart
import 'package:app_starter/app_starter.dart';

case AppRoutes.startup:
  return MaterialPageRoute<void>(
    builder: (_) => AppStarterPage(
      options: AppStarterOptions(...),
    ),
    settings: settings,
  );
```

### 7.2 宿主传入品牌与路由配置 `✅`

关键代码片段：

```dart
AppStarterOptions(
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

## 任务 8：flash_im_app.dart — 宿主继续负责依赖注入 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/app/flash_im_app.dart`

改动类型：`修改`

### 8.1 保持 `AppSessionCubit` 注入不变 `✅`

关键代码片段：

```dart
return RepositoryProvider<AuthRepository>.value(
  value: authRepository,
  child: BlocProvider<AppSessionCubit>.value(
    value: appSessionCubit,
    child: MaterialApp(
      initialRoute: AppRoutes.startup,
      onGenerateRoute: onGenerateAppRoute,
    ),
  ),
);
```

### 8.2 不在这里重做启动流程 `✅`

宿主只负责依赖组装，不要把启动页逻辑重新塞回 `FlashImApp`。

---

## 任务 9：features/startup — 清理旧启动实现 `✅ 已完成`

文件：
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/startup/presentation/startup_page.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/startup/data/startup_coordinator_impl.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/startup/domain/app_bootstrap_snapshot.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/startup/domain/launch_destination.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/startup/domain/startup_stage.dart`

改动类型：`删除/迁移`

### 9.1 删除旧 `StartupPage` 宿主实现 `✅`

迁移完成后，宿主不再保留第二份正式启动页实现。

### 9.2 删除旧残余抽象 `✅`

删除理由：
- 当前不在正式主链路
- 会制造双份启动实现
- 容易让后续任务误接旧结构

---

## 任务 10：client/test/features/startup + widget_test.dart — 宿主测试对齐 `✅ 已完成`

文件：
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/test/features/startup/presentation/startup_page_test.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/test/widget_test.dart`

改动类型：`修改`

### 10.1 启动分流测试切到 package 页面 `✅`

关键代码片段：

```dart
expect(find.widgetWithText(FilledButton, '登录'), findsOneWidget);
expect(find.text('消息'), findsOneWidget);
expect(find.text('重试'), findsOneWidget);
```

### 10.2 宿主恢复登录态测试继续保留 `✅`

重点验证：
- `FlashImApp` 仍以 `/startup` 为入口
- 注入假 `AppSessionCubit` 后仍能正确进主页

---

## 任务 11：app_starter/test — package 自测 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/app_starter/test/app_starter_test.dart`

改动类型：`新建`

### 11.1 基础导出测试 `✅`

关键代码片段：

```dart
expect(AppStarterStage.values, isNotEmpty);
expect(
  const AppStarterRoutes(loginRouteName: '/login', homeRouteName: '/home'),
  isA<AppStarterRoutes>(),
);
```

### 11.2 可选页面渲染测试 `✅`

如果 package 内部测试环境允许注入假 `AppSessionCubit`，可补最小 widget test：

```dart
await tester.pumpWidget(
  MaterialApp(
    home: BlocProvider<AppSessionCubit>.value(
      value: cubit,
      child: AppStarterPage(options: options),
    ),
  ),
);
```

---

## 任务 12：依赖安装、格式化、分析与测试验证 `✅ 已完成`

改动类型：`验证`

### 12.1 package 依赖安装 `✅`

```bash
cd client/modules/app_starter && flutter pub get
```

### 12.2 宿主依赖安装 `✅`

```bash
cd client && flutter pub get
```

### 12.3 格式化 `✅`

```bash
cd client/modules/app_starter && dart format lib test
cd client && dart format lib test
```

### 12.4 分析 `✅`

```bash
cd client/modules/app_starter && flutter analyze
cd client && flutter analyze
```

### 12.5 测试 `✅`

```bash
cd client/modules/app_starter && flutter test
cd client && flutter test
```
