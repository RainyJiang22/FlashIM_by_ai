# 群聊 v0.0.2 架构 Agent 验收报告（attempt 3）

## 结论

**PASS**

attempt 2 之后的增量修改完整闭合了邀请部分投递失败契约，没有引入新的分层、依赖、事务或兼容性阻断；此前四个 P1 仍保持修复状态。

最新客户端 Harness `harness-check-client-attempt-4.json` 为 `PASS`，变更范围覆盖率 `82.56%`，Flutter test/analyze 全部通过；最新服务端 Harness `harness-check-server-attempt-5.json` 为 `PASS`，变更范围覆盖率 `85.19%`，Rust test、fmt、Clippy 全部通过，且没有未计量的变更生产文件。

## 本次邀请失败契约复验

### 1. 服务端响应模型：PASS

- `GroupInvitationItem.id` 已从必填 UUID 改为 `Option<Uuid>`；`conversation_id`、`invitee_id`、`status` 与 `delivered` 继续保留，使每个候选人的结果仍可稳定关联（`server/modules/im-group/src/models.rs:81-102`）。
- 投递成功时返回 `id=Some(...)`、`status=pending`、`delivered=true`；持久化失败并删除 pending invitation 后返回 `id=null`、`status=failed`、`delivered=false`（`server/modules/im-group/src/service.rs:156-206`）。

结论：失败响应不再泄露一个已被回收、无法接受的 invitation ID，响应字段之间语义一致。

### 2. 服务端真实失败与回收链：PASS

- invitation 仍先在单事务中整批校验和创建，输入错误不会形成前半批数据（`server/modules/im-group/src/repository.rs:308-373`）。
- 卡片持久化失败时仅回收对应的 pending invitation，其他已成功投递项保持有效，并以逐项结果返回（`server/modules/im-group/src/service.rs:156-206`、`server/modules/im-group/src/repository.rs:376-387`）。
- 数据库集成测试安装临时 PostgreSQL trigger，真实阻断指定 invitee 的 type 4 消息 INSERT，而不是用 mock 模拟。测试验证同一响应内成功项为 pending/true/有效 ID，失败项为 failed/false/null，并验证失败 invitee 没有残留 pending invitation（`server/src/lib.rs:503-578`）。
- 同一测试继续验证成功邀请只持久化一张卡片，且在点击接受前后成员资格按预期变化（`server/src/lib.rs:579-625`）。

结论：API 契约、数据库事实与卡片事实保持一致，部分失败不再被误报为可接受邀请。

### 3. 客户端失败传播：PASS

- `DioGroupRepository.inviteMembers` 逐项检查 `delivered`；响应结构无效或任一项未投递时抛出稳定的 `GroupRequestException('group invitation delivery failed')`（`client/modules/flash_im_group/lib/src/data/group_repository.dart:87-100`）。
- Cubit 将该领域错误映射为“部分群邀请发送失败，请重试”，同时恢复 `isSaving=false`，页面不会显示全量成功提示（`client/modules/flash_im_group/lib/src/logic/group_detail_cubit.dart:67-84,149-160`）。
- Repository 测试使用 `id:null/status:failed/delivered:false` 验证异常契约，Cubit 测试验证中文反馈和保存状态恢复（`client/modules/flash_im_group/test/group_repository_test.dart:41-56,59-81`、`client/modules/flash_im_group/test/group_detail_cubit_test.dart:52-64`）。

结论：失败语义已贯通 HTTP 响应 → Repository → Cubit → UI 反馈，不会再把部分成功显示为全部成功。

### 4. 容量并发保护：PASS

- 接受邀请仍先锁 active group，再检查有效成员数并写入成员，锁顺序没有因响应契约变更而改变（`server/modules/im-group/src/repository.rs:390-497`）。
- 新增真实数据库并发测试构造 199 人群和两个 pending invitation，同时接受两张邀请；测试断言恰好一个成功且最终有效成员数严格为 200（`server/src/lib.rs:764-852`）。

结论：邀请并发不会突破 200 人上限。

## 既有四个 P1 回归复验

1. **外部 type 4 伪造仍被阻断**：WS 用户入口继续只允许 0～3，并保留 type 4 拒绝测试（`server/modules/im-ws/src/dispatcher.rs:40-77,89-110`）。
2. **广播失败不覆盖提交结果**：消息与群成员通知仍使用提交后 best-effort 广播，数据库成功不会被返回成业务失败（`server/modules/im-message/src/service.rs:110-155`、`server/modules/im-group/src/service.rs:93-110,209-224`）。
3. **邀请/消息/广播一致性未回退**：消息、seq、预览、未读数仍在单事务持久化；广播失败不会删除已存在的有效卡片 invitation（`server/modules/im-message/src/repository.rs:27-136`）。本次失败项的 null ID 又补齐了正常持久化失败路径。
4. **解散与发送 TOCTOU 仍关闭**：消息写入继续以 active conversation/member 的 `FOR UPDATE OF c` 为入口，解散使用同一 conversation 行锁（`server/modules/im-message/src/repository.rs:13-45`、`server/modules/im-group/src/repository.rs:500-535`）。

## 依赖与公共边界

- 本次只调整服务端 DTO 的可空性、Service 输出构造和测试；没有新增 crate/package 依赖，也没有形成 Rust crate 反向依赖。
- Flutter 公共 `GroupRepository` 签名保持 `Future<void> inviteMembers(...)`，失败细节继续由领域异常承载，未把服务端 DTO 或 Dio 类型泄漏到 UI。
- `GroupDetailCubit._save` 仍保持 `Future<GroupDetail> Function()` 强类型边界，没有恢复 `dynamic`。
- protobuf 的 type 4 数值与客户端消息映射未变化，现有历史邀请卡片兼容性不受 `GroupInvitationItem.id` 响应可空性影响。

## 非阻塞建议

- P2：客户端当前以 `delivered` 为业务判据，尚未强校验成功项必须同时满足非空 `id` 和 `status=pending`。服务端当前输出恒满足该不变量；后续若引入生成 DTO，可将邀请结果建模为 sealed success/failed，进一步让非法字段组合无法表示。
- attempt 2 已记录的广播可观测性与 outbox 建议仍有效，但本次变更没有扩大相关风险。

## 最终判定

邀请失败契约现已在服务端类型、数据库回收、逐项 API 响应、客户端错误映射和真实失败测试之间闭环；既有权限、事务、解散和消息边界无回退，Architecture Agent attempt 3 判定 **PASS**。
