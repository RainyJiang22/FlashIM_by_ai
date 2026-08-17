# 群聊详情与成员邀请 — 服务端任务清单

基于 [design.md](./design.md) 实现 `im-group` v0.0.2。

全局约束：

- 保留 v0.0.1 的群创建和群消息行为，不修改私聊、好友申请和媒体消息契约。
- 群管理规则集中在新 `im-group` crate；`im-conversation` 不依赖 `im-group`。
- 所有成员写操作以服务端好友关系、当前成员状态和 200 人上限为准。
- 解散使用软解散与成员软删除，不级联删除消息。
- 不实现拒绝邀请、转让群主、成员主动退群、管理员、群公告或邀请链接。
- 不执行 Gradle/Xcode；服务端只运行 Rust、SQL/API 链路和 Harness 验证。

---

## 执行顺序

1. ✅ 任务 1 — 新增群管理迁移（无依赖）
2. ✅ 任务 2 — 创建 `im-group` crate 并加入 workspace（依赖任务 1）
3. ✅ 任务 3 — 定义群详情、成员、邀请和请求 DTO（依赖任务 2）
4. ✅ 任务 4 — 实现群查询、成员、邀请和解散事务（依赖任务 3）
5. ✅ 任务 5 — 实现权限矩阵与邀请消息编排（依赖任务 4）
6. ✅ 任务 6 — 注册群管理 REST 路由（依赖任务 5）
7. ✅ 任务 7 — 通用会话链路排除已解散群（依赖任务 1）
8. ✅ 任务 8 — 扩展群邀请消息类型与预览（依赖任务 3）
9. ✅ 任务 9 — 宿主注入 WS broadcaster 并合并路由（依赖任务 6、8）
10. 🟨 任务 10 — 服务端单元、路由、数据库与 API 链路测试（依赖任务 1-9）
11. ✅ 最后 — 服务端 Harness Check：格式、测试、新鲜覆盖率 ≥80%、Clippy（依赖任务 1-10）

---

## 任务 1：群管理数据库迁移 `✅ 已完成`

文件：`server/migrations/20260817000100_group_management.sql`

改动类型：`新建文件`

### 1.1 扩展群状态 `✅`

为 `conversations` 增加 `join_approval_required`、`is_dissolved`、`dissolved_at`，默认不改变旧群行为。

### 1.2 新增邀请表与唯一索引 `✅`

创建 `group_invitations`，状态仅允许 pending/accepted，并为同群同被邀请人的 pending 邀请建立部分唯一索引。

## 任务 2：`im-group` crate 与 workspace 配置 `✅ 已完成`

文件：

- `server/modules/im-group/Cargo.toml`
- `server/modules/im-group/src/lib.rs`
- `server/Cargo.toml`

改动类型：`新建 + 配置`

### 2.1 声明依赖 `✅`

依赖 axum、serde、serde_json、sqlx、uuid、chrono、flash_core、im-conversation、im-message；broadcaster 使用 trait 泛型，crate 不反向依赖宿主。

### 2.2 加入 workspace `✅`

增加 `modules/im-group` workspace member 和根 package dependency。

## 任务 3：群领域 DTO `✅ 已完成`

文件：`server/modules/im-group/src/models.rs`

改动类型：`新建文件`

### 3.1 定义数据库行与响应 `✅`

```rust
pub struct GroupSummaryRow { id, name, owner_id, join_approval_required }
pub struct GroupMemberRow { account_id, nickname, avatar, joined_at }
pub struct GroupDetail { conversation_id, name, owner_id, join_approval_required, current_user_role, member_count, members }
pub struct GroupInvitationRow { id, conversation_id, inviter_id, invitee_id, status }
```

### 3.2 定义请求 DTO `✅`

```rust
pub struct UpdateGroupNameBody { pub name: String }
pub struct UpdateGroupSettingsBody { pub join_approval_required: bool }
pub struct GroupMemberIdsBody { pub member_ids: Vec<i64> }
```

## 任务 4：群 Repository 与事务 `✅ 已完成`

文件：`server/modules/im-group/src/repository.rs`

改动类型：`新建文件`

### 4.1 查询群详情和完整成员 `✅`

只返回 `type=1 AND is_dissolved=false` 且当前用户是有效成员的群；成员关联 `user_profiles` 并按 owner 优先、joined_at 排序。

### 4.2 校验好友和成员集合 `✅`

提供批量好友计数、有效成员计数、候选成员冲突检查，避免逐用户查询。

### 4.3 直接添加与删除成员事务 `✅`

批量 `INSERT ... ON CONFLICT DO UPDATE SET is_deleted=FALSE`；删除只允许非 owner 成员。

### 4.4 邀请创建与接受事务 `✅`

创建 pending 邀请并返回 created/existing；接受时 `FOR UPDATE` 锁邀请和群，原子写成员与 accepted 状态。

### 4.5 解散群事务 `✅`

