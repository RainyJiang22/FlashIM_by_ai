# GET /conversations/{id}

非群成员查询详情时按不存在处理，避免暴露群信息。

## Response `404`

```json
{
  "message": "conversation not found"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/conversations/ec1ba6b5-68e3-4a2b-945d-4c608fe791e4' -H 'Authorization: Bearer <redacted>'
```
