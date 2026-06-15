# 客户端登录认证逻辑分析

## 1. 目标与范围

本文基于当前 `client` 产品入口的真实代码，梳理客户端登录认证模块的实际工作方式，覆盖以下范围：

- 应用启动时如何恢复登录态
- 短信验证码登录和密码登录如何发起
- Token 如何持久化
- 登录后如何进入主壳层
- 未设置密码时如何触发补充密码提示
- 个人资料页如何刷新认证资料
- 退出登录如何清理本地状态
- 当前结构中的明显问题与后续优化方向

本文不分析 `playground` 下的演示认证逻辑，只分析正式产品入口 `client/lib/main.dart -> FlashImApp` 实际生效的链路。

## 2. 当前生效入口

当前产品应用的认证主链路从这里开始：

- 应用根：`client/lib/app/flash_im_app.dart`
- 路由表：`client/lib/app/app_router.dart`
- 启动页：`client/lib/features/startup/presentation/startup_page.dart`
- 会话状态中心：`client/lib/features/auth/cubit/app_session_cubit.dart`
- 登录页：`client/lib/features/auth/presentation/login_page.dart`
- 主壳层：`client/lib/features/main_shell/presentation/main_shell_page.dart`
- 我的页面：`client/lib/features/mine/presentation/mine_page.dart`

应用启动后固定走 `/startup`，再由 `StartupPage` 根据 `AppSessionCubit` 的恢复结果决定跳到 `/login` 或 `/home`。

## 3. 模块分层

### 3.1 UI 层

- `StartupPage`
  - 负责展示启动页
  - 调用 `restoreSession()`
  - 监听认证状态并跳转登录页或主页
- `LoginPage`
  - 负责手机号、验证码、密码输入
  - 负责发送验证码和提交登录
  - 登录成功后把结果交给 `AppSessionCubit`
- `MainShellPage`
  - 承载 `消息 / 通讯录 / 我的`
  - 监听 `shouldPromptPasswordSetup`
  - 监听未登录状态并回退到登录页
- `MinePage`
  - 拉取 `/user/profile`
  - 把资料同步回全局会话状态
  - 支持退出登录
- `PasswordSetupPromptDialog`
  - 在未设置密码时弹出
  - 调用设置密码接口

### 3.2 状态层

- `AppSessionCubit`
  - 全局唯一认证状态中心
  - 负责恢复登录态、完成登录、退出登录、刷新资料、管理“是否需要提示设置密码”

当前实现采用“全局 1 个会话 Cubit + 页面内局部状态”的模式：

- 全局共享状态：`AppSessionCubit`
- 页面局部状态：输入框、验证码倒计时、提交 loading、错误文案

### 3.3 数据层

- `AuthRepository`
  - 认证业务抽象
- `DefaultAuthRepository`
  - 负责组装 API 与本地缓存
- `AuthApi`
  - 认证接口抽象
- `DioAuthApi`
  - 基于 Dio 的 HTTP 实现
- `AuthCacheStore`
  - 本地认证缓存抽象
- `SharedPreferencesAuthCacheStore`
  - 当前 token 持久化实现

## 4. 启动恢复链路

### 4.1 初始化依赖

`FlashImApp` 会先加载本地配置，然后构造默认依赖：

- `DefaultLocalConfigStore`
- `DioAuthApi`
- `DefaultAuthRepository`
- `AppSessionCubit`

当前默认后端地址来自：

- `client/lib/core/config/local_config_store.dart`

默认值是：

```text
http://127.0.0.1:9600
```

### 4.2 启动页触发恢复

`StartupPage` 在 `initState()` 中通过 `addPostFrameCallback` 调用：

```dart
context.read<AppSessionCubit>().restoreSession();
```

之后根据 `AppSessionCubit` 状态变化处理跳转：

- `restoring`：展示“正在恢复登录状态...”
- `authenticated`：立即进入 `/home`
- `unauthenticated`：等待 3 秒后进入 `/login`
- `failure`：停留在启动页并展示重试按钮

### 4.3 restoreSession 的真实逻辑

`restoreSession()` 当前只做本地缓存读取：

1. 读取 `AuthCacheStore.read()`
2. 如果没有 token，发出 `unauthenticated`
3. 如果有 token，直接发出 `authenticated`
4. 如果读取缓存报错，清空缓存并发出 `failure`

需要注意：

- 这里不会主动请求后端验证 token 是否有效
- 这里也不会主动加载用户资料
- 这里会把 `passwordSetupRequired` 固定设为 `false`

所以当前恢复逻辑的本质是：

> “本地只要还有 token 字符串，就先认定用户已登录。”

## 5. 登录链路

### 5.1 支持的两种登录方式

`LoginPage` 当前支持两种模式：

- `LoginMethod.smsCode`
- `LoginMethod.password`

