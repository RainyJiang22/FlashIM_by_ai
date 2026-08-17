# 群聊 v0.0.2 测试 Agent 验收报告

## 结论

**FAIL**

当前实现已经覆盖群详情、改名、成员展示、邀请卡片、群主解散和首页锚点菜单的主要 happy path，两份 Harness Check 也均为 `PASS`。但是“同意邀请”事务没有按 Spec 锁定群记录，存在与解散、其他邀请同时提交时破坏群成员上限或恢复已解散群成员的并发窗口。这是群邀请与解散主链路的正确性问题，不能仅以现有测试和覆盖率放行。

此外，真实 `9600` API 链路仍未执行；若干任务清单声称已覆盖的关键语义没有对应断言。因此即使修复并发问题，仍需补齐下面列出的最小测试后再验收。

## 验收基准

- 用户需求与补充需求。
- `docs/features/im/group/v0.0.2/analysis.md`
- `docs/features/im/group/v0.0.2/client/design.md`
- `docs/features/im/group/v0.0.2/server/design.md`
- `docs/features/im/group/v0.0.2/client/tasks.md`
- `docs/features/im/group/v0.0.2/server/tasks.md`
- 当前工作区 diff。
- `quality/harness-check-client-attempt-2.json`
- `quality/harness-check-server-attempt-3.json`

本次为只读验收，没有重新运行测试，也没有修改源码、测试、任务清单或 API 文档。

## 阻断问题

### 1. 同意邀请没有锁定群记录，无法保证成员上限和解散原子性

状态：**FAIL（阻断）**

Spec 明确要求同意邀请时“BEGIN + 锁定邀请和群”，并要求群主解散原子撤销全部成员资格：

- `server/design.md:194-209`
- `server/design.md:222-239`
- `analysis.md:109-117`

当前实现只对 `group_invitations` 执行 `FOR UPDATE`：

- `server/modules/im-group/src/repository.rs:391-397`

随后仅用普通 `SELECT EXISTS` 检查群未解散，没有 `FOR UPDATE`：

- `server/modules/im-group/src/repository.rs:408-423`

成员数读取和成员写入也处于这个未锁群的窗口：

- `server/modules/im-group/src/repository.rs:447-465`

可能出现两类竞态：

1. 群已有 199 人时，两条不同邀请并发同意，各自读取 199 后均插入，群人数超过 200。
2. 同意邀请与解散并发时，同意事务可能在解散软删除全部成员之后重新写回一条 `is_deleted=false` 成员记录，破坏“解散后撤销全部成员资格”的数据库不变量。

最小修复建议：在接受邀请的同一事务中，对目标 active group 执行 `SELECT ... FOR UPDATE`，并确保直接添加、接受邀请和解散都按同一群行锁串行化；补充“199 人同时接受两条邀请”和“接受邀请与解散并发”两个 PostgreSQL 测试。

### 2. 批量邀请逐个提交，后项失败会留下前项副作用

状态：**FAIL（边界语义）**

Spec 对非好友、已入群和超限明确要求“整批请求不写入”：

- `analysis.md:132-140`

当前 `invite_members` 对候选人逐个调用 Repository；每次 `create_group_invitation` 都独立开启并提交事务，随后立刻发送私聊卡片：

- `server/modules/im-group/src/service.rs:148-200`
- `server/modules/im-group/src/repository.rs:308-365`

如果第一位好友邀请和卡片已成功、第二位候选人因非好友或已入群失败，接口整体返回错误，但第一位的 pending 邀请和卡片已经保留，不符合“整批请求不写入”。当前失败回收也只删除本轮候选人的邀请：

- `server/modules/im-group/src/service.rs:183-190`

最小修复建议：先在单事务内批量校验全部候选人的好友关系、成员冲突和容量，再开始创建邀请；补充“第一位有效、第二位无效”批量请求用例，断言没有任何 pending 邀请和邀请卡片产生。若产品允许消息投递阶段部分成功，需要先修改 Spec 和接口响应为逐项结果，不能保持当前整批失败语义。

## 逐条验收

