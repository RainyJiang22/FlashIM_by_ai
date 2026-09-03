# GET /conversations/{conversation_id}/messages/{message_id}/read-status

非消息发送者读取成员级回执详情返回 403。

## Response `403`

```json
{
  "message": "message read status is not allowed"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/conversations/08f3d59a-5d4c-49b1-8e2d-f0a11950fdd5/messages/5f2657c8-d20a-48ee-959c-a34106814632/read-status' -H 'Authorization: Bearer <redacted>'
```
