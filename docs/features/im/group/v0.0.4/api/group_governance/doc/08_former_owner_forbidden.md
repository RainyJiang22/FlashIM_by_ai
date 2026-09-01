# PATCH /groups/{id}/announcement

转让后原群主立即失去群主权限。

## Request

```json
{
  "announcement": "不应成功"
}
```

## Response `403`

```json
{
  "message": "group operation is not allowed"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X PATCH 'http://127.0.0.1:9600/groups/21c6fd90-fdc1-4368-aed0-82ea267d050f/announcement' -H 'Authorization: Bearer <redacted>' -H 'Content-Type: application/json' -d '{"announcement": "不应成功"}'
```
