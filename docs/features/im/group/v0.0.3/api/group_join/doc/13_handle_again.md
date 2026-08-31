# POST /groups/{id}/join-requests/{rid}/handle

同一申请只能处理一次。

## Request

```json
{
  "approved": false
}
```

## Response `400`

```json
{
  "message": "group join request already handled"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X POST 'http://127.0.0.1:9600/groups/83dbb38f-2480-4bbd-8956-c3a88b0c3c11/join-requests/1e01fa05-1d32-4e42-8c2e-0cbbfb34b173/handle' -H 'Authorization: Bearer <redacted>' -H 'Content-Type: application/json' -d '{"approved": false}'
```
