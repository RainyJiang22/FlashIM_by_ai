# POST /groups/{id}/leave

群主必须先转让或解散，不能直接退群。

## Response `400`

```json
{
  "message": "group owner cannot leave"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X POST 'http://127.0.0.1:9600/groups/21c6fd90-fdc1-4368-aed0-82ea267d050f/leave' -H 'Authorization: Bearer <redacted>'
```