切换只影响页面局部 UI，不影响全局状态结构。

### 5.2 发送验证码

验证码发送走：

- `LoginPage._sendCode()`
- `AuthRepository.sendSmsCode()`
- `DioAuthApi.sendSmsCode()`
- `POST /auth/sms`

请求体：

```json
{
  "phone": "13800138000"
}
```

成功后：

- 启动 60 秒倒计时
- Debug 模式下会把返回的验证码自动填回输入框

这个自动回填逻辑只在 `kDebugMode` 下生效。

### 5.3 提交登录

登录提交流程：

1. `LoginPage._submit()` 检查输入是否为空
2. 根据当前模式调用仓库
3. 登录成功后执行 `AppSessionCubit.completeLogin(session)`

短信登录调用：

- `AuthRepository.loginWithSmsCode()`
- `POST /auth/login`

请求体：

```json
{
  "login_type": "sms_code",
  "phone": "13800138000",
  "code": "123456"
}
```

密码登录调用：

- `AuthRepository.loginWithPassword()`
- `POST /auth/login`

请求体：

```json
{
  "login_type": "password",
  "identifier": "13800138000",
  "password": "your-password"
}
```

### 5.4 登录成功后的会话写入

`completeLogin()` 会做两件事：

1. `persistSession(session)` 把 token 写入本地
2. 发出 `authenticated` 状态

同时：

- `shouldPromptPasswordSetup = session.passwordSetupRequired`
- `_passwordPromptDismissed = false`

这意味着：

- 如果后端在本次登录响应中声明“尚未设置密码”，主壳层会收到一个全局提示标记

## 6. Token 持久化逻辑

### 6.1 当前存储位置

当前 token 存在 `SharedPreferences`：

- key: `flash_im.auth.token`
- key: `flash_im.auth.account_id`

由 `SharedPreferencesAuthCacheStore` 负责读写。

### 6.2 当前持久化内容

当前缓存只保存：

- `token`
- `accountId`

不会缓存：

- `hasPassword`
- `nickname`
- `avatar`
- `phone`
- token 过期时间

所以应用重启后只能恢复“有无 token”，不能恢复完整的用户资料视图。

## 7. 主壳层与登录后行为

### 7.1 登录成功后的跳转

`LoginPage` 监听 `AppSessionCubit`：

- 当状态从非 `authenticated` 变成 `authenticated` 时
- 直接跳转 `/home`

### 7.2 主壳层结构

`MainShellPage` 当前有 3 个 Tab：

- 消息
- 通讯录
- 我的

前两个还是占位页，认证相关逻辑主要落在：

- 主壳层的全局监听
- 我的页面的 profile 拉取

### 7.3 未设置密码弹窗

`MainShellPage` 会监听：

- `status`
- `shouldPromptPasswordSetup`

当 `shouldPromptPasswordSetup == true` 时，会弹出：

- `PasswordSetupPromptDialog`

对话框支持两个动作：

- `立即设置`
- `稍后设置`

#### 立即设置

流程如下：

1. `AuthRepository.setPassword(newPassword: ...)`
2. `POST /auth/password/set`
3. 请求头里手工附带 `Authorization: Bearer <token>`
4. 成功后执行 `markPasswordPromptHandled()`
5. 再执行 `refreshProfile()`
6. 弹窗关闭

#### 稍后设置

流程如下：

1. `markPasswordPromptHandled()`
2. 关闭弹窗

这意味着当前实现中：

- 用户本次手动关闭弹窗后，本轮会话内不会再次提示
- 重新登录或重新恢复会话后，提示标志可能重新出现，取决于后续资料同步结果

## 8. “我的”页与资料同步

### 8.1 资料加载时机

`MinePage` 在 `initState()` 中立即调用 `_loadProfile()`。

资料接口链路：

- `AuthRepository.fetchProfile()`
- `DioAuthApi.fetchProfile()`
- `GET /user/profile`

请求头：

```text
Authorization: Bearer <token>
```

### 8.2 资料加载后的处理

当 `MinePage` 成功拿到 `AuthProfile` 后，会执行：

```dart
_sessionCubit.syncProfile(profile);
```

这会把以下信息同步回全局状态：

- `profile`
- `shouldPromptPasswordSetup = !profile.hasPassword`

前提是当前会话还没有把密码提示标记为“已处理”。

### 8.3 鉴权失效时的处理

`MinePage` 在以下两种情况下会触发退出登录：

- 本地拿不到 token，抛出 `AuthMissingTokenException`
- 服务端返回 `401`

触发 `logout()` 后：

- 清空缓存
- 发出 `unauthenticated`
- 页面监听到后跳回 `/login`

## 9. 退出登录链路

退出登录入口目前在“我的”页。

链路如下：

