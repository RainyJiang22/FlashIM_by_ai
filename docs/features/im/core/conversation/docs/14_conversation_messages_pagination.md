# 14 `GET /conversations/{id}/messages` 历史消息分页

## 基本信息

- 请求方法：`GET`
- 请求链接：`http://127.0.0.1:9600/conversations/<conversation-uuid>/messages?before_seq=999999&limit=5`
- 鉴权要求：`Authorization: Bearer <token>`

## 请求参数

| 参数 | 位置 | 必填 | 说明 |
| --- | --- | --- | --- |
| `Authorization` | Header | 是 | 登录态 token |
| `id` | Path | 是 | 会话 ID |
| `before_seq` | Query | 否 | 只返回 `seq < before_seq` 的消息 |
| `limit` | Query | 否 | 本步骤使用 `5` |

请求体：无。

## 响应结果

```json
[
  {
    "id": "<message-uuid>",
    "conversation_id": "<conversation-uuid>",
    "seq": 1,
    "content": "hello"
  }
]
```

说明：当没有历史消息时返回空数组；当剩余消息不足 `limit` 时返回实际剩余数量。

## 完整 curl

```bash
curl -sS "http://127.0.0.1:9600/conversations/<conversation-uuid>/messages?before_seq=999999&limit=5" \
  -H "Authorization: Bearer <jwt-token>"
```
