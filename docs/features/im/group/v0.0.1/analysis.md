# 群聊 — 创建与加入 — 功能分析

## 概述

本次实现群聊的最小可用版本，覆盖四条链路：创建群聊（选人建群）、从单聊发起新群聊（聊天详情页邀请第三者）、查看自己的群聊列表、群聊消息收发。

当前系统已有完整的单聊链路和好友体系。数据库 `conversations` 表已预留 `type=1`、`name`/`avatar`/`owner_id` 字段，`conversation_members` 天然支持多成员，消息发送链路（`MessageService.send` → 验证成员 → seq → 存储 → 广播）已是多成员兼容的，`ChatMessage` protobuf 已有 `sender_name`/`sender_avatar` 字段，客户端消息气泡也已展示他人昵称和头像。本次不修改消息协议和消息收发代码，只补齐群会话的创建、查询与入口 UI。

---

## 一、交互链

### 场景 1：创建群聊

**用户故事**：作为用户，我想从好友中选人创建群聊，以便和多个人同时沟通。

用户在消息 Tab 右上角点击"+"按钮，选择"发起群聊"，进入选择联系人页面。页面顶部是搜索框，下方是按字母分组的好友列表。用户勾选至少 2 个好友，已选的人以头像横条显示在搜索框下方（点击可取消）。右上角显示"完成(N)"。点击完成，群名由前端自动拼接（≤3 人用顿号连接，>3 人取前三 + "等"），调用 `POST /conversations`（type=group），成功后跳转到群聊 ChatPage。

```mermaid
flowchart LR
    A[点击 + 按钮] --> B[进入选择联系人页]
    B --> C[勾选好友 ≥ 2 人]
    C --> D[点击完成]
    D --> E[自动拼接群名]
    E --> F[跳转到群聊页面]
```

### 场景 2：从单聊发起群聊

**用户故事**：作为用户，我正在和某人单聊，想拉更多人进来一起聊。

用户在单聊 ChatPage 右上角点击"..."按钮，进入聊天详情页。详情页显示当前聊天对象的头像和昵称，下方有"邀请更多人"（"+"按钮）。点击后进入选择联系人页，当前聊天对象已预选中（勾选状态，不可取消）。用户再勾选至少 1 个其他好友，点击完成。群名自动拼接，创建成功后跳转到新的群聊 ChatPage。

```mermaid
flowchart LR
    A[单聊页点击 ...] --> B[进入聊天详情页]
    B --> C[点击 + 邀请更多人]
    C --> D[进入选择联系人页]
    D --> E[对方已预选中]
    E --> F[再选 ≥ 1 人 + 点击完成]
    F --> G[自动拼接群名]
    G --> H[跳转到群聊页面]
```

### 场景 3：查看我的群聊

**用户故事**：作为用户，我想查看自己加入的所有群聊，以便快速找到并进入某个群。

用户在通讯录 Tab 点击"群聊"入口，进入我的群聊页面。页面顶部是搜索栏，下方展示已加入的群聊列表（成员组合头像 + 群名）。输入关键词可本地过滤群名。点击某个群聊直接进入 ChatPage。

```mermaid
flowchart LR
    A[通讯录点击群聊] --> B[进入我的群聊页]
    B --> C[看到已加入的群聊列表]
    C --> D[输入关键词过滤]
    D --> E[点击群聊]
    E --> F[进入聊天页]
```

### 场景 4：群聊消息收发

**用户故事**：作为群成员，我想在群聊中发送和接收消息。

用户从会话列表点击群聊会话（type=1），进入聊天页面。标题显示群名称。他人消息左侧显示发送者头像，气泡上方显示发送者昵称。自己的消息靠右，不显示昵称头像。发送流程与单聊完全一致（乐观更新 → WS 发送 → ACK 确认）。

```mermaid
flowchart LR
    A[点击群聊会话] --> B[进入聊天页]
    B --> C[看到历史消息+发送者昵称头像]
    C --> D[输入并发送消息]
    D --> E[乐观显示 → ACK 确认]
```

---

## 二、逻辑树

### 事件流：创建群聊