| 验收项 | 状态 | 实现证据 | 测试/命令证据 | 缺失边界 |
| --- | --- | --- | --- | --- |
| 群聊右上角进入群详情 | PASS | `client/modules/flash_im_chat/lib/src/view/chat_page.dart:97-108`；`client/lib/app/app_router.dart:172-185,243-253` | `client/test/app/app_router_group_test.dart:114-145`；客户端 Harness 全部命令 PASS | 未做真机视觉验收，但入口、路由和返回结果已覆盖 |
| 群主修改群名并同步聊天标题 | PASS | `group_details_page.dart:130-152`；`group_detail_cubit.dart:38-54`；服务端 owner 条件 `repository.rs:65-118` | `group_details_page_test.dart:49-54`；`app_router_group_test.dart:134-145`；服务端 round-trip `server/src/lib.rs:384-402` | 普通成员越权改名只在未执行的 API 脚本中有独立 403 步骤；SQL 权限条件已存在 |
| 显示完整成员列表，成员末尾添加入口 | PASS | 服务端不分页返回所有 active members：`server/modules/im-group/src/repository.rs:38-63`；Grid 在全部 members 后追加“添加”：`group_member_grid.dart:24-53` | `group_details_page_test.dart:44-47`；`group_member_picker_page_test.dart:10-47` | 没有 200 人大列表 widget 性能/滚动测试 |
| 普通成员关闭验证时直接添加好友 | INCOMPLETE | 客户端分支 `group_details_page.dart:187-210`；服务端权限分支 `repository.rs:215-260` | Harness PASS，但现有 PostgreSQL 路由测试只断言“验证开启时普通成员直加为 403”：`server/src/lib.rs:420-430` | 缺少验证关闭时普通成员直加成功、非好友整批回滚和 200 人上限的 DB/API 断言 |
| 验证开启时发送私聊邀请卡片 | FAIL | 服务端创建 pending 并通过消息服务发送 type 4：`service.rs:130-202`；客户端解析和卡片：`message.dart:193-208,236-250`、`group_invitation_bubble.dart:27-161` | 卡片 widget 同意状态：`message_bubble_test.dart:99-138`；路由 happy path 创建邀请：`server/src/lib.rs:432-447` | 批量邀请存在部分提交；路由测试没有读取私聊历史并断言 `msg_type=4`；真实 API 第 6、7 步未执行 |
| 好友点击同意后才入群并进入群聊 | FAIL | 接受接口与客户端导航已接线：`server/modules/im-group/src/routes.rs:149-163`；`client/lib/app/app_router.dart:186-201` | 服务端 round-trip 仅断言 accept 返回 200：`server/src/lib.rs:449-456`；卡片 callback 测试通过 | 接受事务未锁群；没有断言接受前非成员、接受后成为成员、重复点击幂等、邀请人被移除、群已解散、并发满员；客户端宿主测试的 `acceptInvitation` 仍是 `UnimplementedError`，没有覆盖 Repository 到入群路由 |
| 群主直接添加、删除成员 | INCOMPLETE | owner 可绕过验证直加：`server/modules/im-group/src/repository.rs:225-233`；删除保护 owner：`repository.rs:263-300`；客户端删除二次确认：`group_details_page.dart:214-237` | 删除接口 round-trip：`server/src/lib.rs:458-465`；页面仅断言“删除”入口可见：`group_details_page_test.dart:44-47` | 没有群主直加成功的路由断言；没有实际点击删除模式、选择成员、二次确认后列表刷新的 widget 测试；任务清单 `client/tasks.md:217-223` 的覆盖声明高于现有断言 |
| 群主二次确认解散并刷新首页 | FAIL | 解散 UI、结果上抛和首页按 true 刷新：`group_details_page.dart:156-173,240-262`；`app_router.dart:180-184`；`main_shell_page.dart:110-131`；服务端软解散：`repository.rs:480-515` | 群主/成员解散权限和解散后详情 404：`server/src/lib.rs:467-492`；页面确认调用：`group_details_page_test.dart:56-61` | 被“接受邀请未锁群”的竞态破坏；没有断言 pending 邀请失效、解散后历史/发消息拒绝、会话列表隐藏；没有客户端“详情 dissolved → 关闭聊天 → MainShell refresh”的整体测试 |
| 首页简约、锚点下方、可扩展快捷菜单 | PASS | 数据化 action model 和 `MenuAnchor`：`message_quick_actions_menu.dart:4-21,25-92`；当前“发起群聊” action：`messages_placeholder_page.dart:117-126` | `main_shell_page_test.dart:98-111` 断言 action 的 y 坐标位于入口下方并进入建群页 | 没有多 action 布局测试；结构已支持 action 列表扩展 |
| 保留既有私聊、群创建、会话未读、媒体与通讯录行为 | INCOMPLETE | 当前 diff 未见主动删除既有路径；MainShell 仅在 chat 返回 `true` 时刷新，避免普通返回重置未读：`main_shell_page.dart:120-131` | 客户端 Harness：conversation 15、group 20、chat 38、宿主定向 6 个测试全部通过；服务端 49 个测试通过 | 未运行完整 `client` 全量测试，只运行宿主 3 个定向文件；无设备级回归；API 脚本未执行 |

