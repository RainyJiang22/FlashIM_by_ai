# GET /conversations?type=2

会话列表只接受 type=0、type=1 或省略 type。

## Response `400`

```json
{
  "message": "invalid conversation type"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/conversations?type=2' -H 'Authorization: Bearer <redacted>'
```
