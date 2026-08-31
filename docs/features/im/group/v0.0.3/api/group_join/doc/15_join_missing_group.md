# POST /groups/{id}/join

不存在或已解散的群不可加入。

## Response `404`

```json
{
  "message": "group not found"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X POST 'http://127.0.0.1:9600/groups/00000000-0000-0000-0000-000000000000/join' -H 'Authorization: Bearer <redacted>' -H 'Content-Type: application/json' -d '{}'
```
