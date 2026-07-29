# 好友关系 v0.0.1 — 客户端任务清单

基于 [design.md](design.md) 设计，新增 `flash_im_friend` 包并替换宿主通讯录占位页。

全局约束：

- 使用 Cubit，不引入 Event 模式；WS 增量与 HTTP 全量数据统一收口到 `FriendCubit`。
- 视觉参考微信截图的信息层级，沿用 Flash IM 现有主题和 `AvatarWidget`。
- 不实现或绘制手机通讯录、扫一扫、雷达、面对面建群、群聊、标签、公众号、服务号、企业联系人、个人二维码等空壳入口。
- 宿主负责认证 Dio、依赖注入和聊天导航；`flash_im_friend` 不依赖 `client/lib`。
- 只执行 Flutter/Dart 定向分析与测试，不执行 Gradle/Android 或 Xcode/iOS 构建。

---

## 执行顺序

1. ✅ 任务 1 — 生成好友 Protobuf Dart 类型（无依赖）
2. ✅ 任务 2 — 扩展 `WsClient` 好友事件流（依赖任务 1）
3. ✅ 任务 3 — 创建好友包配置与公共导出（依赖任务 2）
4. ✅ 任务 4 — 创建好友数据模型（依赖任务 3）
5. ✅ 任务 5 — 实现好友 HTTP Repository（依赖任务 4）
6. ✅ 任务 6 — 实现好友 Cubit 与状态（依赖任务 2、4、5）
7. ✅ 任务 7 — 实现好友客户端页面（依赖任务 6）
8. ✅ 任务 8 — 接入宿主依赖注入、通讯录 Tab、红点和聊天导航（依赖任务 7）
9. ✅ 任务 9 — 增加模型、Repository、Cubit 与页面测试（依赖任务 8）
10. ✅ 最后 — 格式化、定向分析与测试（依赖任务 1-9）

---

## 任务 1：好友 Protobuf Dart 类型 `✅ 已完成`

文件：

- `scripts/proto/gen.ps1`
- `client/modules/flash_im_core/lib/src/data/proto/friend.pb.dart`
- `client/modules/flash_im_core/lib/src/data/proto/friend.pbenum.dart`
- `client/modules/flash_im_core/lib/src/data/proto/friend.pbjson.dart`

改动类型：`修改脚本 + 生成文件`

### 1.1 将 `proto/friend.proto` 加入 `$ProtoFiles` `✅`

```powershell
$ProtoFiles = @(
  "proto/ws.proto",
  "proto/message.proto",
  "proto/friend.proto"
)
```

### 1.2 使用 protoc 生成好友事件 Dart 类型 `✅`

生成 `FriendUser`、`FriendRequestEvent`、`FriendAcceptedEvent`、`FriendRemovedEvent`。

## 任务 2：`WsClient` — 好友事件强类型分发 `✅ 已完成`

文件：

- `client/modules/flash_im_core/lib/src/logic/ws_client.dart`
- `client/modules/flash_im_core/lib/flash_im_core.dart`
- `client/modules/flash_im_core/test/ws_client_test.dart`

改动类型：`修改文件`

### 2.1 新增三条 broadcast controller/stream 并在 dispose 关闭 `✅`

```dart
Stream<FriendRequestEvent> get friendRequestStream;
Stream<FriendAcceptedEvent> get friendAcceptedStream;
Stream<FriendRemovedEvent> get friendRemovedStream;
```

### 2.2 在 `_handleBinaryMessage` 解码三类好友帧 `✅`

### 2.3 公共导出好友协议类型并覆盖单测 `✅`

## 任务 3：创建 `flash_im_friend` 包配置与导出 `✅ 已完成`

文件：

- `client/modules/flash_im_friend/pubspec.yaml`
- `client/modules/flash_im_friend/analysis_options.yaml`
- `client/modules/flash_im_friend/lib/flash_im_friend.dart`

改动类型：`新建文件`

### 3.1 声明 dio、equatable、flutter_bloc、flash_im_core、flash_shared 依赖 `✅`

