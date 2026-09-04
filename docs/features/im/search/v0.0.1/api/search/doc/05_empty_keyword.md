# GET /api/messages/search?q=<blank>

空白关键词返回 400。

## Response `400`

```json
{
  "message": "invalid message search query"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/api/messages/search?q=%20' -H 'Authorization: Bearer <redacted>'
```
