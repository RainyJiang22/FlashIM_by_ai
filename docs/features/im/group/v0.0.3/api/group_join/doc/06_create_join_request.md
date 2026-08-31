# POST /groups/{id}/join

开启入群验证时创建唯一 pending 申请。

## Request

```json
{
  "message": "请群主通过"
}
```

## Response `200`

```json
{
  "auto_approved": false,
  "request_id": "1e01fa05-1d32-4e42-8c2e-0cbbfb34b173",
  "conversation": null
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X POST 'http://127.0.0.1:9600/groups/83dbb38f-2480-4bbd-8956-c3a88b0c3c11/join' -H 'Authorization: Bearer <redacted>' -H 'Content-Type: application/json' -d '{"message": "请群主通过"}'
```