1. `MinePage._logout()`
2. `AppSessionCubit.logout()`
3. `AuthRepository.logout()`
4. `AuthCacheStore.clear()`
5. Cubit 发出 `unauthenticated`
6. `MinePage` 或 `MainShellPage` 监听后跳回 `/login`

退出登录不会调用服务端注销接口，当前是纯客户端本地清理。

## 10. 当前数据流总结

可以把当前认证数据流概括为下面 3 条主线。

### 10.1 启动恢复主线

`FlashImApp`
-> `StartupPage`
-> `AppSessionCubit.restoreSession()`
-> `AuthRepository.readCachedSession()`
-> `SharedPreferencesAuthCacheStore.read()`
-> 发出 `authenticated / unauthenticated / failure`
-> `StartupPage` 导航

### 10.2 登录主线

`LoginPage`
-> `AuthRepository.loginWithSmsCode()` 或 `loginWithPassword()`
-> `DioAuthApi`
-> `/auth/login`
-> 返回 `AppSession`
-> `AppSessionCubit.completeLogin()`
-> `persistSession()`
-> 跳转 `/home`

### 10.3 资料同步与密码补充主线

`MinePage`
-> `AuthRepository.fetchProfile()`
-> `/user/profile`
-> `AppSessionCubit.syncProfile(profile)`
-> `MainShellPage` 根据 `shouldPromptPasswordSetup` 弹窗
-> `PasswordSetupPromptDialog`
-> `/auth/password/set`

## 11. 当前实现的结构特点

### 11.1 优点

- 结构比较清晰，职责分层基本成立
- 会话共享只集中在 `AppSessionCubit`
- 登录页局部状态没有过度抽象
- API、Repository、CacheStore 都有独立抽象，后续可替换性还不错
- 登录后是否提示补密码，已经有一条完整的闭环链路

### 11.2 当前明显限制

#### 1. 启动恢复只认本地 token，不校验服务端有效性

这会导致：

- 过期 token 仍然可能直接进入主页
- 需要等后续某个真实接口返回 `401` 才会退回登录页

#### 2. 密码是否已设置，冷启动时不能立即得知

因为 `restoreSession()` 不会主动拉 profile，所以：

- 冷启动进入主页后，只有进入“我的”页才会同步 `hasPassword`
- “登录后检测是否有密码”的时机并不完整

#### 3. Token 存储安全等级较低

当前用的是 `SharedPreferences`，更适合 demo 或低安全场景，不适合作为正式产品的长期方案。

#### 4. 鉴权头注入是手工分散式实现

当前 `fetchProfile()` 和 `setPassword()` 都是每次手动拼 `Authorization`，后续接口变多后容易遗漏。

#### 5. 启动模块存在旧抽象残留

仓库中仍然保留了：

- `StartupCoordinator`
- `AppBootstrapSnapshot`
- `LaunchDestination`

这些类还在，但当前正式产品链路已经不再使用它们，而是直接由 `StartupPage + AppSessionCubit` 接管启动流转。也就是说，启动模块现在存在一套“旧抽象残留但未接线”的状态。

## 12. 建议的后续优化方向

### 12.1 把恢复登录态升级为“恢复 + 校验 + 拉资料”

更合理的链路应当是：

1. 读取本地 token
2. 如果没有 token，直接未登录
3. 如果有 token，请求 `/user/profile`
4. 成功则同时恢复会话和 profile
5. `401` 则清缓存并回登录页

这样可以一次解决：

- 假登录态
- 冷启动缺少 profile
- 密码提示触发不完整

### 12.2 把 token 存储迁移到更安全的实现

建议保留 `AuthCacheStore` 抽象，只替换默认实现，例如：

- iOS：Keychain
- Android：EncryptedSharedPreferences / Keystore

### 12.3 统一鉴权注入与 401 处理

可以考虑把以下能力放进 Dio 拦截器：

- 自动注入 token
- 统一识别 `401`
- 统一触发会话失效回收

这样页面层可以少写很多重复逻辑。

### 12.4 清理未使用的旧启动抽象

如果后续确认不再走 `StartupCoordinator` 方案，建议删掉未接线的旧启动模型，避免文档、代码和真实链路三套口径并存。

## 13. 结论

当前客户端认证逻辑已经具备一个可运行的最小闭环：

- 支持短信验证码登录
- 支持密码登录
- 支持 token 本地持久化
- 支持冷启动恢复登录态
- 支持登录后提醒补设置密码
- 支持资料加载和退出登录

但它当前更接近“可用版本”，还不是“强健版本”。

最核心的结构问题在于：

- 启动恢复只依赖本地 token，而不是服务端确认
- profile 与密码状态同步时机偏后
- token 存储与鉴权注入还比较基础

如果后续要进入更稳定的产品阶段，最值得优先收敛的是：

1. 启动阶段直接校验 token 并加载 profile
2. 提升 token 持久化安全性
3. 统一网络层鉴权注入和失效回收
