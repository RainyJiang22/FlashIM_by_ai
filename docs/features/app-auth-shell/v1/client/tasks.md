# app-auth-shell — client 任务清单

基于 design.md 设计，列出需要创建/修改的具体细节。
全局约束：
- 正式认证主链路必须继续脱离 `playground`，产品入口只走 `client/lib/main.dart -> FlashImApp -> StartupPage -> /login or /home`。
- 状态管理只保留一个全局 `AppSessionCubit`；登录页、设置密码弹窗、底部 Tab、“我的”页资料加载都使用页面局部状态。
- 页面不得直接读写 `SharedPreferences`，Token 持久化统一走 [`client/lib/core/auth/auth_cache_store.dart`](/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/core/auth/auth_cache_store.dart) 和正式 `AuthRepository`。
- 登录页和“我的”页可参考 [`client/lib/playground/demos/auth/presentation/auth_playground_page.dart`](/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/playground/demos/auth/presentation/auth_playground_page.dart) 与 [`client/lib/playground/demos/auth/presentation/auth_profile_page.dart`](/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/playground/demos/auth/presentation/auth_profile_page.dart)，但不能把验证码展示卡片和 Token 调试卡片带进正式产品。
- 启动阶段只恢复本地登录态，不在冷启动阶段额外发远端请求校验 token；首次真实接口发现 `401` 时统一回收登录态。
- 不实现 `design.md` 中暂不实现内容：消息真实列表、通讯录真实联系人、修改密码、忘记密码、注册、refresh token、启动期联网鉴权、为每个页面再单独拆 Cubit。

---

## 执行顺序

1. ⬜ 任务 1 — `client/pubspec.yaml` 接入 `flutter_bloc` 依赖（无依赖）
   - ⬜ 1.1 新增 `flutter_bloc`
   - ⬜ 1.2 保持现有 `dio`、`shared_preferences` 版本不被顺手调整
2. ⬜ 任务 2 — `client/lib/features/auth/domain/` 新建正式认证领域模型（依赖任务 1）
   - ⬜ 2.1 新增 `auth_status.dart`
   - ⬜ 2.2 新增 `login_method.dart`
   - ⬜ 2.3 新增 `app_session.dart`
   - ⬜ 2.4 新增 `auth_profile.dart`
3. ⬜ 任务 3 — `client/lib/features/auth/data/models/` 新建认证 DTO（依赖任务 2）
   - ⬜ 3.1 新增 `auth_session_dto.dart`
   - ⬜ 3.2 新增 `auth_profile_dto.dart`
   - ⬜ 3.3 新增 `sms_code_dto.dart`
   - ⬜ 3.4 新增 `password_setup_result_dto.dart`
4. ⬜ 任务 4 — `client/lib/features/auth/data/auth_api.dart` 实现认证接口访问层（依赖任务 3）
   - ⬜ 4.1 定义请求接口
   - ⬜ 4.2 落 `Dio` 实现
5. ⬜ 任务 5 — `client/lib/features/auth/data/auth_repository.dart` 实现仓储与映射（依赖任务 4）
   - ⬜ 5.1 定义正式仓储接口
   - ⬜ 5.2 接入 `AuthCacheStore`
   - ⬜ 5.3 处理缺失 token / 401 场景
6. ⬜ 任务 6 — `client/lib/features/auth/cubit/app_session_cubit.dart` 落全局会话状态中心（依赖任务 5）
   - ⬜ 6.1 定义 `AppSessionState`
   - ⬜ 6.2 实现 `restoreSession / completeLogin / refreshProfile / logout`
   - ⬜ 6.3 统一清理失效 token
7. ⬜ 任务 7 — `client/lib/features/auth/presentation/widgets/auth_login_mode_switch.dart` 抽登录方式切换控件（依赖任务 2）
   - ⬜ 7.1 沿用 playground 的双模式切换思路
8. ⬜ 任务 8 — `client/lib/features/auth/presentation/dialogs/password_setup_prompt.dart` 落设置密码提示弹窗（依赖任务 5、任务 6）
   - ⬜ 8.1 使用页面局部状态维护输入和提交中
   - ⬜ 8.2 成功后回写 `AppSessionCubit`
9. ⬜ 任务 9 — `client/lib/features/auth/presentation/login_page.dart` 落正式登录页（依赖任务 5、任务 6、任务 7）
   - ⬜ 9.1 构建简约登录 UI
   - ⬜ 9.2 页面内维护验证码倒计时和提交状态
   - ⬜ 9.3 登录成功后把结果交给 `AppSessionCubit`
