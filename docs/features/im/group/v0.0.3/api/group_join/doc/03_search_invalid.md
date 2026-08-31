# GET /groups/search?keyword=

空搜索词返回稳定 400。

## Response `400`

```json
{
  "message": "invalid group search keyword"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/groups/search?keyword=' -H 'Authorization: Bearer <redacted>'
```
