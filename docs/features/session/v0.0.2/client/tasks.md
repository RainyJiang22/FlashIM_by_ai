# session v0.0.2 — 客户端任务清单

基于 [design.md](./design.md) 设计，列出从当前 `flash_auth + mine` 结构迁移到 `flash_session` 模块的具体实施步骤。

全局约束：
- 本清单只覆盖 `client/`；`头像上传`、`手机号换绑`、`邮箱绑定` 继续不实现。
- `ProfilePage` 保留在主工程 `client/lib/features/mine/presentation/`；`flash_session` 只承载 data / logic / view 和可复用组件。
- 模块分层、依赖注入和 API 封装方式对齐 `client/modules/flash_auth/`，但会把资料、密码、会话状态职责迁出 `flash_auth`。
- 默认头像只认 `identicon:{seed}` 标记，本地 `CustomPainter` 渲染；不要再依赖随机网络头像作为默认值。
- 名字、签名采用“进入子页编辑，点完成后提交”的即时保存；手机号只展示脱敏值，不可编辑。
- 现有承接入口是 `client/lib/features/mine/presentation/mine_page.dart`、`client/lib/features/home/presentation/main_shell_page.dart`、`client/modules/flash_auth/lib/src/presentation/login_page.dart`，实现时要从这些真实文件迁移，而不是按设计稿虚构路径落代码。

---

## 执行顺序

1. ✅ 任务 1 — `client/modules/flash_session/pubspec.yaml` + `client/pubspec.yaml` 建立新模块依赖（无依赖）
   - ✅ 1.1 创建 `flash_session` package 元数据与基础依赖
   - ✅ 1.2 主工程接入 `flash_session` path dependency
2. ✅ 任务 2 — `client/modules/flash_session/lib/flash_session.dart` 建立 barrel file（依赖任务 1）
   - ✅ 2.1 导出 data / logic / view 公开入口
3. ✅ 任务 3 — `client/modules/flash_session/lib/src/data/user.dart` 定义资料实体（依赖任务 1）
   - ✅ 3.1 新增 `signature` / identicon 辅助 getter
   - ✅ 3.2 提供 `fromJson` / `toJson`
4. ✅ 任务 4 — `client/modules/flash_session/lib/src/data/session_api.dart` + `session_repository.dart` 落地资料与密码接口（依赖任务 3）
   - ✅ 4.1 定义 `/user/profile`、`/user/password` API
   - ✅ 4.2 仓储承接缓存、资料查询、资料更新、设置密码、修改密码
5. ✅ 任务 5 — `client/modules/flash_session/lib/src/logic/session_state.dart` + `session_cubit.dart` 建立全局会话状态（依赖任务 4）
   - ✅ 5.1 迁入 restore / completeLogin / logout / refreshProfile
   - ✅ 5.2 新增 updateProfile / setPassword / changePassword
6. ✅ 任务 6 — `client/modules/flash_auth/lib/src/{data/auth_api.dart,data/auth_repository.dart,presentation/login_page.dart}` + `flash_auth.dart` 收缩为登录模块（依赖任务 5）
   - ✅ 6.1 删除资料/密码接口暴露
   - ✅ 6.2 `LoginPage` 通过回调把登录成功结果交给 `SessionCubit`
7. ✅ 任务 7 — `client/lib/app/flash_im_app.dart` 注入 `SessionRepository` / `SessionCubit`（依赖任务 5、6）
   - ✅ 7.1 主工程同时提供 `AuthRepository` 与 `SessionRepository`
   - ✅ 7.2 全局 Bloc 从 `AppSessionCubit` 切换到 `SessionCubit`
8. ✅ 任务 8 — `client/lib/app/app_router.dart` 增加 session 页面路由（依赖任务 7）
   - ✅ 8.1 注册 `EditProfilePage` / `SetPasswordPage` / `ChangePasswordPage`
   - ✅ 8.2 登录页注入 `onLoginSuccess`
9. ✅ 任务 9 — `client/modules/flash_session/lib/src/view/widget/identicon_avatar.dart` + `user_card.dart` 实现复用组件（依赖任务 3）
   - ✅ 9.1 `IdenticonAvatar` 支持 identicon / 占位
   - ✅ 9.2 `UserCard` / `UserAvatar` 封装微信风格资料卡