10. ⬜ 任务 10 — `client/lib/features/auth/presentation/me/me_page.dart` 落正式“我的”页（依赖任务 5、任务 6）
    - ⬜ 10.1 参考 playground 资料页结构
    - ⬜ 10.2 使用页面内异步加载资料
    - ⬜ 10.3 保留简易退出登录
11. ⬜ 任务 11 — `client/lib/features/messages/presentation/messages_placeholder_page.dart` 与 `contacts/presentation/contacts_placeholder_page.dart` 落两个留白页（依赖任务 1）
    - ⬜ 11.1 新增消息页占位
    - ⬜ 11.2 新增通讯录页占位
12. ⬜ 任务 12 — `client/lib/features/main_shell/presentation/main_shell_page.dart` 落主壳层（依赖任务 6、任务 8、任务 10、任务 11）
    - ⬜ 12.1 页面内维护当前 Tab index
    - ⬜ 12.2 根据会话态弹出设置密码提示框
13. ⬜ 任务 13 — `client/lib/features/startup/presentation/startup_page.dart` 改为驱动 `AppSessionCubit` 恢复登录态（依赖任务 6、任务 12）
    - ⬜ 13.1 去掉页面内自持的登录分流事实源
    - ⬜ 13.2 仅负责品牌展示与状态跳转
14. ⬜ 任务 14 — `client/lib/app/app_router.dart` 接入正式登录页和主壳层（依赖任务 9、任务 12、任务 13）
    - ⬜ 14.1 `/login` 指向 `LoginPage`
    - ⬜ 14.2 `/home` 指向 `MainShellPage`
15. ⬜ 任务 15 — `client/lib/app/flash_im_app.dart` 注入全局依赖与 `AppSessionCubit`（依赖任务 5、任务 6、任务 14）
    - ⬜ 15.1 创建正式 `AuthRepository`
    - ⬜ 15.2 注入 `AppSessionCubit`
    - ⬜ 15.3 保持现有全局背景和主题方向
16. ⬜ 任务 16 — `client/test/features/auth/` 新增认证层测试（依赖任务 5、任务 6）
    - ⬜ 16.1 仓储测试
    - ⬜ 16.2 `AppSessionCubit` 单测
17. ⬜ 任务 17 — `client/test/features/auth/` 与 `client/test/features/main_shell/` 新增 Widget 测试（依赖任务 8-15）
    - ⬜ 17.1 登录页 Widget 测试
    - ⬜ 17.2 主壳层 Tab 与弹窗测试
    - ⬜ 17.3 启动恢复路由测试
18. ⬜ 最后 — 依赖安装、格式化、编译验证与手工路径（依赖任务 1-17）
    - ⬜ 18.1 `flutter pub get`
    - ⬜ 18.2 `dart format lib test`
    - ⬜ 18.3 `flutter test`
    - ⬜ 18.4 手工验证启动恢复、登录、退出、无密码提示框

---

## 任务 1：pubspec.yaml — 接入 `flutter_bloc` `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/pubspec.yaml`

改动类型：`修改`

### 1.1 新增 `flutter_bloc` 依赖 `⬜`

正式产品只保留一个全局 `AppSessionCubit`，因此依赖新增范围很小。

关键代码片段：

```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.9.0
  shared_preferences: ^2.5.3
  flutter_bloc: ^9.1.1
```

### 1.2 保持现有基础依赖不扩散 `⬜`

本期不顺手引入 `go_router`、本地数据库、表单框架或额外状态管理库。

## 任务 2：auth/domain — 正式认证领域模型 `⬜ 待处理`

文件：
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/auth/domain/auth_status.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/auth/domain/login_method.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/auth/domain/app_session.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/auth/domain/auth_profile.dart`

改动类型：`新建`

### 2.1 新增 `AuthStatus` 与 `LoginMethod` `⬜`

关键代码片段：

```dart
enum AuthStatus {
  initial,
  restoring,
  unauthenticated,
  authenticated,
  failure,
}

enum LoginMethod {
  smsCode,
  password,
}
```

### 2.2 新增 `AppSession` `⬜`

关键代码片段：

```dart
class AppSession {
  const AppSession({
    required this.token,
    required this.accountId,
    required this.passwordSetupRequired,
  });

