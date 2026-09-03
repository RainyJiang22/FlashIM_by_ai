# GET /conversations/{id}/messages

非会话成员不能读取历史，也不能建立合法已读位置。

## Response `404`

```json
{
  "message": "conversation not found"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/conversations/08f3d59a-5d4c-49b1-8e2d-f0a11950fdd5/messages' -H 'Authorization: Bearer <redacted>'
```
