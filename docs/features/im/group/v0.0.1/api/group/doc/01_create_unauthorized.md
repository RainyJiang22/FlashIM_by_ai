# POST /conversations

未携带 Bearer Token 创建群聊时返回 401。

## Request

```json
{
  "type": "group",
  "name": "群聊链路-200856",
  "member_ids": [
    57,
    58
  ]
}
```

## Response `401`

```json
{
  "message": "missing token"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X POST 'http://127.0.0.1:9600/conversations' -H 'Content-Type: application/json' -d '{"type": "group", "name": "群聊链路-200856", "member_ids": [57, 58]}'
```