10. ✅ 任务 10 — `client/modules/flash_session/lib/src/view/set_password_page.dart` 首次设置密码页（依赖任务 5、8）
    - ✅ 10.1 单输入框 + 校验 + 调 `setPassword`
11. ✅ 任务 11 — `client/modules/flash_session/lib/src/view/change_password_page.dart` 修改密码页（依赖任务 5、8）
    - ✅ 11.1 双输入框 + 401 错误提示 + 调 `changePassword`
12. ✅ 任务 12 — `client/modules/flash_session/lib/src/view/edit_profile_page.dart` 个人资料编辑页（依赖任务 5、8、9）
    - ✅ 12.1 名字/签名即时保存
    - ✅ 12.2 头像随机更换与完成保存
13. ✅ 任务 13 — `client/lib/features/home/presentation/main_shell_page.dart` + `features/mine/presentation/dialogs/password_setup_prompt_dialog.dart` 接入新密码流程（依赖任务 8、10、11）
    - ✅ 13.1 监听 `SessionCubit`
    - ✅ 13.2 首次密码提示跳转 `SetPasswordPage`
14. ✅ 任务 14 — `client/lib/features/mine/presentation/mine_page.dart` + `widgets/mine_info_card.dart` 改造主工程资料页（依赖任务 8、9、10、11、12、13）
    - ✅ 14.1 顶部替换为 `UserCard`
    - ✅ 14.2 密码入口根据 `hasPassword` 分流
15. ✅ 任务 15 — 模块边界清理、测试补齐、编译验证（依赖任务 1-14）
   - ✅ 15.1 清理旧 `AppSessionCubit` / `AuthProfile` 引用
   - ✅ 15.2 更新或新增 session / mine / auth 相关测试
   - ✅ 15.3 执行 `flutter analyze` 与目标测试

---

## 任务 1：`client/modules/flash_session/pubspec.yaml` + `client/pubspec.yaml` — 建立新模块依赖 `✅ 已完成`

文件：
- `client/modules/flash_session/pubspec.yaml`
- `client/pubspec.yaml`

改动类型：
- `新建`
- `配置修改`

### 1.1 创建 `flash_session` package 元数据与基础依赖 `✅`

关键配置骨架：

```yaml
name: flash_session
description: "Flash IM session feature package."
version: 0.0.1

environment:
  sdk: ^3.11.5
  flutter: ">=1.17.0"

dependencies:
  flutter:
    sdk: flutter
  dio: ^5.9.0
  flutter_bloc: ^9.1.1
  flash_auth:
    path: ../flash_auth
```

说明：
- 这里沿用 `flash_auth` 的 package 组织方式。
- 当前轮先复用 `flash_auth` 里的 `AppSession` 登录结果类型，避免在两个模块间制造循环依赖。

### 1.2 主工程接入 `flash_session` path dependency `✅`

关键配置骨架：

```yaml
dependencies:
  flash_auth:
    path: modules/flash_auth
  flash_session:
    path: modules/flash_session
```

说明：
- 不要顺手调整其他 package 版本；本任务只补 session feature 所需依赖。

---

## 任务 2：`client/modules/flash_session/lib/flash_session.dart` — 建立模块公开入口 `✅ 已完成`

文件：`client/modules/flash_session/lib/flash_session.dart`

改动类型：`新建`

### 2.1 导出 data / logic / view 公开入口 `✅`

关键代码骨架：

```dart
library;

export 'src/data/session_api.dart' show SessionApi, DioSessionApi;
export 'src/data/session_repository.dart'
    show SessionRepository, DefaultSessionRepository, SessionMissingTokenException;
export 'src/data/user.dart' show User;
export 'src/logic/session_cubit.dart' show SessionCubit;
export 'src/logic/session_state.dart' show SessionState, SessionStatus;
export 'src/view/change_password_page.dart' show ChangePasswordPage;
export 'src/view/edit_profile_page.dart' show EditProfilePage;
export 'src/view/set_password_page.dart' show SetPasswordPage;
export 'src/view/widget/identicon_avatar.dart' show IdenticonAvatar;
export 'src/view/widget/user_card.dart' show UserAvatar, UserCard;
```

说明：
- 只导出主工程需要直接引用的类型，私有子页和内部 helper 留在各自文件内部。

---

## 任务 3：`client/modules/flash_session/lib/src/data/user.dart` — 定义资料实体 `✅ 已完成`

