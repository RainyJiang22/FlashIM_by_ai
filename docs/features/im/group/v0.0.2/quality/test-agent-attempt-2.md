# 群聊 v0.0.2 测试 Agent 验收报告（attempt 2）

## 结论

**FAIL**

attempt 1 的两个主要实现缺陷已经得到实质修复：接受邀请现在锁定群行并与解散串行化；批量邀请也改为全量校验、单事务创建。新的客户端和服务端 Harness 均为 `PASS`。

本轮仍不放行，原因集中在邀请可靠性契约和关键回归测试：

1. `delivered=false` 时服务端已经删除 pending 邀请，却仍返回 `status="pending"` 和一个不可接受的邀请 ID，响应事实不一致。
2. attempt 1 明确要求的“199 人群同时接受两条邀请”测试没有补充；当前锁实现从静态上能够串行化，但没有直接回归证据。
3. 部分投递失败的服务端清理、成功项保留、客户端中文失败提示均没有失败路径测试。

本次只读复核当前源码、测试和以下新 Harness，没有重新运行命令，也没有修改源码、任务或其他文档：

- `quality/harness-check-client-attempt-3.json`
- `quality/harness-check-server-attempt-4.json`

## attempt 1 失败点复验

### 1. 接受邀请与解散并发

状态：**PASS**

实现证据：

- 接受邀请先定位 invitation，再对 active conversation 执行 `FOR UPDATE`：`server/modules/im-group/src/repository.rs:399-427`。
- 获取群行锁后再锁 invitation、检查人数并写成员：`server/modules/im-group/src/repository.rs:429-497`。
- 解散继续通过同一个 `lock_group_for_actor` 锁群，再标记 dissolved、软删除成员并删除 pending 邀请：`server/modules/im-group/src/repository.rs:500-535`。

测试证据：

- `server/src/lib.rs:606-701` 并发发起 accept 与 dissolve，允许 accept 返回 200/404，要求 dissolve 返回 200，并最终断言 active member 数为 0。
- 该测试包含在 server attempt 4 的 `cargo test ... -p falsh-im` 中并通过。

结论：两个事务现在按群行锁串行，解散后不会再被接受邀请恢复有效成员。

### 2. 接受邀请与 200 人上限并发

状态：**INCOMPLETE**

实现证据：

- 所有接受邀请事务都会先获取同一群行锁，然后读取 active member count；达到 200 时返回冲突：`server/modules/im-group/src/repository.rs:413-427,467-470`。
- 因群行锁串行化，两条不同邀请不能同时读取同一个 199 人快照，静态实现已修复 attempt 1 指出的竞态。

测试缺口：

- 当前服务端测试中没有构造 199 人群、两条 pending 邀请并发 accept 的用例。
- `rg` 仅能定位人数限制实现，不能定位 199/200 并发断言；attempt 4 的测试清单也没有对应测试名。

最小补充：构造 199 个 active members 和两条不同邀请，`tokio::join!` 同时接受；断言仅一个 200、另一个 409，最终 active member count 恒等于 200。

### 3. 批量邀请全量校验与无副作用失败

状态：**PASS**

实现证据：

- `create_group_invitations` 在同一事务中锁群，并对完整 `invitee_ids` 一次性校验好友关系、已有成员和容量：`server/modules/im-group/src/repository.rs:308-327`。
- 所有校验通过后才循环插入，最后统一提交：`server/modules/im-group/src/repository.rs:329-373`。
- Service 不再逐个创建/提交邀请，而是先调用批量 Repository：`server/modules/im-group/src/service.rs:147-156`。

测试证据：

- `server/src/lib.rs:481-500` 提交“第一位有效、第二位已在群”的批量邀请，断言 400，并查询确认第一位没有 pending 邀请。
- 该真实 PostgreSQL 路由测试在 server attempt 4 中通过。

结论：非好友、已入群和超限等预校验错误不会留下半批 invitation。

### 4. 邀请投递部分失败契约

状态：**FAIL**

已完成部分：

- 批量预校验成功后，Service 对每个新邀请分别持久化私聊卡片；单项持久化失败会删除该 pending invitation，并在响应中返回 `delivered=false`，其余项可以继续：`server/modules/im-group/src/service.rs:156-206`。
- 消息持久化、seq、会话预览和未读更新已合并到一个事务：`server/modules/im-message/src/repository.rs:27-137`。
- WS 广播改为提交后的 best-effort，不再因广播失败删除已经有历史卡片的 invitation：`server/modules/im-message/src/service.rs:110-155`。
- 客户端只要发现任一 `delivered != true` 就抛出领域错误，Cubit 显示“部分群邀请发送失败，请重试”：`client/modules/flash_im_group/lib/src/data/group_repository.dart:87-100`、`client/modules/flash_im_group/lib/src/logic/group_detail_cubit.dart:149-159`。

阻断问题：

- 卡片持久化失败后，pending invitation 已在 `service.rs:183-190` 被删除；但响应仍无条件构造 `status: "pending"`、保留刚被删除的 `id`：`server/modules/im-group/src/service.rs:197-203`。
- 因此 API 对失败项宣称存在 pending invitation，实际数据库中不存在。当前客户端通过 `delivered` 绕过了这个矛盾，但接口契约对其他消费者和重试诊断并不可靠。

测试缺口：

