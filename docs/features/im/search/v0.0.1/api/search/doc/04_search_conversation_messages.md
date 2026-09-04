# GET /conversations/{id}/messages/search?q=<keyword>

在当前用户可读的指定会话内搜索普通消息。

## Parameters

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | uuid | 是 | 会话 ID |
| q | string | 是 | 消息内容关键词 |

## Response `200`

```json
[
  {
    "id": "ae549c90-5d3d-4491-a5fd-5a0417e5b9ab",
    "conversation_id": "25a928f0-83b3-4948-b8a6-441d4abe7473",
    "sender_id": "2844",
    "sender_name": "搜索发起人0904152647",
    "sender_avatar": "identicon:2844",
    "seq": 2,
    "msg_type": 0,
    "content": "普通消息 needle0904152647",
    "extra": null,
    "status": 0,
    "created_at": "2026-09-04T07:26:47.656510Z",
    "read_count": 0
  }
]
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/conversations/25a928f0-83b3-4948-b8a6-441d4abe7473/messages/search?q=needle0904152647' -H 'Authorization: Bearer <redacted>'
```