文件：`client/modules/flash_session/lib/src/data/user.dart`

改动类型：`新建`

### 3.1 新增 `signature` 与 identicon 辅助字段 `✅`

关键代码骨架：

```dart
class User {
  const User({
    required this.userId,
    required this.phone,
    required this.nickname,
    required this.avatar,
    required this.signature,
    required this.hasPassword,
  });

  final int userId;
  final String phone;
  final String nickname;
  final String avatar;
  final String signature;
  final bool hasPassword;

  bool get hasCustomAvatar => avatar.isNotEmpty && !avatar.startsWith('identicon:');
  String get identiconSeed =>
      avatar.startsWith('identicon:') ? avatar.substring('identicon:'.length) : '$userId';
}
```

### 3.2 提供 JSON 映射能力 `✅`

关键代码骨架：

```dart
factory User.fromJson(Map<String, dynamic> json) {
  return User(
    userId: (json['account_id'] as num?)?.toInt() ?? 0,
    phone: json['phone'] as String? ?? '',
    nickname: json['nickname'] as String? ?? '',
    avatar: json['avatar'] as String? ?? '',
    signature: json['signature'] as String? ?? '',
    hasPassword: json['has_password'] as bool? ?? false,
  );
}

Map<String, dynamic> toJson() => <String, dynamic>{
  'account_id': userId,
  'phone': phone,
  'nickname': nickname,
  'avatar': avatar,
  'signature': signature,
  'has_password': hasPassword,
};
```

说明：
- 当前服务端资料接口仍返回 `account_id` / `has_password`，这里按真实接口兼容，不额外引入 DTO 文件。

---

## 任务 4：`client/modules/flash_session/lib/src/data/session_api.dart` + `session_repository.dart` — 落地资料与密码接口 `✅ 已完成`

文件：
- `client/modules/flash_session/lib/src/data/session_api.dart`
- `client/modules/flash_session/lib/src/data/session_repository.dart`

改动类型：
- `新建`
- `新建`

### 4.1 为 `/user/profile`、`/user/password` 定义独立 API `✅`

关键代码骨架：

```dart
abstract interface class SessionApi {
  Future<User> fetchProfile({required String token});
  Future<User> updateProfile({
    required String token,
    String? nickname,
    String? signature,
    String? avatar,
  });
  Future<void> setPassword({
    required String token,
    required String newPassword,
  });
  Future<void> changePassword({
    required String token,
    required String oldPassword,
    required String newPassword,
  });
}
```

```dart
final response = await _dio.put<dynamic>(
  '/user/profile',
  data: <String, String?>{
    'nickname': nickname,
    'signature': signature,
    'avatar': avatar,
  }..removeWhere((_, value) => value == null),
  options: Options(headers: <String, String>{'Authorization': 'Bearer $token'}),
);
```

### 4.2 仓储承接缓存、资料查询、资料更新、设置密码、修改密码 `✅`

关键代码骨架：

```dart
abstract interface class SessionRepository {
  Future<CachedAuthSession?> readCachedSession();
  Future<void> persistSession(AppSession session);
  Future<void> clearSession();
  Future<User> fetchProfile();
  Future<User> updateProfile({
    String? nickname,
    String? signature,
    String? avatar,
  });
  Future<void> setPassword({required String newPassword});
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  });
}
```

```dart
class DefaultSessionRepository implements SessionRepository {
  DefaultSessionRepository({
    required SessionApi api,
    required AuthCacheStore cacheStore,
  }) : _api = api,
       _cacheStore = cacheStore;

  final SessionApi _api;
  final AuthCacheStore _cacheStore;
}
```

说明：
- 这里沿用 `flash_auth` 的 `AuthCacheStore` 做 token 持久化，先完成职责迁移，不在本轮额外重命名缓存层。
- `setPassword` 走 `POST /user/password`，`changePassword` 走 `PUT /user/password`，不要再请求旧 `/auth/password/*` 路径。

---

## 任务 5：`client/modules/flash_session/lib/src/logic/session_state.dart` + `session_cubit.dart` — 建立全局会话状态 `✅ 已完成`

文件：
- `client/modules/flash_session/lib/src/logic/session_state.dart`
- `client/modules/flash_session/lib/src/logic/session_cubit.dart`

