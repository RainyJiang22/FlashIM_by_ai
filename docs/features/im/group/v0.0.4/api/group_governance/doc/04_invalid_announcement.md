# PATCH /groups/{id}/announcement

空白公告返回稳定 400。

## Request

```json
{
  "announcement": " "
}
```

## Response `400`

```json
{
  "message": "invalid group announcement"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X PATCH 'http://127.0.0.1:9600/groups/21c6fd90-fdc1-4368-aed0-82ea267d050f/announcement' -H 'Authorization: Bearer <redacted>' -H 'Content-Type: application/json' -d '{"announcement": " "}'
```
