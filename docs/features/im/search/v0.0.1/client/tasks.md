# 综合搜索 — 客户端任务清单

基于 [design.md](design.md) 设计执行。状态管理使用 Cubit；`flash_im_search` 不依赖宿主路由或 group package；跨模块导航使用回调；复用 `FriendUser`、`Conversation`、`Message`；不实现聊天滚动锚点，不执行 Gradle/Xcode 构建。

---

## 执行顺序

1. ✅ 任务 1 — 创建 search package 与公开出口（无依赖）
2. ✅ 任务 2 — 搜索模型与 Repository（依赖任务 1）
3. ✅ 任务 3 — 搜索历史存储（依赖任务 1）
4. ✅ 任务 4 — 综合搜索 Cubit（依赖任务 2、3）
5. ✅ 任务 5 — 会话内搜索 Cubit（依赖任务 2）
6. ✅ 任务 6 — 高亮与详情页面（依赖任务 2）
7. ✅ 任务 7 — 综合搜索与会话搜索页面（依赖任务 4–6）
8. ✅ 任务 8 — 宿主依赖与 Repository 注入（依赖任务 1–3）
9. ✅ 任务 9 — 消息/通讯录首页入口（依赖任务 7、8）
10. ✅ 任务 10 — 单聊/群聊详情入口（依赖任务 7、8）
11. ✅ 任务 11 — 导航接线（依赖任务 8–10）
12. ✅ 任务 12 — 模块与宿主测试（依赖任务 1–11）
13. ⬜ 任务 13 — Harness Check、覆盖率和静态扫描（依赖任务 1–12）

---

## 任务 1：创建 search package 与公开出口 `✅ 已完成`

文件：`client/modules/flash_im_search/pubspec.yaml`、`lib/flash_im_search.dart`（新建）

### 1.1 声明依赖与导出 `✅`

声明 Dio、Equatable、Flutter Bloc、SharedPreferences，以及 friend/conversation/chat/shared path 依赖；仅导出公共模型、接口、Cubit 和页面。

## 任务 2：搜索模型与 Repository `✅ 已完成`

文件：`client/modules/flash_im_search/lib/src/data/search_models.dart`、`search_repository.dart`（新建）

### 2.1 定义消息分组 `✅`

```dart
class MessageSearchGroup extends Equatable {
  final Conversation conversation;
  final int matchCount;
  final List<Message> messages;
}
```

### 2.2 定义接口与 Dio 实现 `✅`

按设计中的四个 GET 接口解析已有领域模型；错误 payload 或类型不符抛 `FormatException`，Dio 错误由 Cubit 映射为分区失败。

## 任务 3：搜索历史存储 `✅ 已完成`

文件：`client/modules/flash_im_search/lib/src/data/search_history_store.dart`（新建）

### 3.1 抽象并实现 SharedPreferences `✅`

```dart
abstract interface class SearchHistoryStore {
  Future<List<String>> load();
  Future<List<String>> save(String query);
  Future<void> clear();
}
```

去空白、去重置顶、最多 20 条。

## 任务 4：综合搜索 Cubit `✅ 已完成`

文件：`client/modules/flash_im_search/lib/src/logic/search_state.dart`、`search_cubit.dart`（新建）

### 4.1 状态定义 `✅`

包含三个结果列表、pending/failed section、历史、关键词、`hasSearched`。

### 4.2 并发与过期响应保护 `✅`

`search` 同时启动三个受保护请求；每区完成即 emit；generation 不匹配时丢弃；全部完成后保存历史。提供 `retrySection`、`selectHistory`、`clearHistory`。

## 任务 5：会话内搜索 Cubit `✅ 已完成`

文件：`client/modules/flash_im_search/lib/src/logic/conversation_search_state.dart`、`conversation_search_cubit.dart`（新建）

### 5.1 实现独立查询状态 `✅`

空关键词清空；每次搜索更新 generation；成功、空结果、错误和过期响应均可测试。

## 任务 6：高亮与详情页面 `✅ 已完成`

文件：

- `client/modules/flash_im_search/lib/src/view/widgets/highlight_text.dart`
- `client/modules/flash_im_search/lib/src/view/message_detail_page.dart`
- `client/modules/flash_im_search/lib/src/view/single_message_page.dart`

（新建）

### 6.1 关键词高亮 `✅`