- 没有测试让第二个 invitee 的私聊创建或消息持久化失败，并断言第一项保留、第二项清理及响应字段。
- `client/modules/flash_im_group/test/group_repository_test.dart:9-39,42-94` 只返回全部 `delivered=true`，没有覆盖 `delivered=false`、畸形列表和 Cubit 的中文部分失败提示。
- `server/src/lib.rs:415-431` 只证明普通消息在 broadcaster 失败时仍提交成功，没有从群邀请接口验证 invitation/card 一致性。

最小修复：失败项响应使用与事实一致的状态，例如 `status="failed"` 且 nullable invitation ID，或只返回 `invitee_id/delivered/error`；同步更新设计契约。补服务端部分失败测试和客户端 `delivered=false` Repository/Cubit 测试。

## 核心功能验收

| 验收项 | 状态 | 当前证据 | 遗留问题 |
| --- | --- | --- | --- |
| 群聊右上角进入群详情 | PASS | `chat_page.dart:97-108`；`app_router.dart:172-185,243-253`；路由/标题测试通过 | 无设备级视觉验收 |
| 修改群名并热更新聊天标题 | PASS | `group_details_page.dart:130-152`；`app_router_group_test.dart:114-145`；服务端 rename round-trip 通过 | 普通成员 403 仍主要依赖 SQL 权限和未执行 API 脚本 |
| 完整成员列表及末尾添加 | PASS | `repository.rs:38-63` 返回全部 active members；`group_member_grid.dart:24-53` 在成员后追加添加 | 无 200 人大列表性能测试 |
| 验证关闭时成员直接加好友 | INCOMPLETE | Repository 权限分支实现存在：`repository.rs:215-260` | 仍没有“普通成员 + 验证关闭”成功的 DB 路由测试 |
| 验证开启时邀请卡片及同意后入群 | FAIL | 卡片已持久化且接受前后成员关系有断言：`server/src/lib.rs:502-567`；客户端卡片测试通过 | 部分投递失败响应不一致；200 人并发 accept 无测试；客户端宿主接受后导航仍未覆盖 |
| 群主直接添加和删除成员 | INCOMPLETE | 服务端 owner 分支与删除保护存在；删除 round-trip 通过 | 群主直接添加成功、客户端实际删除模式/确认/列表刷新仍无完整测试 |
| 群主解散群 | PASS | 解散权限、详情 404、accept/dissolve 并发最终 0 active members 均有 DB 测试 | pending 邀请失效、解散后历史/发消息和客户端关闭 Chat→刷新首页仍缺独立断言 |
| 首页锚点下方可扩展菜单 | PASS | `MenuAnchor` 数据化 actions；MainShell 测试断言 action 位于按钮下方并可建群 | 无多 action 布局测试 |
| 防止伪造邀请卡片 | PASS | WS 外部入口只允许 type 0～3：`server/modules/im-ws/src/dispatcher.rs:40-76`；`client_cannot_forge_group_invitation_message` 通过 | 尚无完整 WS 握手级 type 4 拒绝测试，dispatcher 单测已覆盖边界 |
| 解散与消息发送串行化 | PASS | 消息事务锁 active conversation 后再写 seq/message：`server/modules/im-message/src/repository.rs:13-45,47-137` | 没有真实并发 send/dissolve 测试，只有 SQL 锁断言 |

## Harness 摘要

### Client attempt 3

- 总状态：PASS；生成时间 `2026-08-17T04:06:39Z`，晚于本轮客户端生产代码修改。
- conversation 15、group 20、chat 38、宿主定向 6 个测试通过。
- 4 组 `flutter analyze` 均 PASS。
- changed-scope 覆盖率：`1137/1388 = 81.92%`，门槛 80%。
- `unmeasured_changed_files=[]`。

### Server attempt 4

- 总状态：PASS；生成时间 `2026-08-17T04:05:53Z`，晚于本轮服务端生产代码修改。
- falsh-im 23、im-conversation 14、im-group 4、im-message 9、im-ws 6，共 56 个测试通过。
- `cargo fmt --all --check` PASS。
- 两组 Clippy `-D warnings` PASS。
- changed-scope 覆盖率：`1618/1925 = 84.05%`，门槛 80%。
- `unmeasured_changed_files=[]`。

Harness 新鲜且通过，但总覆盖率不能替代缺失的并发上限和投递失败定向测试。

## 遗留 INCOMPLETE

1. 独立 Python 13 步 API 链仍未执行；`api/group_management/doc/00_link.md:7-23` 仍全部为“运行后生成”。
2. 199 人群两条邀请并发接受没有测试。
3. 部分投递失败的服务端逐项结果和客户端错误提示没有测试。
4. 验证关闭的普通成员直加成功、群主直加成功没有路由 round-trip。
5. 客户端没有覆盖邀请卡片接受后真实宿主导航，也没有覆盖解散结果关闭当前 Chat 并只刷新一次首页列表。
6. 解散后历史读取/消息发送、pending invitation 接受失败缺少独立接口断言。

## 下一次复验最低条件

1. 修正 `delivered=false` 项的状态/ID 响应事实，并补服务端部分失败测试。
2. 补客户端 `delivered=false` Repository 与 Cubit 中文反馈测试。
3. 补 199 人群并发接受两条邀请的 PostgreSQL 测试。
4. 重新生成比修复代码更新的 client/server Harness，覆盖率继续不低于 80%，所有测试、格式和静态检查 PASS。
5. 若本轮仍不执行独立 Python API 链，需保留为明确的 `INCOMPLETE`，不得描述为已经生成真实 01～13 响应文档。