  final String token;
  final int accountId;
  final bool passwordSetupRequired;
}
```

### 2.3 新增 `AuthProfile` `⬜`

关键代码片段：

```dart
class AuthProfile {
  const AuthProfile({
    required this.accountId,
    required this.nickname,
    required this.avatarUrl,
    required this.phone,
    required this.hasPassword,
  });

  final int accountId;
  final String nickname;
  final String avatarUrl;
  final String phone;
  final bool hasPassword;
}
```

## 任务 3：auth/data/models — 认证 DTO `⬜ 待处理`

文件：
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/auth/data/models/auth_session_dto.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/auth/data/models/auth_profile_dto.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/auth/data/models/sms_code_dto.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/auth/data/models/password_setup_result_dto.dart`

改动类型：`新建`

### 3.1 新增登录与资料 DTO `⬜`

关键代码片段：

```dart
class AuthSessionDto {
  const AuthSessionDto({
    required this.token,
    required this.accountId,
    required this.passwordSetupRequired,
  });

  factory AuthSessionDto.fromJson(Map<String, dynamic> json) { ... }
}

class AuthProfileDto {
  const AuthProfileDto({
    required this.accountId,
    required this.nickname,
    required this.avatar,
    required this.phone,
    required this.hasPassword,
  });

  factory AuthProfileDto.fromJson(Map<String, dynamic> json) { ... }
}
```

### 3.2 新增短信与设置密码 DTO `⬜`

关键代码片段：

```dart
class SmsCodeDto {
  const SmsCodeDto({required this.phone, required this.code});

  factory SmsCodeDto.fromJson(Map<String, dynamic> json) { ... }
}

class PasswordSetupResultDto {
  const PasswordSetupResultDto({
    required this.passwordSetupRequired,
    required this.updatedAt,
  });

  factory PasswordSetupResultDto.fromJson(Map<String, dynamic> json) { ... }
}
```

## 任务 4：auth_api.dart — 认证接口访问层 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/auth/data/auth_api.dart`

改动类型：`新建`

### 4.1 定义正式认证请求接口 `⬜`

关键代码片段：

```dart
abstract interface class AuthApi {
  Future<SmsCodeDto> sendSmsCode({required String phone});

  Future<AuthSessionDto> loginWithSmsCode({
    required String phone,
    required String code,
  });

  Future<AuthSessionDto> loginWithPassword({
    required String identifier,
    required String password,
  });

  Future<AuthProfileDto> fetchProfile({required String token});

  Future<PasswordSetupResultDto> setPassword({
    required String token,
    required String newPassword,
  });
}
```

### 4.2 落 `Dio` 实现 `⬜`

复用 [`client/lib/core/network/dio_factory.dart`](/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/core/network/dio_factory.dart)，通过 `Authorization` 头访问认证接口。

## 任务 5：auth_repository.dart — 正式认证仓储 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/auth/data/auth_repository.dart`

改动类型：`新建`

### 5.1 定义正式仓储接口 `⬜`

仓储负责 DTO 到 domain 的映射、token 持久化和无 token 保护，不负责页面跳转。

关键代码片段：

```dart
abstract interface class AuthRepository {
  Future<CachedAuthSession?> readCachedSession();
  Future<AppSession> loginWithSmsCode({
    required String phone,
    required String code,
  });
  Future<AppSession> loginWithPassword({
    required String identifier,
    required String password,
  });
  Future<void> persistSession(AppSession session);
  Future<AuthProfile> fetchProfile();
  Future<void> setPassword({required String newPassword});
  Future<void> logout();
}
```

### 5.2 接入正式缓存与异常类型 `⬜`

关键代码片段：

```dart
class DefaultAuthRepository implements AuthRepository {
  DefaultAuthRepository({
    required AuthApi api,
    required AuthCacheStore cacheStore,
  }) : _api = api,
       _cacheStore = cacheStore;
}

class AuthMissingTokenException implements Exception { ... }
```

### 5.3 映射与持久化规则 `⬜`

登录页不直接写缓存；登录成功后把 `AppSession` 交给会话层，由会话层决定何时持久化。

## 任务 6：app_session_cubit.dart — 全局会话状态中心 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/auth/cubit/app_session_cubit.dart`

改动类型：`新建`

### 6.1 定义 `AppSessionState` `⬜`

关键代码片段：

```dart
class AppSessionState {
  const AppSessionState({
    required this.status,
    this.session,
    this.profile,
    this.errorMessage,
    this.shouldPromptPasswordSetup = false,
  });
}
```

### 6.2 实现恢复、登录完成、资料刷新、退出登录 `⬜`

