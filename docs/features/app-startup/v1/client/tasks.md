# app-startup — client 任务清单

基于 design.md 设计，列出需要创建/修改的具体细节。
全局约束：
- 本模块目标是让应用正式脱离 `playground` 首页，根入口先进入启动页，再分流到登录占位页或主页面占位页。
- 启动阶段只读取本地配置和本地认证缓存，不引入远端配置拉取、token 刷新或网络阻塞初始化。
- 认证缓存实现应参考 [`client/lib/playground/demos/auth/data/auth_session_store.dart`](/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/playground/demos/auth/data/auth_session_store.dart) 的 `shared_preferences` 用法，但不得继续沿用 playground 命名和 key。
- 本期 UI 范围仅限 `logo + Flash IM` 启动页，以及文字空白页 `登录页占位` / `主页面占位`。
- 不实现 `design.md` 中 `暂不实现` 的内容：远端配置、复杂动画、真实登录/主页业务、playground 能力合并。

---

## 执行顺序

1. ✅ 任务 1 — `client/pubspec.yaml` 注册正式 logo 资源（无依赖）
   - ✅ 1.1 增加 `assets/branding/flash_im_logo.png` 资源声明
   - ✅ 1.2 保持现有依赖不扩散
2. ✅ 任务 2 — `client/assets/branding/flash_im_logo.png` 落正式品牌资源（依赖任务 1）
   - ✅ 2.1 将用户提供的 logo 复制到应用资产目录
3. ✅ 任务 3 — `client/lib/core/config/app_config.dart` 定义本地配置模型（依赖任务 1）
   - ✅ 3.1 新增 `LocalAppConfig`
4. ✅ 任务 4 — `client/lib/core/config/local_config_store.dart` 实现本地配置读取接口（依赖任务 3）
   - ✅ 4.1 定义 `LocalConfigStore`
   - ✅ 4.2 提供默认实现
5. ✅ 任务 5 — `client/lib/core/auth/auth_cache_store.dart` 实现正式认证缓存接口（依赖任务 3）
   - ✅ 5.1 定义 `CachedAuthSession` 与 `AuthCacheStore`
   - ✅ 5.2 用 `shared_preferences` 落正式缓存实现
6. ✅ 任务 6 — `client/lib/features/startup/domain/launch_destination.dart` 与 `startup_stage.dart` 定义启动状态枚举（依赖任务 3）
   - ✅ 6.1 新增 `LaunchDestination`
   - ✅ 6.2 新增 `StartupStage`
7. ✅ 任务 7 — `client/lib/features/startup/domain/app_bootstrap_snapshot.dart` 定义启动结果聚合模型（依赖任务 3、任务 5、任务 6）
   - ✅ 7.1 新增 `AppBootstrapSnapshot`
8. ✅ 任务 8 — `client/lib/features/startup/data/startup_coordinator_impl.dart` 实现启动编排（依赖任务 4、任务 5、任务 7）
   - ✅ 8.1 定义 `StartupCoordinator`
   - ✅ 8.2 实现本地配置 + 认证缓存读取与分流
9. ✅ 任务 9 — `client/lib/features/startup/presentation/login_placeholder_page.dart` 与 `home_placeholder_page.dart` 落占位页（依赖任务 6）
   - ✅ 9.1 新增登录占位页
   - ✅ 9.2 新增主页占位页
10. ✅ 任务 10 — `client/lib/features/startup/presentation/startup_page.dart` 实现启动页与分流（依赖任务 2、任务 7、任务 8、任务 9）
    - ✅ 10.1 展示 logo + `Flash IM`
    - ✅ 10.2 驱动 bootstrap 和跳转
    - ✅ 10.3 处理启动失败与重试
11. ✅ 任务 11 — `client/lib/app/app_router.dart` 新建根路由壳层（依赖任务 9、任务 10）
    - ✅ 11.1 注册 `/startup` `/login` `/home`
12. ✅ 任务 12 — `client/lib/app/flash_im_app.dart` 接入正式启动路由（依赖任务 11）
    - ✅ 12.1 移除 `PlaygroundHomePage` 作为默认首页
    - ✅ 12.2 保持现有主题风格不被顺手重构
