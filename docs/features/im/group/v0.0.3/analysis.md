# 搜索加群与入群审批 — 功能分析

## 概述

v0.0.2 实现了群聊额外补充功能，但用户只能通过"被邀请"的方式进入群聊。本次补全"主动加入"的链路：用户可以搜索公开群聊、申请入群，群主可以审批入群申请。

核心挑战有两个：一是入群申请的分支逻辑——同一个 `POST /groups/{id}/join` 接口要同时处理"无需验证直接加入"和"需要验证创建申请等待审批"两种场景；二是群主端的实时通知推送——入群申请需要通过 WS 帧实时送达群主，群主处理后结果也要通知申请者。

v0.0.2 已经提供群聊详情、成员列表和 `join_approval_required` 设置。本版复用该字段和既有 `GET /groups/{id}`、`PATCH /groups/{id}/settings` 契约：开关关闭时，成员邀请和主动入群都可直接完成；开关开启时，成员邀请仍走邀请卡片，主动入群则创建待群主审批的申请。

### 已确认范围与实现假设

- 当前数据模型没有群公开/私密字段。本版把所有未解散群视为可搜索群；后续若增加群可见性，再由搜索 SQL 过滤。
- 群号复用会话 UUID；输入完整 UUID 时可精确匹配，否则按群名模糊搜索。
- 入群申请留言可选，去除首尾空格后最多 200 个 Unicode 字符；空值使用默认文案“请求加入群聊”。
- 同一用户对同一群同一时刻只允许一条待处理申请；被拒绝后允许再次申请。
- 关闭入群验证不会自动批准已有待处理申请，仍由群主逐条处理。
- 直接加入和审批同意都遵守现有 200 人上限，并复用成员关系恢复、宫格头像刷新和持久化群系统消息链路。

---

## 一、交互链

### 场景 1：搜索并直接加入群聊（无需验证）

**用户故事**：作为用户，我想搜索并加入一个不需要审批的群聊，以便快速参与群聊讨论。

用户在通讯录 Tab 点击"加好友/群"（原"添加朋友"页面扩展），页面新增"搜索群聊"入口。点击进入 SearchGroupPage，顶部搜索栏输入关键词，300ms 防抖触发远程搜索，搜索结果展示匹配的群聊列表（群头像 + 群名 + 成员数 + 群号）。已加入的群显示"已加入"灰色标签，不可点击。未加入且无需验证的群显示"加入"蓝色按钮。点击"加入"后弹出确认对话框，确认后直接加入成功，Toast 提示"已成功加入群聊"，搜索结果中该群状态变为"已加入"。

```mermaid
flowchart LR
    A[加好友/群页面] --> B[点击搜索群聊]
    B --> C[输入关键词搜索]
    C --> D[看到搜索结果]
    D --> E[点击加入]
    E --> F[确认对话框]
    F --> G[直接加入成功]
```

### 场景 2：搜索并申请加入群聊（需验证）

**用户故事**：作为用户，我想申请加入一个需要审批的群聊，以便群主审核后我能参与讨论。

操作路径和场景 1 类似，但需要验证的群显示"申请"橙色按钮。点击后弹出对话框，包含一个可选的留言输入框（默认文案"请求加入群聊"）。点击"发送申请"后 Toast 提示"申请已发送，等待群主审批"，搜索结果中该群按钮变为"已申请"灰色标签。

```mermaid
flowchart LR
    A[加好友/群页面] --> B[点击搜索群聊]
    B --> C[输入关键词搜索]
    C --> D[看到搜索结果]
    D --> E[点击申请]
    E --> F[输入留言]
    F --> G[发送申请]
    G --> H[等待群主审批]
```

### 场景 3：群主处理入群申请

**用户故事**：作为群主，我想审批入群申请，以便控制谁能加入我的群。

