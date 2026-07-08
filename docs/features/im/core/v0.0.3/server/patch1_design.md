---
module: im-core
version: v0.0.3-patch1
date: 2026-04-03
tags: [消息收发, patch, sender-info, mark-read, total-unread]
---

# IM Core v0.0.3 — 服务端补丁 1

> 基于 v0.0.3 实际联调中发现的问题，补充以下改动。

## 1. ChatMessage 帧新增 sender_name / sender_avatar

### 问题

WebSocket 推送的 ChatMessage 帧不包含发送者昵称和头像，前端收到对方消息后无法显示头像和名字。HTTP 历史消息接口有（MessageWithSender），但实时消息没有。

### 改动

message.proto 的 ChatMessage 新增两个字段：

```protobuf
message ChatMessage {
  ...
  string sender_name = 10;
  string sender_avatar = 11;
}
```

后端 WsBroadcaster 在广播消息时，查询 user_profiles 填入 sender_name 和 sender_avatar。

### 影响文件

- `proto/message.proto`
- `server/modules/im-ws/src/broadcaster.rs`
- `client/modules/flash_im_chat/lib/src/logic/chat_cubit.dart`

---

## 2. ConversationUpdate 帧新增 total_unread

### 问题

前端底部导航需要显示总未读数角标。会话列表有分页，本地求和不完整。

### 改动

message.proto 的 ConversationUpdate 新增字段：

```protobuf
message ConversationUpdate {
  ...
  int32 total_unread = 5;
}
```

后端 WsBroadcaster 在推送会话更新时，为每个接收者查询 `SUM(unread_count)` 填入 total_unread。

WsBroadcaster 新增 PgPool 依赖（用于查询 total_unread）。

### 影响文件

- `proto/message.proto`
- `server/modules/im-ws/src/broadcaster.rs`（新增 db 字段）
- `server/modules/im-ws/Cargo.toml`（新增 sqlx 依赖）
- `server/src/main.rs`（WsBroadcaster::new 传入 db）

---

## 3. 新增 POST /conversations/:id/read 接口

### 问题

前端进入聊天页时本地清零 unread_count，但后端数据未重置。下拉刷新后未读数恢复。

### 改动

im-conversation 新增路由：

```
POST /conversations/:id/read
```

逻辑：将 conversation_members 中当前用户的 unread_count 设为 0。

### 影响文件

- `server/modules/im-conversation/src/routes.rs`（新增 mark_read handler + 路由注册）

---

## 4. 新增 GET /conversations/:id 接口

### 问题

前端会话列表分页加载，未加载到的会话收到 CONVERSATION_UPDATE 时无法更新。前端需要先用帧数据创建骨架会话（preview/time/unread 有值，nickname/avatar 为空），再通过 HTTP 拉取完整信息补全。

### 改动

im-conversation 新增路由：

```
GET /conversations/:id
```

逻辑：验证当前用户是会话成员，返回单个会话的完整信息（关联 user_profiles 补充对方昵称和头像），格式与列表接口中的单条一致。

### 影响文件

- `server/modules/im-conversation/src/routes.rs`（新增 get_conversation handler + 路由注册）
- `server/modules/im-conversation/src/service.rs`（新增 get_by_id 方法）
- `client/modules/flash_im_conversation/lib/src/data/conversation_repository.dart`（新增 getById 方法）
- `client/modules/flash_im_conversation/lib/src/logic/conversation_list_cubit.dart`（_handleUpdate 处理未知会话）