锁 active 群、校验 owner，更新 dissolved 字段、软删除全部成员并删除 pending 邀请后提交。

## 任务 5：群 Service 与权限编排 `✅ 已完成`

文件：`server/modules/im-group/src/service.rs`

改动类型：`新建文件`

### 5.1 规范化输入和权限矩阵 `✅`

校验群名 1～100 字、成员 ID 非空/去重/不含自己、添加后不超过 200；owner 可直加，普通成员仅在 `join_approval_required=false` 时直加。

### 5.2 编排群资料和成员管理 `✅`

实现 `get_detail/update_name/update_settings/add_members/remove_member/dissolve_group`，成功写操作返回最新快照。

### 5.3 编排邀请卡片 `✅`

普通成员在需确认时创建邀请，调用 `ConversationMessageService.create_or_get_private`，再调用 `MessageService.send(type=4)` 持久化并广播卡片。

### 5.4 接受邀请与新会话推送 `✅`

接受成功返回群 `ConversationListItem`，并通过 broadcaster 向新成员推送会话更新以触发客户端 hydrate。

## 任务 6：群 REST 路由 `✅ 已完成`

文件：

- `server/modules/im-group/src/routes.rs`
- `server/modules/im-group/src/lib.rs`

改动类型：`新建 + 修改`

### 6.1 注册群详情和管理接口 `✅`

实现 GET detail、PATCH name/settings、POST members/invitations、DELETE member/group 和 POST accept invitation；统一使用 JWT `extract_user_id`。

### 6.2 暴露 broadcaster 泛型 router `✅`

```rust
pub fn router_with_broadcaster<B>(broadcaster: Arc<B>) -> Router<SharedContext>
where B: MessageBroadcaster + 'static;
```

## 任务 7：通用会话排除已解散群 `✅ 已完成`

文件：

- `server/modules/im-conversation/src/repository.rs`
- `server/modules/im-conversation/src/service.rs`

改动类型：`修改文件`

### 7.1 查询与成员权限过滤 `✅`

列表、详情、`is_member/get_member_ids` 均排除 `c.is_dissolved=true`。

### 7.2 公开群接受后查询入口 `✅`

提供在接受邀请后按新成员视角返回 `ConversationListItem` 的稳定 service 方法，避免 `im-group` 复制通用会话映射。

## 任务 8：群邀请消息类型 `✅ 已完成`

文件：

- `proto/message.proto`
- `server/modules/im-message/src/service.rs`

改动类型：`修改文件`

### 8.1 新增 `GROUP_INVITATION=4` `✅`

协议只新增枚举值，不改变现有字段编号。

### 8.2 校验 extra 和会话预览 `✅`

type=4 必须包含 invitation_id/group_id/group_name/inviter_name；预览固定为 `[群聊邀请]`。

## 任务 9：宿主路由接线 `✅ 已完成`

文件：`server/src/routes/mod.rs`

改动类型：`修改文件`

### 9.1 注入同一 WS broadcaster `✅`

使用 `shared_ws_state()` 和 PostgreSQL pool 构造 broadcaster，合并 `im-group` router。

## 任务 10：服务端测试与 API 链路 `🟨 部分完成`

文件：

- `server/modules/im-group/src/models.rs`
- `server/modules/im-group/src/repository.rs`
- `server/modules/im-group/src/service.rs`
- `server/src/lib.rs`
- `docs/features/im/group/v0.0.2/api/group_management/request/group_management.py`
- `docs/features/im/group/v0.0.2/api/group_management/doc/`

改动类型：`新增 + 修改测试`

### 10.1 单元和 SQL 约束测试 `✅`

覆盖权限矩阵、输入边界、SQL active-group 过滤、owner 保护、pending 唯一、接受事务和软解散。

### 10.2 路由鉴权与数据库 round-trip `✅`

覆盖群详情、改名、设置、直加、邀请卡片、同意入群、踢人和解散后不可访问/发消息。

### 10.3 API 链路与中文文档 `🟨 待执行`

脚本与 13 步中文文档索引已完成；当前本地 `9600` 端口被旧服务占用，未中断用户进程。群详情、改名、验证权限、邀请/同意、删人和解散已通过宿主真实 PostgreSQL 路由 round-trip 测试。

生成正常/错误场景链路和接口文档；真实环境不可用时保留可执行脚本并记录阻塞。

## 最后：服务端 Harness Check `✅ 已完成`

```bash
cd server && cargo fmt --check
cd server && cargo test -p im-group
cd server && cargo test -p im-conversation -p im-message
cd server && cargo llvm-cov --workspace --lcov --output-path <attempt>/server.lcov
cd server && cargo clippy -p im-group -p im-conversation -p im-message --all-targets -- -D warnings
```

使用新 attempt 目录记录变更生产代码、新鲜覆盖率、测试与 Clippy 输出；本次变更生产代码覆盖率必须不低于 80%。