改动类型：
- `新建`
- `新建`

### 5.1 定义 session 状态与会话生命周期 `✅`

关键代码骨架：

```dart
enum SessionStatus { initial, restoring, authenticated, unauthenticated, failure }

class SessionState {
  const SessionState({
    required this.status,
    this.session,
    this.user,
    this.errorMessage,
    this.shouldPromptPasswordSetup = false,
  });

  const SessionState.initial() : this(status: SessionStatus.initial);

  final AppSession? session;
  final User? user;
  ...
}
```

### 5.2 迁入 restore / login / profile / password 逻辑 `✅`

关键代码骨架：

```dart
class SessionCubit extends Cubit<SessionState> {
  SessionCubit({required SessionRepository repository})
      : _repository = repository,
        super(const SessionState.initial());

  Future<void> restoreSession() async { ... }
  Future<void> completeLogin(AppSession session) async { ... }
  Future<void> refreshProfile() async { ... }
  Future<void> updateProfile({
    String? nickname,
    String? signature,
    String? avatar,
  }) async { ... }
  Future<void> setPassword({required String newPassword}) async { ... }
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async { ... }
  Future<void> logout() async { ... }
  void markPasswordPromptHandled() { ... }
}
```

说明：
- `completeLogin()` 负责缓存 token，并根据登录结果里的 `passwordSetupRequired` 决定是否弹首次设置密码提示。
- `setPassword()` 成功后要刷新资料或直接把 `user.hasPassword` 置为 `true`，否则 Mine 页面会继续跳到首次设置流程。

---

## 任务 6：`client/modules/flash_auth/lib/src/{data/auth_api.dart,data/auth_repository.dart,presentation/login_page.dart}` + `flash_auth.dart` — 收缩为登录模块 `✅ 已完成`

文件：
- `client/modules/flash_auth/lib/src/data/auth_api.dart`
- `client/modules/flash_auth/lib/src/data/auth_repository.dart`
- `client/modules/flash_auth/lib/src/presentation/login_page.dart`
- `client/modules/flash_auth/lib/flash_auth.dart`

改动类型：`修改`

### 6.1 从 auth API / repository 中移除资料与密码职责 `✅`

关键代码骨架：

```dart
abstract interface class AuthRepository {
  Future<String> sendSmsCode(String phone);
  Future<AppSession> loginWithPassword({
    required String identifier,
    required String password,
  });
  Future<AppSession> loginWithSmsCode({
    required String phone,
    required String code,
  });
}
```

说明：
- `fetchProfile()`、`setPassword()`、`persistSession()`、`readCachedSession()`、`logout()` 从 `AuthRepository` 迁出到 `SessionRepository`。
- `AuthApi` 同步移除 `/user/profile` 和 `/auth/password/set` 封装。

### 6.2 `LoginPage` 通过回调把登录结果交给 `SessionCubit` `✅`

关键代码骨架：

```dart
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.homeRouteName,
    required this.onLoginSuccess,
  });

  final String homeRouteName;
  final Future<void> Function(AppSession session) onLoginSuccess;
}
```

```dart
final session = switch (_method) { ... };
await widget.onLoginSuccess(session);
Navigator.of(context).pushNamedAndRemoveUntil(widget.homeRouteName, (_) => false);
```

说明：
- 这样 `flash_auth` 不再依赖 `SessionCubit` / `SessionStatus`，只负责登录 UI 与登录请求。
- `flash_auth.dart` 也要同步停止导出 `AppSessionCubit`、`AuthProfile`、`AuthStatus` 之类的旧 session 类型。

---

## 任务 7：`client/lib/app/flash_im_app.dart` — 注入 `SessionRepository` / `SessionCubit` `✅ 已完成`

文件：`client/lib/app/flash_im_app.dart`

改动类型：`修改`

### 7.1 主工程同时提供 auth 与 session 仓储 `✅`

关键代码骨架：

```dart
final authRepository = widget.authRepository ?? ...;
final sessionRepository =
    widget.sessionRepository ??
    (_defaultSessionRepository ??= DefaultSessionRepository(
      api: DioSessionApi(dio: DioFactory.create(baseUrl: config.apiBaseUrl)),
      cacheStore: const SharedPreferencesAuthCacheStore(),
    ));
```

### 7.2 全局 Bloc 从 `AppSessionCubit` 切换到 `SessionCubit` `✅`