使用大小写不敏感的本地 span 拆分，不改变原文。

### 6.2 详情页 `✅`

消息分组详情展示发送者头像、昵称、内容、时间并通过回调进入 ChatPage；单条详情展示完整消息信息。

## 任务 7：搜索页面 `✅ 已完成`

文件：`client/modules/flash_im_search/lib/src/view/search_page.dart`、`conversation_search_page.dart`（新建）

### 7.1 综合搜索 `✅`

300ms 防抖；空关键词显示历史；三个分区默认各 3 条和“查看更多”；分区 loading/error/retry；消息组 `matchCount == 1` 直接回调打开会话，否则打开详情页。

### 7.2 会话内搜索 `✅`

300ms 防抖，展示消息列表；点击进入 `SingleMessagePage`。

## 任务 8：宿主依赖与 Repository 注入 `✅ 已完成`

文件：`client/pubspec.yaml`、`client/lib/app/flash_im_app.dart`（修改）

### 8.1 注册 package `✅`

```yaml
flash_im_search:
  path: modules/flash_im_search
```

### 8.2 注入 SearchRepository `✅`

`FlashImApp` 增加可测试覆盖参数，默认创建带鉴权 Dio 的 `DioSearchRepository`，加入 `MultiRepositoryProvider`。

## 任务 9：首页搜索入口 `✅ 已完成`

文件：

- `client/lib/features/messages/presentation/messages_placeholder_page.dart`
- `client/modules/flash_im_friend/lib/src/view/contacts_page.dart`

（修改）

### 9.1 消息首页 `✅`

新增可点击搜索栏和 `onSearch` 回调，保留头像、WS 状态与快捷菜单。

### 9.2 通讯录首页 `✅`

顶部综合搜索入口改由宿主回调，保留好友列表、添加好友和公开群搜索专用流程。

## 任务 10：聊天详情搜索入口 `✅ 已完成`

文件：

- `client/modules/flash_im_group/lib/src/view/private_chat_details_page.dart`
- `client/modules/flash_im_group/lib/src/view/group_details_page.dart`

（修改）

### 10.1 新增 `onSearchMessages` `✅`

两个详情页增加“查找聊天内容” ListTile；只触发回调，不依赖 search package。

## 任务 11：导航接线 `✅ 已完成`

文件：`client/lib/features/home/presentation/main_shell_page.dart`、`client/lib/app/app_router.dart`（修改）

### 11.1 综合搜索导航 `✅`

MainShell 进入 `SearchPage`；好友结果进入 `FriendProfilePage`，群/消息结果复用 `_openChat`。

### 11.2 会话内搜索导航 `✅`

详情路由携带当前 `Conversation`，打开 `ConversationSearchPage`；保留既有返回类型和群更新行为。

## 任务 12：模块与宿主测试 `✅ 已完成`

文件：

- `client/modules/flash_im_search/test/search_models_repository_test.dart`
- `client/modules/flash_im_search/test/search_history_store_test.dart`
- `client/modules/flash_im_search/test/search_cubit_test.dart`
- `client/modules/flash_im_search/test/search_pages_test.dart`
- 受构造参数影响的既有模块/宿主测试

### 12.1 数据与状态测试 `✅`

覆盖 JSON、历史上限/去重、三请求并发、逐区完成、部分失败、重试和响应乱序。

### 12.2 Widget 与导航测试 `✅`

覆盖 300ms 防抖、默认 3 条/展开、历史、消息单条/多条点击、会话详情入口，以及消息/通讯录首页真实进入综合搜索页。

执行记录（2026-09-04）：`flash_im_search` 11 个测试全部通过，模块行覆盖率 88.73%（433/488）；受影响的 friend/group/宿主导航 14 个回归测试全部通过。

## 任务 13：客户端质量门禁 `⬜ 待处理`

文件：`docs/features/im/search/v0.0.1/quality/`（新建报告）

### 13.1 Harness Check `⬜`

```bash
cd client/modules/flash_im_search && flutter test --coverage
cd client && flutter test --coverage
cd client && flutter analyze
python3 <feature-quality-gate>/scripts/harness_check.py ...
```

每次使用新 attempt id 和新鲜 lcov；变更生产代码覆盖率必须 `>= 80%`。完成测试 Agent、架构 Agent 和最终 Harness Check 后才标记任务完成。