| 时刻 | 事件 | 处理 | 产生的新事件 |
|------|------|------|-------------|
| T1 | 用户点击"完成" | 前端 `POST /conversations`，body: `{ type: "group", name, member_ids }` | HTTP 请求到达后端 |
| T2 | 后端收到请求 | 校验：群名非空、邀请好友数 ≥ 2 且 ≤ 199、成员 ID 去重且都与群主存在好友关系。事务内插入 conversations（type=1, name, owner_id）并批量插入群主与成员 | 群聊创建成功 |
| T3 | 返回响应 | 按现有会话详情结构返回 Conversation，并补充 owner_id、群成员头像列表 | 前端收到响应 |
| T4 | 前端处理 | 刷新会话列表并跳转 ChatPage | 页面跳转 |

```mermaid
sequenceDiagram
    participant U as 用户
    participant FE as 前端
    participant API as conversation_routes
    participant SVC as ConversationService
    participant DB as PostgreSQL

    U->>FE: T1 选人 + 点击完成
    FE->>API: POST /conversations {type:"group", name, member_ids}
    API->>SVC: T2 create_group(owner_id, name, member_ids)
    SVC->>DB: 校验好友关系
    SVC->>DB: 事务：INSERT conversations + members
    SVC-->>API: Conversation
    API-->>FE: T3 200 {id, type, name, owner_id, member_avatars...}
    FE->>U: T4 刷新列表并跳转群聊 ChatPage
```

### 事件流：从单聊发起群聊

| 时刻 | 事件 | 处理 | 产生的新事件 |
|------|------|------|-------------|
| T1 | 用户在单聊页点击"..." | 前端跳转到聊天详情页，传入 conversation 信息（peerUserId, peerNickname, peerAvatar） | 详情页展示 |
| T2 | 用户点击"+"邀请更多人 | 前端跳转到创建群聊页，`initialSelectedIds = { peerUserId }`，预选中且不可取消 | 创建群聊页展示 |
| T3 | 用户选人+点击完成 | 同"创建群聊"事件流 T1~T4，member_ids 包含预选的 peerUserId + 新选的好友 | 群聊创建成功，跳转 ChatPage |

```mermaid
sequenceDiagram
    participant U as 用户
    participant Chat as ChatPage
    participant Info as 聊天详情页
    participant CG as 创建群聊页
    participant API as 后端

    U->>Chat: T1 点击 "..."
    Chat->>Info: push 聊天详情页
    U->>Info: T2 点击 "+"
    Info->>CG: push 创建群聊页（对方预选中）
    U->>CG: T3 再选好友 + 点击完成
    CG-->>API: POST /conversations（同创建群聊 T1~T5）
    API-->>CG: Conversation
    CG->>U: 跳转群聊 ChatPage
```

### 事件流：群聊消息（复用现有链路，无改动）

| 时刻 | 事件 | 处理 | 产生的新事件 |
|------|------|------|-------------|
| T1 | 用户发送消息 | 前端乐观插入 → WS `SendMessageRequest` | 帧到达后端 |
| T2 | dispatcher → MessageService.send | 验证成员 → seq → 存储 → 更新 preview/time → unread+1 | 消息持久化 |
| T3 | 广播 | ChatMessage 帧（含 sender_name/sender_avatar）→ 除发送者外的在线成员；ConversationUpdate 帧 → 所有成员；MessageAck → 发送者 | 各端收到推送 |

```mermaid
sequenceDiagram
    participant U as 用户
    participant FE as 前端
    participant WS as WebSocket
    participant SVC as MessageService
    participant DB as PostgreSQL

    U->>FE: T1 输入并发送
    FE->>FE: 乐观插入本地消息
    FE->>WS: SendMessageRequest 帧
    WS->>SVC: T2 验证成员 → seq → 存储
    SVC->>DB: INSERT messages + UPDATE conversations
    SVC->>WS: T3 广播 ChatMessage → 其他成员
    WS->>FE: MessageAck → 发送者
    FE->>U: sending → sent
```

### 状态流转

