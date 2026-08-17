# POST /conversations

包含非好友时服务端拒绝创建且不写入半成品会话。

## Request

```json
{
  "type": "group",
  "name": "非好友",
  "member_ids": [
    56,
    58
  ]
}
```

## Response `400`

```json
{
  "message": "invalid group members"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X POST 'http://127.0.0.1:9600/conversations' -H 'Authorization: Bearer <redacted>' -H 'Content-Type: application/json' -d '{"type": "group", "name": "非好友", "member_ids": [56, 58]}'
```