13. ✅ 任务 13 — `client/test/features/startup/` 新增启动模块测试（依赖任务 8、任务 10、任务 12）
    - ✅ 13.1 启动编排单测
    - ✅ 13.2 启动页分流 Widget 测试
14. ✅ 最后 — 资源、编译验证与测试路径（依赖任务 1-13）
    - ✅ 14.1 `flutter pub get`
    - ✅ 14.2 `dart format`
    - ✅ 14.3 `flutter test`
    - ✅ 14.4 手工验证启动分流

---

## 任务 1：pubspec.yaml — 注册正式 logo 资源 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/pubspec.yaml`

改动类型：`修改`

### 1.1 增加启动页 logo 资源声明 `✅`

为启动页接入正式品牌图，不要继续依赖临时网络图或 playground 图标。

关键代码片段：

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/branding/flash_im_logo.png
```

### 1.2 保持当前依赖不扩散 `✅`

本期不新增动画、状态管理或路由库依赖，避免启动模块先被第三方选型绑死。

关键代码片段：

```yaml
dependencies:
  flutter:
    sdk: flutter
  shared_preferences: ^2.5.3
```

## 任务 2：flash_im_logo.png — 落正式品牌资源 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/assets/branding/flash_im_logo.png`

改动类型：`新建`

### 2.1 复制用户提供的 logo 到客户端资产目录 `✅`

将用户提供的蓝色聊天气泡 logo 作为正式启动页资源纳入仓库。

执行要点：
1. 创建 `client/assets/branding/` 目录。
2. 将用户提供的图片复制为 `flash_im_logo.png`。
3. 启动页只引用仓库内资产路径，不直接引用下载目录。

## 任务 3：app_config.dart — 定义本地配置模型 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/core/config/app_config.dart`

改动类型：`新建`

### 3.1 新增 `LocalAppConfig` `✅`

统一承接应用名称、接口基地址和本地调试开关，避免启动页直接写散落常量。

关键代码片段：

```dart
class LocalAppConfig {
  const LocalAppConfig({
    required this.appName,
    required this.apiBaseUrl,
    required this.enableDebugTools,
  });

  final String appName;
  final String apiBaseUrl;
  final bool enableDebugTools;
}
```

## 任务 4：local_config_store.dart — 本地配置读取入口 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/core/config/local_config_store.dart`

改动类型：`新建`

### 4.1 定义配置读取接口 `✅`

让启动编排依赖抽象接口，而不是直接写死默认值。

关键代码片段：

```dart
abstract interface class LocalConfigStore {
  Future<LocalAppConfig> load();
}
```

### 4.2 提供默认实现 `✅`

本期先用应用内默认值作为本地配置来源，保持后续可平滑切到文件或环境化配置。

关键代码片段：

```dart
class DefaultLocalConfigStore implements LocalConfigStore {
  const DefaultLocalConfigStore();

  @override
  Future<LocalAppConfig> load() async {
    return const LocalAppConfig(
      appName: 'Flash IM',
      apiBaseUrl: 'http://127.0.0.1:9600',
      enableDebugTools: false,
    );
  }
}
```

## 任务 5：auth_cache_store.dart — 正式认证缓存接口与实现 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/core/auth/auth_cache_store.dart`

改动类型：`新建`

### 5.1 定义正式缓存模型与接口 `✅`

参考 [`client/lib/playground/demos/auth/data/auth_session_store.dart`](/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/playground/demos/auth/data/auth_session_store.dart) 的读写模式，但切掉 playground 语义。

关键代码片段：

```dart
class CachedAuthSession {
  const CachedAuthSession({
    required this.token,
    this.accountId,
  });

  final String token;
  final int? accountId;
}

abstract interface class AuthCacheStore {
  Future<CachedAuthSession?> read();
  Future<void> save(CachedAuthSession session);
  Future<void> clear();
}
```

### 5.2 用 `shared_preferences` 落正式实现 `✅`

缓存 key 要改成正式应用命名，避免与 playground 混用。

关键代码片段：

