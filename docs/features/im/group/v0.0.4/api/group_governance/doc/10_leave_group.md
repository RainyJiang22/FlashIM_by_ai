# POST /groups/{id}/leave

普通成员软删除自己的群成员关系。

## Response `200`

```json
{
  "message": "left group"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X POST 'http://127.0.0.1:9600/groups/21c6fd90-fdc1-4368-aed0-82ea267d050f/leave' -H 'Authorization: Bearer <redacted>'
```
