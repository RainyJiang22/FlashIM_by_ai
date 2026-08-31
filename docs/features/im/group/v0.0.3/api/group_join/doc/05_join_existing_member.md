# POST /groups/{id}/join

已在群内的用户不能重复加入。

## Response `400`

```json
{
  "message": "already a group member"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X POST 'http://127.0.0.1:9600/groups/6e2275d3-460f-4fa2-b9ae-7384516dbcc5/join' -H 'Authorization: Bearer <redacted>' -H 'Content-Type: application/json' -d '{}'
```
