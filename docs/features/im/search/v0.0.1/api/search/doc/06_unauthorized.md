# GET /api/messages/search?q=<keyword>

未携带 Bearer token 时返回 401。

## Response `401`

```json
{
  "message": "missing token"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/api/messages/search?q=needle0904152647'
```
