# 群治理与群信息实时同步 — 客户端任务清单

基于 [design.md](./design.md) 增量实现 Flutter 客户端 v0.0.4。

全局约束：使用 Cubit；复用现有 `GroupDetailsPage`、Repository、会话列表和 ChatPage，不建立平行模块；type=5 直接展示服务端 content；HTTP 初始值 + WS 增量；群聊 UI 延续当前 Flash IM iOS 风格与高对比度选项；宿主负责跨模块路由接线；不运行 Gradle/Android 或 Xcode/iOS 构建。

---

## 执行顺序

1. ⬜ 任务 1 — 生成客户端 protobuf 并扩展 WsClient（依赖服务端协议）
2. ⬜ 任务 2 — Conversation 解散状态与列表同步（依赖任务 1）
3. ⬜ 任务 3 — GroupDetail/Repository 治理契约（依赖任务 1）
4. ⬜ 任务 4 — GroupDetailCubit 治理与实时状态（依赖任务 3）
5. ⬜ 任务 5 — 群名、公告和转让页面（依赖任务 4）
6. ⬜ 任务 6 — 扩展群详情角色化 UI（依赖任务 4-5）
7. ⬜ 任务 7 — ChatPage 解散只读与系统消息泛化（依赖任务 2）
8. ⬜ 任务 8 — 会话行与宿主路由接线（依赖任务 2、6、7）
9. ⬜ 任务 9 — Core/Conversation/Group/Chat/Host 测试（依赖任务 1-8）
10. ⬜ 最后 — 客户端 Harness：测试、新鲜覆盖率 ≥80%、format/analyze（依赖任务 9）

---

## 任务 1：协议与 WsClient `⬜ 待处理`

文件：`client/modules/flash_im_core/lib/src/data/proto/group.pb*.dart`、`ws.pb*.dart`、`lib/src/logic/ws_client.dart`、`flash_im_core.dart`；改动类型：生成 + 修改。

### 1.1 重新生成并导出协议 `⬜`

从仓库 `proto/group.proto`、`proto/ws.proto` 生成 Dart 文件，保留 0～10 帧编号，新增 type 11。

### 1.2 群信息事件 stream `⬜`

增加 controller/getter/decode/dispose：

```dart
Stream<GroupInfoUpdateNotification> get groupInfoUpdateStream;
```

## 任务 2：Conversation 与列表同步 `⬜ 待处理`

文件：`client/modules/flash_im_conversation/lib/src/data/conversation.dart`、`logic/conversation_list_cubit.dart`、`view/conversation_tile.dart`；改动类型：修改。

### 2.1 解散字段 JSON/copy/Equatable `⬜`

```dart
final bool isDissolved;
```

旧 mock 未提供字段时默认 false。

### 2.2 消费群信息事件 `⬜`

Cubit 订阅 type 11：`membershipActive=false` 删除会话；否则更新 name/avatar/owner/isDissolved；close 取消订阅。

### 2.3 会话行标识 `⬜`

已解散群显示清晰“已解散”标签，保留最后消息预览和点击历史入口。

## 任务 3：群数据与 Repository `⬜ 待处理`

文件：`client/modules/flash_im_group/lib/src/data/group_detail.dart`、`group_repository.dart`、`flash_im_group.dart`；改动类型：修改。

### 3.1 GroupDetail 公告/解散字段 `⬜`

增加 announcement、updatedAt、updatedBy、updatedByName、isDissolved 的 JSON、copy/merge 与 props。

### 3.2 REST 方法 `⬜`

```dart
Future<void> leaveGroup(String groupId);
Future<GroupDetail> transferOwner(String groupId, int ownerId);
Future<GroupDetail> updateAnnouncement(String groupId, String announcement);
```

扩展中文错误映射，不在页面解析 Dio。

## 任务 4：GroupDetailCubit `⬜ 待处理`

文件：`client/modules/flash_im_group/lib/src/logic/group_detail_state.dart`、`group_detail_cubit.dart`；改动类型：修改。

### 4.1 动作状态和结果 `⬜`

状态支持 saving、left、removed、dissolved；构造时接收 `WsClient` 并只处理当前 groupId。

### 4.2 治理方法 `⬜`

```dart
Future<bool> leaveGroup();
Future<bool> transferOwner(int memberId);
Future<bool> updateAnnouncement(String value);
```

HTTP 成功更新详情；WS 移除立即退场；type 11 重复事件幂等。

### 4.3 生命周期 `⬜`

