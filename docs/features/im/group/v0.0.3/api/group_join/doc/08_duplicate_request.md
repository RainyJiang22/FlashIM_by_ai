# POST /groups/{id}/join

部分唯一索引阻止同一用户并发产生多条 pending。

## Response `409`

```json
{
  "message": "group join request already pending"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X POST 'http://127.0.0.1:9600/groups/83dbb38f-2480-4bbd-8956-c3a88b0c3c11/join' -H 'Authorization: Bearer <redacted>' -H 'Content-Type: application/json' -d '{}'
```
