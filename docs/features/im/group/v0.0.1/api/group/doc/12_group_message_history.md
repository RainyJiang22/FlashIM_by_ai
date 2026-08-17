# GET /conversations/{id}/messages?before_seq=999999&limit=10

群成员通过现有历史消息接口回放群消息。

## Response `200`

```json
[
  {
    "id": "9b855521-af89-444d-a342-d24802bfc878",
    "conversation_id": "ec1ba6b5-68e3-4a2b-945d-4c608fe791e4",
    "sender_id": "56",
    "sender_name": "13800991001",
    "sender_avatar": "identicon:56",
    "seq": 1,
    "msg_type": 0,
    "content": "群聊复用链路 2026-08-16T20:08:56",
    "extra": null,
    "status": 0,
    "created_at": "2026-08-16T12:08:56.657982Z"
  }
]
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/conversations/ec1ba6b5-68e3-4a2b-945d-4c608fe791e4/messages?before_seq=999999&limit=10' -H 'Authorization: Bearer <redacted>'
```

> 该消息由步骤 11 的现有 WebSocket CHAT_MESSAGE 链路写入。
