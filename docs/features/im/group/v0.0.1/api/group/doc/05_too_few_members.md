# POST /conversations

成员不足时服务端拒绝创建且不写入半成品会话。

## Request

```json
{
  "type": "group",
  "name": "人数不足",
  "member_ids": [
    57
  ]
}
```

## Response `400`

```json
{
  "message": "invalid group member count"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X POST 'http://127.0.0.1:9600/conversations' -H 'Authorization: Bearer <redacted>' -H 'Content-Type: application/json' -d '{"type": "group", "name": "人数不足", "member_ids": [57]}'
```