### 3.2 导出 Repository、模型、Cubit、状态与页面 `✅`

## 任务 4：创建好友数据模型 `✅ 已完成`

文件：

- `client/modules/flash_im_friend/lib/src/data/friend_user.dart`
- `client/modules/flash_im_friend/lib/src/data/friend_request.dart`

改动类型：`新建文件`

### 4.1 定义 `FriendUser` 与关系状态便捷属性 `✅`

```dart
class FriendUser extends Equatable {
  final int accountId;
  final String nickname;
  final String avatar;
  final String signature;
  final String? flashId;
  final String? relationStatus;
}
```

### 4.2 定义 `FriendRequest` 与 `FriendAcceptResult` JSON 解析 `✅`

## 任务 5：实现好友 HTTP Repository `✅ 已完成`

文件：`client/modules/flash_im_friend/lib/src/data/friend_repository.dart`

改动类型：`新建文件`

### 5.1 定义 `FriendRepository` 接口 `✅`

包含 `getFriends`、`getReceivedRequests`、`searchUsers`、`getUser`、`sendRequest`、`acceptRequest`、`rejectRequest`、`removeFriend`。

### 5.2 实现 `DioFriendRepository` 与严格 JSON 解析 `✅`

API 路径使用 `/api/friends...` 与 `/api/users...`。

## 任务 6：实现好友 Cubit 与状态 `✅ 已完成`

文件：

- `client/modules/flash_im_friend/lib/src/logic/friend_state.dart`
- `client/modules/flash_im_friend/lib/src/logic/friend_cubit.dart`

改动类型：`新建文件`

### 6.1 定义不可变 `FriendState` `✅`

包含列表、申请、搜索、加载/搜索/操作状态、错误信息和 `pendingRequestCount`。

### 6.2 实现 HTTP 加载、搜索、申请、接受、拒绝、删除 `✅`

### 6.3 订阅三类好友 WS 事件并按 ID 去重，close 时取消订阅 `✅`

## 任务 7：实现好友客户端页面 `✅ 已完成`

文件：

- `client/modules/flash_im_friend/lib/src/view/contacts_page.dart`
- `client/modules/flash_im_friend/lib/src/view/new_friends_page.dart`
- `client/modules/flash_im_friend/lib/src/view/add_friend_page.dart`
- `client/modules/flash_im_friend/lib/src/view/friend_search_page.dart`
- `client/modules/flash_im_friend/lib/src/view/friend_profile_page.dart`
- `client/modules/flash_im_friend/lib/src/view/send_friend_request_page.dart`
- `client/modules/flash_im_friend/lib/src/view/widgets/friend_avatar_tile.dart`

改动类型：`新建文件`

### 7.1 通讯录页 `✅`

结构：居中标题 + 搜索/+；“新的朋友”入口；白色好友列表；空态/错误/下拉刷新。

### 7.2 新的朋友页 `✅`

显示头像、昵称、验证留言、接受/拒绝操作与行级 loading。

### 7.3 添加与搜索页 `✅`

添加页只展示当前可用的搜索入口；搜索页自动聚焦、提交搜索、展示结果与空态。

### 7.4 资料与验证页 `✅`

按 `relationStatus` 展示添加、等待验证、处理申请或发消息；好友可二次确认删除；验证留言最多 200 字。

## 任务 8：接入宿主 `✅ 已完成`

文件：

- `client/pubspec.yaml`
- `client/lib/app/flash_im_app.dart`
- `client/lib/features/home/presentation/main_shell_page.dart`
- `client/lib/features/home/presentation/widgets/home_navigation_bar.dart`
- 删除 `client/lib/features/contacts/presentation/contacts_placeholder_page.dart`

改动类型：`配置 + 修改 + 删除占位文件`

### 8.1 注入 `FriendRepository` `✅`

支持构造参数覆盖，默认复用认证 Dio。

### 8.2 创建并释放 `FriendCubit`，替换通讯录占位页 `✅`

### 8.3 好友发消息时定位私聊会话并复用现有 `_openChat` `✅`

