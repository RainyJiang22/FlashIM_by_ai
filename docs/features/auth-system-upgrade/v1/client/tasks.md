# auth-system-upgrade — client 任务清单

基于 design.md 设计，列出需要创建/修改的具体细节。
全局约束：
- 客户端范围限定在 `client/lib/playground/demos/auth/` 和对应测试，不扩散到其他 playground 模块。
- 登录成功后的分流必须由 `password_setup_required` 驱动，不自行猜测账户状态。
- token 持久化继续使用现有 `SharedPreferencesAuthSessionStore`，本期不引入 refresh token。
- 密码登录输入统一切为 `identifier + password`，当前文案默认面向手机号，但不要把协议重新写死为手机号专用字段。
- 参考文档：`docs/features/auth-system-upgrade/v1/client/design.md`，并保留现有 `AuthPlaygroundPage` / `AuthProfilePage` 的导航风格。

---

## 执行顺序

1. ⬜ 任务 1 — `domain` 模型升级（无依赖）
   - ⬜ 1.1 更新 `AuthSession`
   - ⬜ 1.2 更新 `AuthProfile`
   - ⬜ 1.3 新增登录后跳转意图
2. ⬜ 任务 2 — `data/models` DTO 升级（依赖任务 1）
   - ⬜ 2.1 登录响应改到 `account_id`
   - ⬜ 2.2 资料响应补 `has_password`
   - ⬜ 2.3 新增设置密码 / 修改密码 DTO
3. ⬜ 任务 3 — `auth_api.dart` 扩展接口协议（依赖任务 2）
   - ⬜ 3.1 密码登录切到 `identifier`
   - ⬜ 3.2 新增 set/change password 请求
4. ⬜ 任务 4 — `auth_repository.dart` 重写登录后分流结果（依赖任务 1、任务 2、任务 3）
   - ⬜ 4.1 统一映射 `accountId`
   - ⬜ 4.2 新增设置密码与修改密码仓储方法
5. ⬜ 任务 5 — `auth_playground_page.dart` 登录表单与分流改造（依赖任务 4）
   - ⬜ 5.1 账号密码模式改成 identifier + password
   - ⬜ 5.2 登录后按 `passwordSetupRequired` 分流
6. ⬜ 任务 6 — `auth_set_password_page.dart` 新增首次设置密码页（依赖任务 4、任务 5）
   - ⬜ 6.1 双密码输入与校验
   - ⬜ 6.2 成功后进入资料页
7. ⬜ 任务 7 — `auth_profile_page.dart` 与 `auth_change_password_sheet.dart` 增加密码状态入口（依赖任务 4、任务 6）
   - ⬜ 7.1 资料页展示 `hasPassword`
   - ⬜ 7.2 已设密码走修改密码弹层，未设密码走设置密码页
8. ⬜ 任务 8 — `auth_api_test.dart`、`auth_repository_test.dart`、`auth_playground_page_test.dart` 测试对齐新协议（依赖任务 3、任务 4、任务 5、任务 6、任务 7）
   - ⬜ 8.1 API 层断言 `account_id` 与 `identifier`
   - ⬜ 8.2 Repository 层断言 `passwordSetupRequired`
   - ⬜ 8.3 页面层断言登录后分流
9. ⬜ 最后 — 编译验证 + 测试路径（依赖任务 1-8）
   - ⬜ 9.1 `flutter analyze`
   - ⬜ 9.2 `flutter test test/playground/auth/...`
   - ⬜ 9.3 手工走一遍“短信登录→设置密码→资料页→修改密码”

---

## 任务 1：domain 模型升级 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/playground/demos/auth/domain/auth_session.dart`

改动类型：`修改`

### 1.1 登录态切到 `accountId` + `passwordSetupRequired` `⬜`

关键代码片段：

```dart
class AuthSession {
  const AuthSession({
    required this.token,
    required this.accountId,
    required this.passwordSetupRequired,
  });

  final String token;
  final int accountId;
  final bool passwordSetupRequired;
}
```

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/playground/demos/auth/domain/auth_profile.dart`

改动类型：`修改`

### 1.2 资料模型补 `hasPassword` 并切到 `accountId` `⬜`

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
}
```

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/playground/demos/auth/domain/auth_login_next_step.dart`

改动类型：`新建`

### 1.3 新增登录后的跳转意图枚举 `⬜`

关键代码片段：

```dart
enum AuthLoginNextStep {
  openProfile,
  setupPassword,
}
```

## 任务 2：data/models DTO 升级 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/playground/demos/auth/data/models/auth_session_dto.dart`