## Harness 证据

### 客户端

来源：`quality/harness-check-client-attempt-2.json`

- 总状态：PASS，生成时间 `2026-08-17T03:37:29Z`。
- `flash_im_conversation`：15 tests passed。
- `flash_im_group`：20 tests passed。
- `flash_im_chat`：38 tests passed。
- 宿主定向测试：6 tests passed。
- 4 组 `flutter analyze`：PASS。
- changed-scope 覆盖率：`1134/1384 = 81.94%`，超过 80% 门槛。
- `unmeasured_changed_files` 为空。

### 服务端

来源：`quality/harness-check-server-attempt-3.json`

- 总状态：PASS，生成时间 `2026-08-17T03:39:32Z`。
- `cargo test -p im-group -p im-conversation -p im-message -p falsh-im`：23 + 14 + 4 + 8 = 49 tests passed。
- `cargo fmt --all --check`：PASS。
- `cargo clippy -p im-group -p im-conversation -p im-message --all-targets -- -D warnings`：PASS。
- `cargo clippy -p falsh-im --lib --no-deps -- -D warnings`：PASS。
- changed-scope 覆盖率：`1512/1662 = 90.97%`，超过 80% 门槛。
- `unmeasured_changed_files` 为空。

Harness PASS 证明当前命令集无失败和覆盖率达标，但不能覆盖上述未建模并发竞态，也不能替代未执行的真实 API 链路。

## 未完成的外部链路

状态：**INCOMPLETE**

`server/tasks.md:199-224` 明确记录 API 链路仍待执行，原因是本地 `9600` 被旧服务占用；`api/group_management/doc/00_link.md` 的 13 个接口文档仍全部显示“运行后生成”。因此以下外部行为尚无本轮真实响应文档：

- 普通成员越权改名 403。
- 验证开启后直加 403。
- 私聊历史真实返回 `GROUP_INVITATION=4`。
- 被邀请人接受后才成为成员。
- 群主直加、删除。
- 非群主解散 403、群主解散 200、解散后详情 404。

## 最小复验清单

1. 修复接受邀请时缺失的群行锁，并增加两个并发 PostgreSQL 测试。
2. 修复或明确批量邀请的原子/逐项语义，增加前项有效后项无效的回滚测试。
3. 扩展服务端 round-trip：断言邀请前后成员关系、私聊 `msg_type=4`、群主直加、pending 邀请失效、解散后历史和发消息均失败。
4. 扩展客户端宿主测试：邀请卡片调用真实 Fake GroupRepository 后进入群聊天；解散结果关闭 Chat 并只触发一次首页会话刷新。
5. 在可控的新端口启动当前服务，执行 `api/group_management/request/group_management.py`，生成并核对 01～13 中文响应文档。
6. 重新生成新的 client/server Harness attempt；两端覆盖率继续不低于 80%，格式、测试和静态检查全部 PASS 后再提交测试 Agent 复验。
