# 04 `GET /conversations` 查询会话列表第一页

## 基本信息

- 请求方法：`GET`
- 请求链接：`http://127.0.0.1:9600/conversations?limit=20&offset=0`
- 鉴权要求：`Authorization: Bearer <token>`

## 请求参数

| 参数 | 位置 | 必填 | 说明 |
| --- | --- | --- | --- |
| `Authorization` | Header | 是 | 登录态 token |
| `limit` | Query | 否 | 每页数量，默认 `20`，最大 `100` |
| `offset` | Query | 否 | 分页偏移量，默认 `0` |

请求体：无。

## 响应结果

```json
[
  {
    "id": "<conversation-uuid>",
    "type": 0,
    "name": null,
    "peer_user_id": "3",
    "peer_nickname": "胭脂",
    "peer_avatar": "color:#C03F3C",
    "last_message_at": "2026-07-07T08:00:00Z",
    "last_message_preview": "今天的接口联调先看会话列表。",
    "unread_count": 3,
    "created_at": "2026-07-07T08:00:00Z"
  }
]
```

字段说明：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | `string` | 会话 ID，UUID |
| `type` | `number` | 会话类型，当前单聊为 `0` |
| `name` | `string?` | 群聊或命名会话名称，单聊通常为空 |
| `peer_user_id` | `string?` | 单聊对方账号 ID |
| `peer_nickname` | `string?` | 单聊对方昵称 |
| `peer_avatar` | `string?` | 单聊对方头像标记，如 `identicon:*` 或 `color:#RRGGBB` |
| `last_message_at` | `string?` | 最后一条消息时间 |
| `last_message_preview` | `string?` | 最后一条消息摘要 |
| `unread_count` | `number` | 当前用户在该会话下的未读数 |
| `created_at` | `string` | 会话创建时间 |

## 完整 curl

```bash
curl -sS "http://127.0.0.1:9600/conversations?limit=20&offset=0" \
  -H "Authorization: Bearer <jwt-token>"
```