### 8.4 底部通讯录图标展示 pending 请求 Badge `✅`

## 任务 9：好友模块测试 `✅ 已完成`

文件：

- `client/modules/flash_im_friend/test/friend_models_test.dart`
- `client/modules/flash_im_friend/test/friend_repository_test.dart`
- `client/modules/flash_im_friend/test/friend_cubit_test.dart`
- `client/modules/flash_im_friend/test/contacts_page_test.dart`

改动类型：`新建文件`

### 9.1 覆盖 JSON、API 路径与错误格式 `✅`

### 9.2 覆盖加载、申请处理及 WS 增量 `✅`

### 9.3 覆盖通讯录只呈现已实现入口 `✅`

## 最后：格式化、定向分析与测试 `✅ 已完成`

改动类型：`验证`

### 10.1 格式化修改的 Dart 文件 `✅`

```bash
dart format client/lib client/modules/flash_im_core/lib client/modules/flash_im_core/test client/modules/flash_im_friend
```

### 10.2 定向分析 `✅`

```bash
cd client/modules/flash_im_core && flutter analyze
cd client/modules/flash_im_friend && flutter analyze
cd client && flutter analyze lib/app/flash_im_app.dart lib/features/home/presentation/main_shell_page.dart lib/features/home/presentation/widgets/home_navigation_bar.dart
```

### 10.3 定向测试 `✅`

```bash
cd client/modules/flash_im_core && flutter test
cd client/modules/flash_im_friend && flutter test
```


## 实际验证结果

| 命令 | 结果 |
| --- | --- |
| `cd client/modules/flash_im_core && flutter analyze --no-pub` | 通过，No issues found |
| `cd client/modules/flash_im_core && flutter test` | 通过，12 tests passed |
| `cd client/modules/flash_im_friend && flutter analyze --no-pub` | 通过，No issues found |
| `cd client/modules/flash_im_friend && flutter test --no-pub` | 通过，7 tests passed |
| `cd client && flutter analyze --no-pub lib/app/flash_im_app.dart lib/features/home/presentation/main_shell_page.dart lib/features/home/presentation/widgets/home_navigation_bar.dart test/features/main_shell/presentation/main_shell_page_test.dart` | 通过，No issues found |
| `cd client && flutter test --no-pub test/features/main_shell/presentation/main_shell_page_test.dart` | 通过，1 test passed |
| `git diff --check` | 通过，无空白错误 |

未执行 Gradle/Android、Xcode/iOS 构建；本次为 Flutter 客户端范围。API 链路测试阶段不新增文件：服务端好友链路脚本与生成文档已存在于 `docs/features/im/friend/api/friend/`，本次未修改服务端契约。

## 补充任务 11：好友资料页微信式布局 `✅ 已完成`

文件：

- `client/modules/flash_im_friend/lib/src/view/friend_profile_page.dart`
- `client/modules/flash_im_friend/test/contacts_page_test.dart`

完成内容：

- 放大头像与主资料区，使用白色内容块和灰色分组背景。
- 账号与个性签名改为资料分组行，发消息/添加好友改为居中操作行。
- 删除好友移动到右上角更多菜单，保留二次确认和原业务回调。
- 未增加朋友圈、朋友权限、音视频通话等未实现入口。

验证结果：

| 命令 | 结果 |
| --- | --- |
| `flutter analyze --no-pub lib/src/view/friend_profile_page.dart test/contacts_page_test.dart` | 通过，No issues found |
| `flutter test --no-pub test/contacts_page_test.dart` | 通过，1 test passed |

## 补充任务 12：通讯录标题与右侧操作布局 `✅ 已完成`

- `_ContactsHeader` 使用 `double.infinity` 占满可用宽度，移除固定屏宽值。
- 标题保持相对整屏居中，搜索与添加按钮固定在右侧。
- Widget 测试增加标题中心点及两个右侧按钮位置断言。

验证：`flutter analyze --no-pub lib/src/view/contacts_page.dart test/contacts_page_test.dart` 与 `flutter test --no-pub test/contacts_page_test.dart` 均通过。