```dart
class SharedPreferencesAuthCacheStore implements AuthCacheStore {
  static const String _tokenKey = 'flash_im.auth.token';
  static const String _accountIdKey = 'flash_im.auth.account_id';

  @override
  Future<CachedAuthSession?> read() async { ... }

  @override
  Future<void> save(CachedAuthSession session) async { ... }

  @override
  Future<void> clear() async { ... }
}
```

## 任务 6：launch_destination.dart + startup_stage.dart — 启动状态枚举 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/startup/domain/launch_destination.dart`

改动类型：`新建`

### 6.1 定义 `LaunchDestination` `✅`

关键代码片段：

```dart
enum LaunchDestination {
  login,
  home,
}
```

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/startup/domain/startup_stage.dart`

改动类型：`新建`

### 6.2 定义 `StartupStage` `✅`

关键代码片段：

```dart
enum StartupStage {
  idle,
  loading,
  ready,
  failed,
}
```

## 任务 7：app_bootstrap_snapshot.dart — 启动结果聚合模型 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/startup/domain/app_bootstrap_snapshot.dart`

改动类型：`新建`

### 7.1 定义 `AppBootstrapSnapshot` `✅`

把启动后要流转的结果一次性打包，避免页面层再重复读取配置或缓存。

关键代码片段：

```dart
class AppBootstrapSnapshot {
  const AppBootstrapSnapshot({
    required this.destination,
    required this.hasAuthSession,
    required this.config,
  });

  final LaunchDestination destination;
  final bool hasAuthSession;
  final LocalAppConfig config;
}
```

## 任务 8：startup_coordinator_impl.dart — 启动编排主逻辑 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/startup/data/startup_coordinator_impl.dart`

改动类型：`新建`

### 8.1 定义 `StartupCoordinator` 接口与默认实现 `✅`

关键代码片段：

```dart
abstract interface class StartupCoordinator {
  Future<AppBootstrapSnapshot> bootstrap();
}

class DefaultStartupCoordinator implements StartupCoordinator {
  const DefaultStartupCoordinator({
    required LocalConfigStore configStore,
    required AuthCacheStore authCacheStore,
  }) : _configStore = configStore,
       _authCacheStore = authCacheStore;

  final LocalConfigStore _configStore;
  final AuthCacheStore _authCacheStore;
}
```

### 8.2 实现本地启动编排步骤 `✅`

函数体不要直接展开完整实现，但必须按以下步骤组织：

关键代码片段：

```dart
@override
Future<AppBootstrapSnapshot> bootstrap() async {
  // 1. load local config
  // 2. read cached auth session
  // 3. on parse failure -> clear cache -> go login
  // 4. map session existence to LaunchDestination
  // 5. return AppBootstrapSnapshot
}
```

异常约束：
1. 配置读取失败 -> 抛出异常给页面层处理 failed 态。
2. 缓存损坏 -> 清理缓存并回退 `login`，不要直接抛致命错误。

## 任务 9：placeholder pages — 登录页/主页占位 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/startup/presentation/login_placeholder_page.dart`

改动类型：`新建`

### 9.1 新增登录页占位 `✅`

关键代码片段：

```dart
class LoginPlaceholderPage extends StatelessWidget {
  const LoginPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('登录页占位'),
      ),
    );
  }
}
```

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/startup/presentation/home_placeholder_page.dart`

改动类型：`新建`

### 9.2 新增主页占位 `✅`

关键代码片段：

```dart
class HomePlaceholderPage extends StatelessWidget {
  const HomePlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('主页面占位'),
      ),
    );
  }
}
```

## 任务 10：startup_page.dart — 启动页与分流页面 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/startup/presentation/startup_page.dart`

改动类型：`新建`

### 10.1 展示品牌启动页骨架 `✅`

关键 Widget 树：

```dart
Scaffold(
  backgroundColor: Colors.white,
  body: SafeArea(
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/branding/flash_im_logo.png', width: 132),
          SizedBox(height: 20),
          Text('Flash IM'),
          SizedBox(height: 12),
          Text('正在启动'),
        ],
      ),
    ),
  ),
)
```

### 10.2 驱动 bootstrap 并在成功后跳转 `✅`

关键代码片段：