关键代码片段：

```dart
class AppSessionCubit extends Cubit<AppSessionState> {
  AppSessionCubit({required AuthRepository repository}) : ...;

  Future<void> restoreSession() async { ... }

  Future<void> completeLogin(AppSession session) async { ... }

  Future<void> refreshProfile() async { ... }

  Future<void> logout() async { ... }

  void markPasswordPromptHandled() { ... }
}
```

### 6.3 统一 401 / token 缺失处理 `⬜`

任何全局鉴权失败都收敛到这里，避免每个页面自己清缓存。

## 任务 7：auth_login_mode_switch.dart — 登录方式切换控件 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/auth/presentation/widgets/auth_login_mode_switch.dart`

改动类型：`新建`

### 7.1 抽出短信验证码 / 密码两种模式切换 `⬜`

关键代码片段：

```dart
class AuthLoginModeSwitch extends StatelessWidget {
  const AuthLoginModeSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final LoginMethod value;
  final ValueChanged<LoginMethod> onChanged;
}
```

## 任务 8：password_setup_prompt.dart — 设置密码提示弹窗 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/auth/presentation/dialogs/password_setup_prompt.dart`

改动类型：`新建`

### 8.1 使用页面局部状态维护弹窗输入和提交中 `⬜`

不要再为这个一次性弹窗单独拆 Cubit。

关键代码片段：

```dart
class PasswordSetupPromptDialog extends StatefulWidget {
  const PasswordSetupPromptDialog({
    super.key,
    required this.repository,
    required this.appSessionCubit,
  });
}
```

### 8.2 设置密码成功后回写会话态 `⬜`

成功后刷新 `AppSessionCubit`，并关闭弹窗。

## 任务 9：login_page.dart — 正式登录页 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/auth/presentation/login_page.dart`

改动类型：`新建`

### 9.1 构建简约风格登录主结构 `⬜`

页面风格参考 playground 登录，但收敛成正式产品首个业务页。

关键代码片段：

```dart
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
}
```

### 9.2 页面内维护验证码倒计时和提交状态 `⬜`

关键状态：

```dart
LoginMethod _method = LoginMethod.smsCode;
bool _isSendingCode = false;
bool _isSubmitting = false;
int _cooldownSeconds = 0;
String? _inlineError;
Timer? _countdownTimer;
```

### 9.3 登录成功后把结果交给 `AppSessionCubit` `⬜`

登录页只负责拿到 `AppSession` 并调用：

```dart
context.read<AppSessionCubit>().completeLogin(session);
```

### 9.4 监听会话态跳转到主壳层 `⬜`

通过 `BlocListener<AppSessionCubit, AppSessionState>` 监听 `authenticated`，跳到 `AppRoutes.home`。

## 任务 10：me_page.dart — 正式“我的”页 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/auth/presentation/me/me_page.dart`

改动类型：`新建`

### 10.1 参考 playground 资料页结构但移除调试信息 `⬜`

保留头像、昵称、手机号、账户 ID 和退出登录按钮，不展示 token。

### 10.2 使用页面内异步加载资料 `⬜`

可以用 `FutureBuilder` 或页面内 `Future<AuthProfile>`，不单独拆 `ProfileCubit`。

关键代码片段：

```dart
late Future<AuthProfile> _profileFuture;
```

### 10.3 发现 401 时统一回收登录态 `⬜`

如果资料接口返回 `401`，调用 `context.read<AppSessionCubit>().logout()`。

## 任务 11：messages / contacts 占位页 `⬜ 待处理`

文件：
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/messages/presentation/messages_placeholder_page.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/contacts/presentation/contacts_placeholder_page.dart`

改动类型：`新建`

### 11.1 新增消息占位页 `⬜`

关键代码片段：

```dart
class MessagesPlaceholderPage extends StatelessWidget {
  const MessagesPlaceholderPage({super.key});
}
```

### 11.2 新增通讯录占位页 `⬜`

占位页只使用简洁文案，不提前引入假列表。

## 任务 12：main_shell_page.dart — 正式主壳层 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/main_shell/presentation/main_shell_page.dart`

改动类型：`新建`

### 12.1 页面内维护当前 Tab index `⬜`

当前只有 3 个固定 Tab，不额外拆 `MainTabCubit`。

关键代码片段：

```dart
class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});
}

int _currentIndex = 0;
```

### 12.2 根据会话态弹出设置密码提示框 `⬜`

通过 `BlocListener<AppSessionCubit, AppSessionState>` 监听 `shouldPromptPasswordSetup`。

