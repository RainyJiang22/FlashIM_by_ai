# 05 `GET /conversations` 查询会话列表分页

## 基本信息

- 请求方法：`GET`
- 请求链接：`http://127.0.0.1:9600/conversations?limit=5&offset=5`
- 鉴权要求：`Authorization: Bearer <token>`

## 请求参数

| 参数 | 位置 | 必填 | 说明 |
| --- | --- | --- | --- |
| `Authorization` | Header | 是 | 登录态 token |
| `limit` | Query | 否 | 本步骤使用 `5` |
| `offset` | Query | 否 | 本步骤使用 `5`，表示跳过前 5 条 |

请求体：无。

## 响应结果

```json
[
  {
    "id": "<conversation-uuid>",
    "type": 0,
    "name": null,
    "peer_user_id": "8",
    "peer_nickname": "酡颜",
    "peer_avatar": "color:#F9906F",
    "last_message_at": "2026-07-07T06:30:00Z",
    "last_message_preview": "会话模块先不接消息收发。",
    "unread_count": 2,
    "created_at": "2026-07-07T06:30:00Z"
  }
]
```

说明：响应数组长度最多为 `limit`。当剩余数据不足时，返回实际剩余数量；当没有更多数据时，返回空数组。

## 完整 curl

```bash
curl -sS "http://127.0.0.1:9600/conversations?limit=5&offset=5" \
  -H "Authorization: Bearer <jwt-token>"
```