群主收到 WS 推送的入群申请通知（GROUP_JOIN_REQUEST 帧），通讯录 Tab 的"群通知"入口显示红点角标（未处理数量）。点击进入群通知页面，看到申请列表：每条显示申请者头像、昵称、申请加入的群名、留言内容。每条申请右侧有"拒绝"和"同意"两个按钮。点击"同意"后该条状态变为"已同意"，申请者自动加入群聊（群头像刷新）。点击"拒绝"则状态变为"已拒绝"。已处理的申请不再显示操作按钮。

```mermaid
flowchart LR
    A[收到入群通知] --> B[通讯录红点角标]
    B --> C[点击群通知入口]
    C --> D[查看申请列表]
    D --> E{同意或拒绝}
    E -->|同意| F[申请者加入群聊]
    E -->|拒绝| G[申请被驳回]
```

### 场景 4：查看群详情与切换入群验证

**用户故事**：作为群主，我想查看群成员列表并控制入群验证开关，以便管理谁能加入我的群。

用户在群聊 ChatPage 右上角点击群图标，进入群聊详情页。页面展示群名、群号、群头像、成员列表（头像 + 昵称网格）。如果当前用户是群主，底部显示"入群验证"开关（Switch），可切换开启/关闭。切换后即时生效，Toast 提示"已开启入群验证"或"已关闭入群验证"。

```mermaid
flowchart LR
    A[群聊页右上角] --> B[进入群详情页]
    B --> C[查看成员列表]
    B --> D[群主切换入群验证开关]
    D --> E[即时生效]
```

---

## 二、逻辑树

### 事件流：搜索群聊

| 时刻 | 事件 | 处理 | 产生的新事件 |
|------|------|------|-------------|
| T1 | 用户输入关键词 | 前端 300ms 防抖后 `GET /groups/search?keyword=xxx` | HTTP 请求 |
| T2 | 后端搜索 | `WHERE c.type = 1 AND c.is_dissolved = FALSE`，完整 UUID 精确匹配群号，否则按群名 `ILIKE`；关联查 member_count、当前用户 is_member、`conversations.join_approval_required` | 返回 GroupSearchResult 列表 |
| T3 | 前端渲染 | 根据 is_member / join_approval_required / has_pending_request 决定按钮状态：已加入 / 加入 / 申请 / 已申请 | 搜索结果展示 |

搜索结果中每个群的按钮状态由三个字段决定：

| is_member | has_pending_request | join_approval_required | 按钮状态 |
|-----------|--------------------|--------------------|---------|
| true | — | — | "已加入"（灰色，不可点击） |
| false | true | — | "已申请"（灰色，不可点击） |
| false | false | false | "加入"（蓝色） |
| false | false | true | "申请"（橙色） |

### 事件流：申请入群

| 时刻 | 事件 | 处理 | 产生的新事件 |
|------|------|------|-------------|
| T1 | 用户点击"加入"或"申请" | 前端 `POST /groups/{id}/join`，body: `{ message? }` | HTTP 请求 |
| T2 | 后端事务校验 | 锁定未解散群，校验用户非成员、成员数未满 200；需审批时再校验无待处理申请 | — |
| T3a | 无需验证（join_approval_required=false） | 恢复或插入 conversation_members + 刷新宫格头像 + 持久化“XXX 加入了群聊”系统消息 → 返回 `{ auto_approved: true, request_id: null }` | 用户立即加入 |
| T3b | 需要验证（join_approval_required=true） | INSERT group_join_requests（status=0）→ 返回 `{ auto_approved: false, request_id }` | 申请已创建 |
| T4 | 需审批时 | 后端通过 WS 推送 GROUP_JOIN_REQUEST 帧给群主 | 群主收到通知 |