| 实体 | 触发事件 | 前状态 | 后状态 |
|------|---------|--------|--------|
| Conversation | POST /conversations (type=group) | 不存在 | type=1, name, owner_id；响应含成员头像列表 |
| ConversationMember | 创建群聊 | 不存在 | joined (unread=0, is_deleted=false) |
| 本地消息 | 发送 → ACK | sending | sent |
| 本地消息 | 12s 超时 | sending | failed |

### 异常流与回退

| 异常 | 触发条件 | 用户反馈 | 系统回退 |
| --- | --- | --- | --- |
| 选人不足 | 直接创建少于 2 位好友，或单聊入口未再选择其他好友 | “至少选择 2 位好友” | 不发请求，保留当前选择 |
| 成员非法 | 成员重复、包含自己、成员不存在或已不是好友 | “群成员无效，请刷新好友列表后重试” | 服务端不写入任何会话数据 |
| 群名非法 | 自动群名为空或超过 100 字 | “群名称不合法” | 服务端不写入任何会话数据 |
| 创建失败 | 网络失败或事务失败 | “群聊创建失败，请稍后重试” | 事务回滚，页面保留选择以便重试 |
| 群列表加载失败 | `GET /conversations?type=1` 失败 | 错误页与重试按钮 | 保留在我的群聊页 |
| 消息发送失败 | 12 秒未收到 ACK | 现有失败态 | 复用现有消息重试行为 |

---

## 三、功能编号与网络定位

### 本次新增节点

| 编号 | 功能节点 | 层级 | 简介 |
|------|---------|------|------|
| D-18 | 群聊创建 | 领域 | 扩展 POST /conversations 支持 type=group，校验好友关系并事务创建群与成员 |
| D-19 | 我的群聊查询 | 领域 | 扩展 GET /conversations 支持 type=1 过滤，并返回群 owner 与成员头像 |
| P-28 | 创建群聊页 | 前端业务 | 微信风格选人页：已选头像横条 + FlashSearchBar + 字母索引分组 + 自动拼接群名 |
| P-29 | 我的群聊页 | 前端业务 | 通讯录"群聊"入口 → 已加入群聊列表 + 本地过滤搜索 |
| P-31 | 单聊详情页 | 前端业务 | 显示对方信息 + "+"邀请更多人入口，跳转创建群聊页并预选对方 |
| P-33 | 群聊会话展示 | 前端业务 | 群聊显示群名称，并根据成员头像列表绘制组合头像 |

### 前置依赖

| 依赖节点 | 依赖方式 | 是否已有 |
|----------|---------|---------|
| D-01 会话创建 | 扩展（新增 group 分支） | ✅ 需扩展 |
| D-06~D-10 消息链路 | 调接口（完全复用） | ✅ 已有 |
| D-15 好友关系管理 | 共享数据（创建群聊页复用好友列表） | ✅ 已有 |
| P-06~P-09 聊天页 | 直接复用消息展示与发送链路，仅增加单聊详情入口 | ✅ 已有 |
| P-01 会话列表 | 扩展（群聊显示适配） | ✅ 需扩展 |
| P-20 好友列表页 | 共享数据 | ✅ 已有 |

### 边界接口

| 接口/协议 | 定义方 | 消费方 | 说明 |
|-----------|--------|--------|------|
| POST /conversations (type=group) | D-18 | P-28 | 扩展现有接口 |
| GET /conversations?type=1 | D-19 | P-29 | 扩展现有接口，按会话类型过滤 |
| Conversation.owner_id | D-18/D-19 | P-28/P-29 | 群主标识；私聊为空 |
| Conversation.member_avatars | D-18/D-19 | P-29/P-33 | 群成员头像列表；客户端绘制组合头像 |

---

## 四、结论

- **开发顺序**：优先完成 D-18/D-19 服务端创建与查询、服务端单元和 API 链路测试；通过后再实现 P-28/P-29/P-31/P-33 客户端页面与测试。
- **复杂度集中点**：D-18 的成员去重、好友关系校验和事务原子性；P-28 的固定预选成员、最小人数校验与失败后状态保留。
- **暂不实现**：向已有群聊继续加人、退群/解散、群管理、群公告、群昵称、入群验证、自定义群头像、系统消息。单聊详情的“拉人”语义是创建一个新群聊，不修改原私聊，也不向已有群加人。