改动类型：`修改`

### 2.1 登录响应切到 `account_id` `⬜`

关键代码片段：

```dart
class AuthSessionDto {
  const AuthSessionDto({
    required this.token,
    required this.accountId,
    required this.passwordSetupRequired,
  });

  factory AuthSessionDto.fromJson(Map<String, dynamic> json) {
    return AuthSessionDto(
      token: json['token'] as String? ?? '',
      accountId: (json['account_id'] as num?)?.toInt() ?? 0,
      passwordSetupRequired: json['password_setup_required'] as bool? ?? false,
    );
  }
}
```

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/playground/demos/auth/data/models/auth_profile_dto.dart`

改动类型：`修改`

### 2.2 资料响应补 `has_password` `⬜`

关键代码片段：

```dart
class AuthProfileDto {
  const AuthProfileDto({
    required this.accountId,
    required this.nickname,
    required this.avatar,
    required this.phone,
    required this.hasPassword,
  });
}
```

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/playground/demos/auth/data/models/set_password_result_dto.dart`

改动类型：`新建`

### 2.3 新增设置密码结果 DTO `⬜`

关键代码片段：

```dart
class SetPasswordResultDto {
  const SetPasswordResultDto({
    required this.passwordSetupRequired,
    required this.updatedAt,
  });
}
```

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/playground/demos/auth/data/models/change_password_result_dto.dart`

改动类型：`新建`![ChatGPT Image 2026年6月12日 15_21_09.png](../../../../../../../Downloads/ChatGPT%20Image%202026%E5%B9%B46%E6%9C%8812%E6%97%A5%2015_21_09.png)

### 2.4 新增修改密码结果 DTO `⬜`

关键代码片段：

```dart
class ChangePasswordResultDto {
  const ChangePasswordResultDto({
    required this.updatedAt,
  });
}
```

## 任务 3：auth_api.dart — 扩展新接口协议 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/playground/demos/auth/data/auth_api.dart`

改动类型：`修改`

### 3.1 密码登录改用 `identifier` 入参 `⬜`

关键代码片段：

```dart
Future<AuthSessionDto> loginWithPassword({
  required String identifier,
  required String password,
});
```

请求骨架：

```dart
data: <String, String>{
  'login_type': 'password',
  'identifier': identifier,
  'password': password,
}
```

### 3.2 新增设置密码与修改密码请求 `⬜`

关键代码片段：

```dart
Future<SetPasswordResultDto> setPassword({
  required String token,
  required String newPassword,
});

Future<ChangePasswordResultDto> changePassword({
  required String token,
  required String oldPassword,
  required String newPassword,
});
```

## 任务 4：auth_repository.dart — 仓储层统一分流语义 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/playground/demos/auth/data/auth_repository.dart`

改动类型：`修改`

### 4.1 更新接口定义与 DTO 映射 `⬜`

关键代码片段：

```dart
abstract interface class AuthRepository {
  Future<AuthSession> loginWithPassword({
    required String identifier,
    required String password,
  });

  Future<void> setPassword({required String newPassword});
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  });
}
```

### 4.2 保存 token 并保留分流信息 `⬜`

关键代码片段：

```dart
AuthSession _mapSession(AuthSessionDto dto) {
  return AuthSession(
    token: dto.token,
    accountId: dto.accountId,
    passwordSetupRequired: dto.passwordSetupRequired,
  );
}
```

### 4.3 调用设置密码与修改密码接口 `⬜`

逻辑步骤：
1. 从 `AuthSessionStore` 读取 token。
2. token 缺失时抛 `AuthMissingTokenException`。
3. 调 API。
4. 成功后必要时刷新资料。

## 任务 5：auth_playground_page.dart — 登录页改造与分流 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/playground/demos/auth/presentation/auth_playground_page.dart`

改动类型：`修改`

### 5.1 将密码登录 UI 改成 `identifier + password` `⬜`

保留现有双模式切换，不再使用示例账号语义。

关键 Widget 骨架：