```mermaid
sequenceDiagram
    participant U as 用户
    participant FE as 前端
    participant API as im-group
    participant DB as PostgreSQL
    participant WS as MessageDispatcher

    U->>FE: 点击加入/申请
    FE->>API: POST /groups/id/join
    API->>DB: 校验群存在 + 非成员 + 无待处理申请
    API->>DB: 锁定 conversations 并读取 join_approval_required

    alt 无需验证
        API->>DB: INSERT conversation_members
        API->>DB: 刷新宫格头像
        API-->>FE: auto_approved true
        FE->>U: 已成功加入群聊
    else 需要验证
        API->>DB: INSERT group_join_requests
        API-->>FE: auto_approved false
        API->>WS: GROUP_JOIN_REQUEST 帧推送群主
        FE->>U: 申请已发送
    end
```

### 事件流：群主处理入群申请

| 时刻 | 事件 | 处理 | 产生的新事件 |
|------|------|------|-------------|
| T1 | 群主点击"同意"或"拒绝" | 前端 `POST /groups/{id}/join-requests/{rid}/handle`，body: `{ approved: bool }` | HTTP 请求 |
| T2 | 后端事务校验 | 锁定群与申请，校验当前用户是群主、申请属于该群且 status=0；同意时再次校验 200 人上限 | — |
| T3a | 同意 | UPDATE status=1 + 恢复或 INSERT conversation_members + 刷新宫格头像；提交后持久化系统消息并推送处理结果 | 申请者加入群聊 |
| T3b | 拒绝 | UPDATE status=2；提交后推送处理结果 | 申请被驳回 |

### 事件流：群主查询入群通知

| 时刻 | 事件 | 处理 | 产生的新事件 |
|------|------|------|-------------|
| T1 | 群主进入群通知页 | 前端 `GET /groups/join-requests` | HTTP 请求 |
| T2 | 后端查询 | 查当前用户作为群主的所有群的入群申请，关联查申请者昵称/头像、群名 | 返回 JoinRequestItem 列表 |

### 状态流转

| 实体 | 触发事件 | 前状态 | 后状态 |
|------|---------|--------|--------|
| GroupJoinRequest | POST /join（需审批） | 不存在 | status=0（待处理） |
| GroupJoinRequest | 群主同意 | status=0 | status=1（已同意） |
| GroupJoinRequest | 群主拒绝 | status=0 | status=2（已拒绝） |
| ConversationMember | 直接加入 / 群主同意 | 不存在 | joined（is_deleted=false） |
| ConversationMember | 直接加入 / 群主同意 | is_deleted=true | joined（is_deleted=false） |
| conversations.avatar | 新成员加入 | grid:旧头像列表 | grid:新头像列表（刷新） |

**异常回退**：
- 重复申请：后端返回 400"已有待处理的入群申请"
- 已是成员：后端返回 400"已经是群成员"
- 非群主审批：后端返回 403"只有群主可以处理入群申请"
- 申请已处理：后端返回 400"该申请已处理"
- 群已解散或不存在：后端返回 404"group not found"
- 群成员已满：后端返回 409"group member limit reached"
- 非法留言（超过 200 字符）：后端返回 400"invalid join request message"
- 并发重复申请：数据库待处理唯一索引兜底，返回稳定的 409 冲突，不产生两条待处理记录

---

## 三、功能编号与网络定位

### 本次新增节点

| 编号 | 功能节点 | 层级 | 简介 |
|------|---------|------|------|
| D-19 | 群搜索 | 领域 | GET /groups/search，按群名模糊搜索或群号精确匹配，返回成员数/是否已加入/是否需验证/是否已申请 |
| D-20 | 入群申请 | 领域 | POST /groups/{id}/join，无需验证直接加入，需验证创建申请 + WS 通知群主 |
| D-21 | 入群审批 | 领域 | POST /groups/{id}/join-requests/{rid}/handle，群主同意或拒绝 |
| D-22 | 入群通知查询 | 领域 | GET /groups/join-requests，聚合当前用户作为群主的所有入群申请 |
| F-10 | 群通知 WS 帧分发 | 前端基础 | WsClient 新增 GROUP_JOIN_REQUEST 帧类型，groupJoinRequestStream 分发 |
| P-34 | 群搜索与入群 | 前端业务 | SearchGroupPage，独立搜索群聊页：远程搜索 + 四种按钮状态 + 入群对话框 |
| P-35 | 群通知页 | 前端业务 | GroupNotificationsPage，群主查看和处理入群申请列表 |
| P-36 | 群通知角标 | 前端业务 | GroupNotificationCubit 管理 pendingCount，驱动通讯录 Tab 红点 |
| D-23 | 既有群设置复用 | 领域 | 复用 GET /groups/{id} 与 PATCH /groups/{id}/settings，使 join_approval_required 同时约束成员邀请和主动入群 |
| P-37 | 既有群详情文案扩展 | 前端业务 | 复用 GroupDetailsPage，仅补充主动入群审批语义，不重复创建详情页 |