`close()` 取消 stream subscription，禁止 close 后 emit。

## 任务 5：治理子页面 `⬜ 待处理`

文件：`client/modules/flash_im_group/lib/src/view/group_name_edit_page.dart`、`group_announcement_page.dart`、`transfer_group_owner_page.dart`；改动类型：新建。

### 5.1 群名独立编辑页 `⬜`

1～100 字、字符计数、保存 loading；调用传入 callback，不创建新 Cubit。

### 5.2 公告查看/编辑页 `⬜`

普通成员只读；群主可进入编辑态，1～2000 字、计数、发布确认、更新人/时间和空态。

### 5.3 转让页 `⬜`

只列出排除当前群主的活跃成员；单选后弹二次确认，执行期间禁用重复点击。

## 任务 6：GroupDetailsPage `⬜ 待处理`

文件：`client/modules/flash_im_group/lib/src/view/group_details_page.dart`；改动类型：修改。

### 6.1 注入 WsClient 与路由结果 `⬜`

沿用现有 Repository provider，Cubit 增加 WsClient；返回 `updated/left/removed/dissolved` 明确结果。

### 6.2 iOS 风格信息组 `⬜`

成员宫格保持不变；群名/群号/公告/入群验证使用当前卡片、分隔线、CupertinoSwitch 和高对比度副文案。

### 6.3 角色化危险操作 `⬜`

群主显示转让、解散；普通成员显示退出。退出/解散均二次确认，saving 时禁用。

## 任务 7：ChatPage 与系统消息 `⬜ 待处理`

文件：`client/modules/flash_im_chat/lib/src/view/chat_page.dart`、`view/bubble/message_bubble.dart`；改动类型：修改。

### 7.1 解散只读 UI `⬜`

ChatPage 接收最新 `Conversation`；已解散群隐藏详情入口，保留历史列表，输入与媒体入口替换为“该群聊已解散”。

### 7.2 type=5 权威文本 `⬜`

所有 type=5 直接显示 `message.content`；`system_event` 仅作语义/测试使用，未知事件不得拼成“创建了群聊”。

## 任务 8：宿主接线 `⬜ 待处理`

文件：`client/lib/features/home/presentation/main_shell_page.dart`；改动类型：修改。

### 8.1 ChatPage 实时会话来源 `⬜`

打开聊天时复用现有 `ConversationListCubit`，让当前 conversation 随 type 11 更新；退群/被移除关闭聊天，解散留在只读页。

### 8.2 详情返回结果 `⬜`

`updated` 合并会话，`left/removed` 从列表移除并关闭页面，`dissolved` 保留并标记；不重复创建 Repository/Cubit。

## 任务 9：客户端测试 `⬜ 待处理`

文件：

- `client/modules/flash_im_core/test/ws_client_test.dart`
- `client/modules/flash_im_conversation/test/{conversation_list_cubit,conversation_tile}_test.dart`
- `client/modules/flash_im_group/test/{group_detail,group_repository,group_detail_cubit,group_details_page,group_governance_pages}_test.dart`
- `client/modules/flash_im_chat/test/{chat_page,message_bubble}_test.dart`
- `client/test/features/main_shell/presentation/main_shell_page_test.dart`

改动类型：新增 + 修改测试。

### 9.1 协议、模型、Repository、Cubit `⬜`

覆盖 type 11 解码/close、公告空值和时间、三个 REST 方法、WS 幂等、角色变化、退出/移除/解散结果、会话更新/删除。

### 9.2 Widget/宿主回归 `⬜`

覆盖群主与成员入口、公告读写、转让确认、iOS 开关对比度、已解散输入禁用/详情隐藏/历史保留、未知 type=5 文本和跨模块返回结果。

## 最后：客户端 Harness Check `⬜ 待处理`

```bash
cd client/modules/flash_im_core && dart format --set-exit-if-changed lib test && flutter test --coverage && flutter analyze
cd client/modules/flash_im_conversation && dart format --set-exit-if-changed lib test && flutter test --coverage && flutter analyze
cd client/modules/flash_im_group && dart format --set-exit-if-changed lib test && flutter test --coverage && flutter analyze
cd client/modules/flash_im_chat && dart format --set-exit-if-changed lib test && flutter test --coverage && flutter analyze
cd client && dart format --set-exit-if-changed lib test && flutter test --coverage && flutter analyze
```

每个包与宿主均使用新的 attempt 目录保存输出；按本次变更生产代码计算 changed coverage，必须不低于 80%。
