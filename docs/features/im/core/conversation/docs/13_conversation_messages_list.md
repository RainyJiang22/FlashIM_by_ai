# 13 `GET /conversations/{id}/messages` 查询历史消息

## 基本信息

- 请求方法：`GET`
- 请求链接：`http://127.0.0.1:9600/conversations/<conversation-uuid>/messages?limit=10`
- 鉴权要求：`Authorization: Bearer <token>`

## 请求参数

| 参数 | 位置 | 必填 | 说明 |
| --- | --- | --- | --- |
| `Authorization` | Header | 是 | 登录态 token |
| `id` | Path | 是 | 会话 ID |
| `limit` | Query | 否 | 返回数量，默认 `50`，最大 `100` |

请求体：无。

## 响应结果

```json
[
  {
    "id": "<message-uuid>",
    "conversation_id": "<conversation-uuid>",
    "sender_id": "2",
    "sender_name": "Rainy",
    "sender_avatar": "identicon:2",
    "seq": 1,
    "msg_type": 0,
    "content": "hello",
    "extra": null,
    "status": 0,
    "created_at": "2026-07-07T08:00:00Z"
  }
]
```

说明：响应数组按当前后端查询结果返回；客户端可使用 `seq` 和 `before_seq` 做历史分页。

## 完整 curl

```bash
curl -sS "http://127.0.0.1:9600/conversations/<conversation-uuid>/messages?limit=10" \
  -H "Authorization: Bearer <jwt-token>"
```