```dart
TextField(
  controller: _identifierController,
  decoration: const InputDecoration(
    labelText: '手机号 / 邮箱',
  ),
)
```

### 5.2 登录成功后根据 `passwordSetupRequired` 分流 `⬜`

关键代码片段：

```dart
final session = switch (_loginType) {
  AuthLoginType.smsCode => await _repository.loginWithSmsCode(...),
  AuthLoginType.password => await _repository.loginWithPassword(...),
};

if (session.passwordSetupRequired) {
  _openSetPassword();
} else {
  _openProfile();
}
```

## 任务 6：auth_set_password_page.dart — 新增首次设置密码页 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/playground/demos/auth/presentation/auth_set_password_page.dart`

改动类型：`新建`

### 6.1 搭建双密码输入与基本校验 `⬜`

关键 Widget 骨架：

```dart
Column(
  children: [
    TextField(controller: _passwordController, obscureText: true),
    TextField(controller: _confirmPasswordController, obscureText: true),
    FilledButton(onPressed: _submit, child: const Text('设置密码')),
  ],
)
```

### 6.2 成功后进入资料页 `⬜`

关键代码片段：

```dart
await _repository.setPassword(newPassword: password);
Navigator.of(context).pushReplacement(
  MaterialPageRoute<void>(
    builder: (_) => AuthProfilePage(repository: _repository),
  ),
);
```

## 任务 7：资料页与修改密码入口 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/playground/demos/auth/presentation/auth_profile_page.dart`

改动类型：`修改`

### 7.1 展示密码状态并决定入口文案 `⬜`

关键代码片段：

```dart
_ProfileSummaryRow(
  icon: Icons.lock_outline_rounded,
  label: '密码状态',
  value: profile.hasPassword ? '已设置' : '未设置',
)
```

### 7.2 资料页增加入口按钮 `⬜`

逻辑：
1. `hasPassword == false` 时进入 `AuthSetPasswordPage`
2. `hasPassword == true` 时打开修改密码弹层

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/playground/demos/auth/presentation/auth_change_password_sheet.dart`

改动类型：`新建`

### 7.3 新增修改密码交互弹层 `⬜`

关键 Widget 骨架：

```dart
showModalBottomSheet<void>(
  context: context,
  builder: (_) => _AuthChangePasswordSheet(
    onSubmit: (oldPassword, newPassword) async { ... },
  ),
);
```

## 任务 8：认证测试对齐新协议 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/test/playground/auth/data/auth_api_test.dart`

改动类型：`修改`

### 8.1 更新 API 测试断言 `⬜`

至少覆盖：

```dart
expect(session.accountId, 7);
expect(session.passwordSetupRequired, true);
expect(lastLoginPayload, <String, dynamic>{
  'login_type': 'password',
  'identifier': '13800138000',
  'password': 'rainy123',
});
```

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/test/playground/auth/data/auth_repository_test.dart`

改动类型：`修改`

### 8.2 更新 Repository 测试到分流模型 `⬜`

关键断言：

```dart
expect(session.passwordSetupRequired, isTrue);
expect(session.accountId, 1001);
```

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/test/playground/auth/presentation/auth_playground_page_test.dart`

改动类型：`修改`

### 8.3 页面测试验证登录分流 `⬜`

至少补两种情况：
1. `passwordSetupRequired == true` 时跳设置密码页
2. `passwordSetupRequired == false` 时跳资料页

关键测试骨架：

```dart
testWidgets('sms login opens set password page when password is missing', (tester) async { ... });
testWidgets('password login opens profile page when password already exists', (tester) async { ... });
```

## 任务 9：编译验证 + 测试路径 `⬜ 待处理`

文件：`无单一文件，执行验证`

改动类型：`配置/验证`

### 9.1 Flutter 静态检查与测试 `⬜`

执行：

```bash
flutter analyze
flutter test test/playground/auth/data/auth_api_test.dart
flutter test test/playground/auth/data/auth_repository_test.dart
flutter test test/playground/auth/presentation/auth_playground_page_test.dart
```

### 9.2 手工验证路径 `⬜`

至少走通：

```text
短信登录 -> 返回 password_setup_required=true -> 设置密码 -> 进入资料页
资料页 has_password=true -> 修改密码 -> 成功提示
identifier + password 登录 -> 直接进入资料页
```