```dart
class StartupPage extends StatefulWidget {
  const StartupPage({super.key, StartupCoordinator? coordinator})
      : _coordinator = coordinator;

  final StartupCoordinator? _coordinator;
}

class _StartupPageState extends State<StartupPage> {
  StartupStage _stage = StartupStage.idle;

  Future<void> _bootstrap() async { ... }
  void _goToDestination(LaunchDestination destination) { ... }
}
```

逻辑步骤：
1. `initState()` 触发 `_bootstrap()`
2. loading -> 调 coordinator
3. success -> `pushReplacement` 到登录/主页占位页
4. failed -> 留在本页展示错误文案和重试按钮

### 10.3 处理失败态与重试 `✅`

关键代码片段：

```dart
if (_stage == StartupStage.failed) ...[
  const Text('启动失败，请重试'),
  FilledButton(
    onPressed: _bootstrap,
    child: const Text('重试'),
  ),
]
```

## 任务 11：app_router.dart — 根路由壳层 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/app/app_router.dart`

改动类型：`新建`

### 11.1 建立正式启动路由表 `✅`

本期不引入第三方路由库，先用原生 `routes` / `onGenerateRoute` 即可。

关键代码片段：

```dart
abstract final class AppRoutes {
  static const startup = '/startup';
  static const login = '/login';
  static const home = '/home';
}

Route<dynamic>? onGenerateAppRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.startup:
      return MaterialPageRoute(builder: (_) => const StartupPage());
    case AppRoutes.login:
      return MaterialPageRoute(builder: (_) => const LoginPlaceholderPage());
    case AppRoutes.home:
      return MaterialPageRoute(builder: (_) => const HomePlaceholderPage());
  }
  return null;
}
```

## 任务 12：flash_im_app.dart — 接入正式启动入口 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/app/flash_im_app.dart`

改动类型：`修改`

### 12.1 移除 `PlaygroundHomePage` 作为默认首页 `✅`

当前正式应用入口不能再直接落到 playground。

关键代码片段：

```dart
return MaterialApp(
  title: 'Flash IM',
  debugShowCheckedModeBanner: false,
  theme: ...,
  initialRoute: AppRoutes.startup,
  onGenerateRoute: onGenerateAppRoute,
);
```

### 12.2 保持现有主题方向稳定 `✅`

保留已有 `ColorScheme.fromSeed` 和暗色基调，不要在启动模块任务里顺手重构整套主题。

## 任务 13：startup tests — 启动模块测试 `✅ 已完成`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/test/features/startup/data/startup_coordinator_impl_test.dart`

改动类型：`新建`

### 13.1 覆盖启动编排单测 `✅`

至少覆盖：
1. 无缓存 -> 返回 `LaunchDestination.login`
2. 有 token -> 返回 `LaunchDestination.home`
3. 缓存损坏 -> 清理缓存并返回 `login`

关键代码片段：

```dart
test('bootstrap goes to login when no cached session', () async { ... });
test('bootstrap goes to home when token exists', () async { ... });
test('bootstrap clears corrupted cache and falls back to login', () async { ... });
```

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/test/features/startup/presentation/startup_page_test.dart`

改动类型：`新建`

### 13.2 覆盖启动页分流与失败态 Widget 测试 `✅`

至少覆盖：
1. 成功后跳到 `登录页占位`
2. 成功后跳到 `主页面占位`
3. coordinator 抛错时展示 `启动失败，请重试`

关键代码片段：

```dart
testWidgets('startup page routes to login placeholder', (tester) async { ... });
testWidgets('startup page routes to home placeholder', (tester) async { ... });
testWidgets('startup page shows retry on bootstrap failure', (tester) async { ... });
```

## 任务 14：编译验证 + 测试路径 `✅ 已完成`

文件：`无单一文件，执行验证`

改动类型：`配置/验证`

### 14.1 依赖与格式化验证 `✅`

执行：

```bash
cd client
flutter pub get
dart format lib test
```

### 14.2 自动化测试验证 `✅`

执行：

```bash
cd client
flutter test
```

### 14.3 手工启动链路验证 `✅`

至少覆盖以下路径：
1. 首次安装或清缓存 -> 启动页后进入 `登录页占位`
2. 本地存在 token -> 启动页后进入 `主页面占位`
3. 人为破坏认证缓存 -> 启动页不崩溃，并回退到 `登录页占位`
