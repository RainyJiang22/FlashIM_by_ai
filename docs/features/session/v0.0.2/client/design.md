---
module: session
version: v0.0.2
side: client
date: 2026-03-26
tags: [会话, 用户编辑, 签名, 密码修改, flash_session, 模块化]
---

# session v0.0.2 — 客户端设计报告

> 关联设计：[session v0.0.1 客户端](../../v0.0.1/client/design.md) | [session v0.0.2 服务端](../server/design.md)

## 1. 目标

- User 模型新增 `signature` 字段，支持个性签名
- 用户信息编辑：昵称、签名点击即编辑即保存，头像跳转独立页面随机更换
- 密码管理拆分：首次设置（SetPasswordPage）与修改密码（ChangePasswordPage）分离
- 默认头像：识别 `identicon:{seed}` 标记，CustomPainter 本地渲染 5×5 对称方块图案
- flash_session 模块重构为 `data/` + `logic/` + `view/` 三层架构，与 flash_auth 保持一致
- 用户卡片（UserCard）、用户头像（UserAvatar）封装为模块级可复用组件

## 2. 现状分析（v0.0.1 已完成）

| 能力 | 说明 |
|------|------|
| SessionCubit | 全局会话管理，持有 token + user + hasPassword |
| SessionRepository | fetchProfile、setPassword、本地缓存读写 |
| User 模型 | userId, phone, nickname, avatar（无 signature） |
| ProfilePage | 展示用户信息，只读，无编辑能力 |
| SetPasswordPage | 设置和修改共用同一逻辑，无旧密码验证 |
| 模块结构 | 文件散落在 src/ 根目录，无分层 |

## 3. 数据层（data/）

### User 模型

```dart
class User {
  final int userId;
  final String phone;
  final String nickname;
  final String avatar;
  final String signature;  // 新增，默认空字符串

  bool get hasCustomAvatar => !avatar.startsWith('identicon:');
  String get identiconSeed => avatar.substring('identicon:'.length);
}
```

### SessionRepository 新增接口

| 方法 | 路径 | 说明 |
|------|------|------|
| `setPassword` | POST `/user/password` | 路径从 `/auth/password` 迁移 |
| `updateProfile` | PUT `/user/profile` | 字段可选，只传需要修改的 |
| `changePassword` | PUT `/user/password` | 需旧密码 + 新密码 |

## 4. 逻辑层（logic/）

### SessionCubit 新增方法

| 方法 | 行为 |
|------|------|
| `updateProfile({nickname?, signature?, avatar?})` | 调接口 → 服务端返回完整 User → 更新状态 + 缓存 |
| `changePassword({oldPassword, newPassword})` | 调接口，无需更新状态（hasPassword 已为 true） |

## 5. 视图层（view/）

### 5.1 ProfilePage（主工程）

微信风格"我"页面，位于 `client/lib/src/home/profile/`，因为未来会聚合多个模块内容。

- 顶部白色用户卡片：使用模块导出的 `UserCard` 组件
- 点击卡片 → 跳转 EditProfilePage
- 密码行根据 hasPassword 跳转 SetPasswordPage 或 ChangePasswordPage
- 状态栏颜色与卡片背景一致（白色）

### 5.2 EditProfilePage（模块内）

微信风格"个人资料"列表页，`StatelessWidget`，数据由 `BlocBuilder` 驱动。

- 三组白色卡片：头像+名字 | 手机号+闪讯号 | 签名
- 标签固定 72 宽度，`fontWeight: w600`，内容右对齐
- 手机号脱敏显示（前3后2，中间为 *）
- **即时保存**：名字、签名点击跳转子编辑页，点"完成"直接调 `updateProfile` 接口
- 头像点击跳转独立的头像编辑页，预览大图 + 随机更换 + 点"完成"保存

### 5.3 SetPasswordPage（模块内）

仅用于首次设置密码，单一输入框，调用 `setPassword`。

### 5.4 ChangePasswordPage（模块内）

修改密码，旧密码 + 新密码两个输入框，调用 `changePassword`。区分 401（旧密码错误）提示。

### 5.5 组件（view/widget/）

| 组件 | 说明 |
|------|------|
| `IdenticonAvatar` | 基于 seed 的 5×5 对称方块图案，CustomPainter 实现，15% 内边距 |
| `UserAvatar` | 根据 User 状态自动选择 identicon / 网络图片 / 灰色占位 |
| `UserCard` | 微信风格用户卡片（头像 + 昵称 + 闪讯号 + 签名 + 箭头） |

## 6. 模块结构

```
flash_session/lib/
├── flash_session.dart              # barrel file
└── src/
    ├── data/                       # 数据层
    │   ├── session_repository.dart
    │   └── user.dart
    ├── logic/                      # 逻辑层
    │   ├── session_cubit.dart
    │   └── session_state.dart
    └── view/                       # 视图层
        ├── edit_profile_page.dart
        ├── set_password_page.dart
        ├── change_password_page.dart
        └── widget/
            ├── identicon_avatar.dart
            └── user_card.dart
```

### barrel file 导出

```dart
// data
export 'src/data/session_repository.dart' show SessionRepository;
export 'src/data/user.dart' show User;
// logic
export 'src/logic/session_cubit.dart' show SessionCubit;
export 'src/logic/session_state.dart' show SessionState, SessionStatus;
// view
export 'src/view/edit_profile_page.dart' show EditProfilePage;
export 'src/view/set_password_page.dart' show SetPasswordPage;
export 'src/view/change_password_page.dart' show ChangePasswordPage;
export 'src/view/widget/identicon_avatar.dart' show IdenticonAvatar;
export 'src/view/widget/user_card.dart' show UserCard, UserAvatar;
```

## 7. 技术决策

| 决策 | 方案 | 理由 |
|------|------|------|
| 三层架构 | data/ + logic/ + view/ | 与 flash_auth 保持一致，职责清晰 |
| 即时保存 | 子编辑页点完成直接调接口 | 减少操作步骤，体验更流畅 |
| ProfilePage 留主工程 | 不放入 flash_session 模块 | 未来会聚合多模块内容（设置、收藏等） |
| UserCard 放模块内 | 作为可复用组件导出 | 其他页面也可能展示用户卡片 |
| identicon 本地渲染 | CustomPainter + DJB2 哈希 | 不依赖第三方服务，离线可用 |

## 8. 暂不实现

| 功能 | 理由 |
|------|------|
| 头像上传 | 推迟到 storage 模块接入后 |
| 手机号换绑 | 属于 flash_auth 职责 |
| 邮箱绑定 | 等 auth v0.0.2 服务端实现后 |