关键代码骨架：

```dart
return MultiRepositoryProvider(
  providers: [
    RepositoryProvider<AuthRepository>.value(value: authRepository),
    RepositoryProvider<SessionRepository>.value(value: sessionRepository),
  ],
  child: BlocProvider<SessionCubit>.value(
    value: sessionCubit,
    child: MaterialApp(...),
  ),
);
```

说明：
- Widget 构造参数也要从 `AppSessionCubit?` 扩展为 `SessionCubit?` / `SessionRepository?`。
- `dispose()` 里只关闭当前文件新持有的默认 cubit 实例。

---

## 任务 8：`client/lib/app/app_router.dart` — 增加 session 页面路由 `✅ 已完成`

文件：`client/lib/app/app_router.dart`

改动类型：`修改`

### 8.1 注册资料与密码页面路由 `✅`

关键代码骨架：

```dart
abstract final class AppRoutes {
  static const startup = '/startup';
  static const login = '/login';
  static const home = '/home';
  static const editProfile = '/mine/profile/edit';
  static const setPassword = '/mine/password/set';
  static const changePassword = '/mine/password/change';
}
```

### 8.2 登录页注入 `onLoginSuccess`，session 页面从新模块构建 `✅`

关键代码骨架：

```dart
case AppRoutes.login:
  return MaterialPageRoute<void>(
    builder: (context) => LoginPage(
      homeRouteName: AppRoutes.home,
      onLoginSuccess: context.read<SessionCubit>().completeLogin,
    ),
  );
case AppRoutes.editProfile:
  return MaterialPageRoute<void>(builder: (_) => const EditProfilePage());
```

说明：
- 资料编辑页内部私有子页使用 `MaterialPageRoute` 即可，不需要把 `_TextEditPage` / `_AvatarEditPage` 再暴露成全局命名路由。

---

## 任务 9：`client/modules/flash_session/lib/src/view/widget/identicon_avatar.dart` + `user_card.dart` — 实现复用组件 `✅ 已完成`

文件：
- `client/modules/flash_session/lib/src/view/widget/identicon_avatar.dart`
- `client/modules/flash_session/lib/src/view/widget/user_card.dart`

改动类型：
- `新建`
- `新建`

### 9.1 `IdenticonAvatar` 支持 identicon / 占位态 `✅`

关键代码骨架：

```dart
class IdenticonAvatar extends StatelessWidget {
  const IdenticonAvatar({
    super.key,
    required this.seed,
    this.size = 48,
    this.borderRadius,
  });
}

class _IdenticonPainter extends CustomPainter {
  const _IdenticonPainter(this.seed);
}
```

说明：
- 图案规则按设计稿落 5x5 左半镜像、15% 内边距；颜色从 seed 哈希稳定派生。

### 9.2 `UserAvatar` / `UserCard` 输出主工程可复用卡片 `✅`

关键代码骨架：

```dart
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.user,
    this.size = 56,
  });

  final User user;
}

class UserCard extends StatelessWidget {
  const UserCard({
    super.key,
    required this.user,
    this.onTap,
  });
}
```

```dart
Row(
  children: [
    UserAvatar(user: user, size: 64),
    const SizedBox(width: 16),
    Expanded(child: ...nickname / 闪讯号 / signature...),
    const Icon(Icons.chevron_right_rounded),
  ],
)
```

说明：
- `signature` 为空时要展示弱提示文案，而不是留下空白行。

---

## 任务 10：`client/modules/flash_session/lib/src/view/set_password_page.dart` — 首次设置密码页 `✅ 已完成`

文件：`client/modules/flash_session/lib/src/view/set_password_page.dart`

改动类型：`新建`

### 10.1 单输入框 + 校验 + 调 `setPassword` `✅`

关键代码骨架：

```dart
class SetPasswordPage extends StatefulWidget {
  const SetPasswordPage({super.key});
}

Future<void> _submit() async {
  final password = _passwordController.text.trim();
  if (password.length < 6) { ... }
  await context.read<SessionCubit>().setPassword(newPassword: password);
}
```

```dart
Scaffold(
  appBar: AppBar(title: const Text('设置密码')),
  body: Column(
    children: [
      TextField(...),
      FilledButton(onPressed: _submit, child: const Text('完成')),
    ],
  ),
)
```