### 前置依赖

| 依赖节点 | 依赖方式 | 是否已有 |
|----------|---------|---------|
| D-18 群聊创建 | 共享数据（conversations.join_approval_required 字段） | ✅ 已有 |
| D-02 会话列表查询 | 扩展（搜索结果需要 member_count） | ✅ 已有 |
| I-08 在线用户管理 | 调接口（WS 推送入群通知给群主） | ✅ 已有 |
| I-09 帧分发器 | 扩展（新增 GROUP_JOIN_REQUEST 帧处理） | ✅ 需扩展 |
| F-06 WsClient 帧分发 | 扩展（新增 groupJoinRequestStream） | ✅ 需扩展 |
| P-25 添加朋友页 | 扩展（新增"搜索群聊"入口，页面标题改为"加好友/群"） | ✅ 需扩展 |

### 边界接口

| 接口/协议 | 定义方 | 消费方 | 说明 |
|-----------|--------|--------|------|
| GET /groups/search?keyword= | D-19 | P-34 | 新增接口 |
| POST /groups/{id}/join | D-20 | P-34 | 新增接口 |
| POST /groups/{id}/join-requests/{rid}/handle | D-21 | P-35 | 新增接口 |
| GET /groups/join-requests | D-22 | P-35 | 新增接口 |
| GROUP_JOIN_REQUEST（WS 帧） | D-20 | F-10 → P-36 | 新增帧类型 |
| GroupJoinRequestNotification（Protobuf） | D-20 | F-10 | 新增 proto 消息 |
| group_join_requests 表 | D-20 | D-21, D-22 | 新增数据库表 |
| GET /groups/{id} | D-23 | P-37 | 复用既有接口 |
| PATCH /groups/{id}/settings | D-23 | P-37 | 复用既有接口，语义扩展 |

---

## 四、结论

- **开发顺序**：数据库迁移（group_join_requests 表）→ Protobuf 定义（GROUP_JOIN_REQUEST 帧 + GroupJoinRequestNotification 消息）→ D-19 群搜索 → D-20 入群申请 → D-21 入群审批 → D-22 入群通知查询 → 服务端 API/WS 链路验证 → F-10 WS 帧分发扩展 → P-34 群搜索与入群 → P-35 群通知页 → P-36 群通知角标 → P-37 既有详情语义扩展
- **复杂度集中点**：
  - D-20 入群申请的分支逻辑——同一个接口要处理"直接加入"和"创建申请等待审批"两种场景，且需要验证时还要触发 WS 推送
  - P-34 搜索结果的四种按钮状态（已加入/加入/申请/已申请）+ 300ms 防抖 + 入群确认/申请对话框
  - P-36 群通知角标的实时更新——WS 推送驱动 pendingCount 变化，需要和 HTTP 查询的初始值协调
- **和 v0.0.2 的关系**：所有新增群领域接口放在 `im-group` crate 中；前端模型、状态与页面放在 `flash_im_group`。复用既有群详情、群成员、群头像和消息链，不另建 group_info 或详情模块。
- **暂不实现**：群公开/私密开关、申请者撤回、群主批量审批、管理员代审、入群问题、黑名单、二维码/邀请链接搜索、历史已处理申请分页、离线推送和系统通知中心。