### 12.3 组合三个子页面 `⬜`

页面主体依次组合：
- `MessagesPlaceholderPage`
- `ContactsPlaceholderPage`
- `MePage`

## 任务 13：startup_page.dart — 仅负责启动恢复与跳转 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/features/startup/presentation/startup_page.dart`

改动类型：`修改`

### 13.1 从 `StartupCoordinator` 切到 `AppSessionCubit.restoreSession()` `⬜`

当前启动页内置了一套本地分流事实源，需要收敛到全局会话态。

关键代码片段：

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  context.read<AppSessionCubit>().restoreSession();
});
```

### 13.2 通过状态监听跳页 `⬜`

根据 `AuthStatus` 跳转 `/login` 或 `/home`，保留现有品牌启动页视觉。

## 任务 14：app_router.dart — 正式路由接线 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/app/app_router.dart`

改动类型：`修改`

### 14.1 `/login` 指向 `LoginPage` `⬜`

替换当前 `LoginPlaceholderPage`。

### 14.2 `/home` 指向 `MainShellPage` `⬜`

替换当前 `HomePlaceholderPage`。

### 14.3 保持 `/startup` 作为产品根入口 `⬜`

不把 playground 路由重新接回正式入口。

## 任务 15：flash_im_app.dart — 根级依赖与会话态注入 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/app/flash_im_app.dart`

改动类型：`修改`

### 15.1 创建正式认证依赖图 `⬜`

关键代码片段：

```dart
final config = await const DefaultLocalConfigStore().load();
final authApi = DioAuthApi(
  dio: DioFactory.create(baseUrl: config.apiBaseUrl),
);
final authRepository = DefaultAuthRepository(
  api: authApi,
  cacheStore: const SharedPreferencesAuthCacheStore(),
);
```

### 15.2 注入 `AppSessionCubit` 到根树 `⬜`

关键代码片段：

```dart
RepositoryProvider.value(
  value: authRepository,
  child: BlocProvider(
    create: (_) => AppSessionCubit(repository: authRepository),
    child: MaterialApp(...),
  ),
)
```

### 15.3 保持现有背景主色 `#FFF6F7F9` `⬜`

认证模块接入时不顺手改掉当前已定主题。

## 任务 16：test/features/auth — 认证层测试 `⬜ 待处理`

文件：
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/test/features/auth/data/auth_repository_test.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/test/features/auth/cubit/app_session_cubit_test.dart`

改动类型：`新建`

### 16.1 仓储测试 `⬜`

验证 DTO 映射、token 持久化、无 token 抛错、资料读取等基础行为。

### 16.2 `AppSessionCubit` 单测 `⬜`

覆盖启动恢复、登录成功、401 回退、退出登录、密码提示标记处理等关键状态流。

## 任务 17：Widget 测试 `⬜ 待处理`

文件：
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/test/features/auth/presentation/login_page_test.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/test/features/main_shell/presentation/main_shell_page_test.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/test/features/startup/presentation/startup_page_test.dart`

改动类型：`新建 / 修改`

### 17.1 登录页 Widget 测试 `⬜`

验证两种登录模式切换、按钮 loading、错误文案展示。

### 17.2 主壳层与弹窗测试 `⬜`

验证三个 Tab 可切换，以及 `shouldPromptPasswordSetup = true` 时会弹出设置密码框。

### 17.3 启动恢复路由测试 `⬜`

把现有启动页测试从 `StartupCoordinator` 分流改成 `AppSessionCubit` 分流。

## 最后：依赖安装、格式化、编译验证与手工路径 `⬜ 待处理`

改动类型：`验证`

### 18.1 拉取依赖 `⬜`

```bash
cd /Users/rainyjiang/AndroidStudioProjects/flash_im/client
flutter pub get
```

### 18.2 代码格式化 `⬜`

```bash
cd /Users/rainyjiang/AndroidStudioProjects/flash_im/client
dart format lib test
```

### 18.3 自动化测试 `⬜`

```bash
cd /Users/rainyjiang/AndroidStudioProjects/flash_im/client
flutter test
```

### 18.4 手工验证路径 `⬜`

至少手动确认：
1. 冷启动无 token 进入登录页。
2. 短信验证码登录成功后进入主壳层。
3. 未设置密码账号会弹出设置密码提示框。
4. 已有 token 冷启动直接进入主壳层。
5. “我的”页退出登录后回到登录页且不保留主壳层返回栈。