说明：
- 成功后应返回上一页，并确保 `shouldPromptPasswordSetup` 关闭。

---

## 任务 11：`client/modules/flash_session/lib/src/view/change_password_page.dart` — 修改密码页 `✅ 已完成`

文件：`client/modules/flash_session/lib/src/view/change_password_page.dart`

改动类型：`新建`

### 11.1 双输入框 + 401 错误提示 + 调 `changePassword` `✅`

关键代码骨架：

```dart
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});
}

Future<void> _submit() async {
  await context.read<SessionCubit>().changePassword(
    oldPassword: _oldPasswordController.text.trim(),
    newPassword: _newPasswordController.text.trim(),
  );
}
```

```dart
on DioException catch (error) {
  if (error.response?.statusCode == 401) {
    setState(() => _inlineError = '旧密码错误');
    return;
  }
  setState(() => _inlineError = error.message ?? '修改密码失败，请稍后重试');
}
```

说明：
- 页面样式与 `SetPasswordPage` 保持一致，只增加旧密码输入和 401 特判。

---

## 任务 12：`client/modules/flash_session/lib/src/view/edit_profile_page.dart` — 个人资料编辑页 `✅ 已完成`

文件：`client/modules/flash_session/lib/src/view/edit_profile_page.dart`

改动类型：`新建`

### 12.1 主页面用 `BlocBuilder` 驱动三组资料卡 `✅`

关键代码骨架：

```dart
class EditProfilePage extends StatelessWidget {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionCubit, SessionState>(
      builder: (context, state) {
        final user = state.user;
        ...
      },
    );
  }
}
```

```dart
String _maskPhone(String phone) {
  if (phone.length < 5) return phone;
  return '${phone.substring(0, 3)}****${phone.substring(phone.length - 2)}';
}
```

### 12.2 名字 / 签名 / 头像编辑采用子页完成即提交 `✅`

关键代码骨架：

```dart
Future<void> _editNickname(BuildContext context, User user) async { ... }
Future<void> _editSignature(BuildContext context, User user) async { ... }
Future<void> _editAvatar(BuildContext context, User user) async { ... }
```

```dart
await context.read<SessionCubit>().updateProfile(
  nickname: resultNickname,
);
```

说明：
- `_TextEditPage`、`_AvatarEditPage` 保持文件内私有，避免把仅供本页使用的编辑器继续扩散成公共组件。
- “随机更换头像”只生成新的 `identicon:{seed}`，不接入图片选择器。

---

## 任务 13：`client/lib/features/home/presentation/main_shell_page.dart` + `features/mine/presentation/dialogs/password_setup_prompt_dialog.dart` — 接入新密码流程 `✅ 已完成`

文件：
- `client/lib/features/home/presentation/main_shell_page.dart`
- `client/lib/features/mine/presentation/dialogs/password_setup_prompt_dialog.dart`

改动类型：`修改`

### 13.1 主壳监听 `SessionCubit`，替换旧 `AppSessionCubit` 依赖 `✅`

关键代码骨架：

```dart
return BlocListener<SessionCubit, SessionState>(
  listenWhen: (previous, current) =>
      previous.status != current.status ||
      previous.shouldPromptPasswordSetup != current.shouldPromptPasswordSetup,
  listener: (context, state) async { ... },
  child: Scaffold(...),
);
```

### 13.2 首次密码提示改为跳转 `SetPasswordPage`，不再弹内联输入框 `✅`

关键代码骨架：

```dart
class PasswordSetupPromptDialog extends StatelessWidget {
  const PasswordSetupPromptDialog({
    super.key,
    required this.onSetNow,
    required this.onSkip,
  });
}
```

```dart
FilledButton(
  onPressed: onSetNow,
  child: const Text('立即设置'),
)
```

说明：
- `showDialog()` 结束后，若用户选择“立即设置”，由 `MainShellPage` 负责 `Navigator.pushNamed(AppRoutes.setPassword)`。
- 旧的密码输入、接口调用、错误文案全部迁到 `SetPasswordPage`，避免两套设置密码 UI 并存。

---

## 任务 14：`client/lib/features/mine/presentation/mine_page.dart` + `widgets/mine_info_card.dart` — 改造主工程资料页 `✅ 已完成`

文件：
- `client/lib/features/mine/presentation/mine_page.dart`
- `client/lib/features/mine/presentation/widgets/mine_info_card.dart`

改动类型：`修改`

### 14.1 Mine 页从 `FutureBuilder<AuthProfile>` 切到 `SessionCubit` 状态驱动 `✅`

关键代码骨架：

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    context.read<SessionCubit>().refreshProfile();
  });
}
```

```dart
return BlocConsumer<SessionCubit, SessionState>(
  listener: (context, state) { ...logout / error... },
  builder: (context, state) {
    final user = state.user;
    ...
  },
);
```

### 14.2 顶部替换为 `UserCard`，密码入口按 `hasPassword` 分流 `✅`

关键代码骨架：

```dart
UserCard(
  user: user,
  onTap: () => Navigator.of(context).pushNamed(AppRoutes.editProfile),
)
```

```dart
_MineActionRow(
  label: '密码管理',
  value: user.hasPassword ? '修改密码' : '首次设置',
  onTap: () => Navigator.of(context).pushNamed(
    user.hasPassword ? AppRoutes.changePassword : AppRoutes.setPassword,
  ),
)
```

说明：
- `mine_info_card.dart` 可以保留为资料动作卡的承载组件，但展示内容要从静态字段列表改成可点击行。
- 现有 `mine_profile_header.dart` 会被 `UserCard` 取代；若实现完成后确认无引用，再单独删除，不要在本任务一开始就先删文件。

---

## 任务 15：模块边界清理、测试补齐、编译验证 `✅ 已完成`

文件：
- `client/modules/flash_auth/lib/src/cubit/app_session_cubit.dart`
- `client/modules/flash_auth/lib/src/domain/auth_profile.dart`
- `client/modules/flash_auth/lib/src/domain/auth_status.dart`
- `client/test/features/auth/cubit/app_session_cubit_test.dart`
- `client/test/features/auth/data/auth_repository_test.dart`
- `client/test/features/auth/presentation/login_page_test.dart`
- `client/test/features/main_shell/presentation/main_shell_page_test.dart`
- `client/test/features/mine/presentation/mine_page_test.dart`
- `client/modules/flash_session/test/session_repository_test.dart`
- `client/modules/flash_session/test/session_cubit_test.dart`
- `client/modules/flash_session/test/edit_profile_page_test.dart`

改动类型：
- `修改`
- `新建`

### 15.1 清理旧 session 类型与引用 `✅`

处理原则：

```text
1. 先把主工程和测试全部切到 flash_session
2. 再删除或停止导出 flash_auth 内部的 AppSessionCubit / AuthProfile / AuthStatus
3. 若某些旧文件暂时保留，也要确保 flash_im 主工程不再 import 它们
```

### 15.2 更新或新增关键测试 `✅`

目标覆盖：

```text
- auth_repository_test: 只验证登录请求映射，不再校验 fetchProfile / setPassword
- login_page_test: 断言 onLoginSuccess 被调用
- main_shell_page_test: 首次密码提示改为跳转 SetPasswordPage
- mine_page_test: UserCard 展示、密码入口分流、下拉刷新触发 refreshProfile
- session_repository_test: profile / updateProfile / setPassword / changePassword 路径映射
- session_cubit_test: restoreSession、completeLogin、updateProfile、setPassword、changePassword、logout
- edit_profile_page_test: 名字/签名编辑完成后调用 updateProfile
```

### 15.3 编译验证与测试路径 `✅`

执行顺序：

```bash
cd client && flutter pub get
cd client/modules/flash_session && flutter test
cd client/modules/app_starter && flutter test
cd client && flutter test test/widget_test.dart test/features/auth/cubit/app_session_cubit_test.dart test/features/auth/data/auth_repository_test.dart test/features/auth/presentation/login_page_test.dart test/features/main_shell/presentation/main_shell_page_test.dart test/features/startup/presentation/startup_page_test.dart test/features/mine/presentation/mine_page_test.dart
cd client && flutter analyze lib test
```

说明：
- 上述命令已在本次执行中完成，`flash_session` 包测试、`app_starter` 包测试、客户端关键测试集和 `flutter analyze lib test` 均已通过。
- 旧的 `AppSessionCubit` / `AuthProfile` / `AuthStatus` 以及 `mine_profile_header.dart` 已从主流程中移除，任务状态已同步更新。
