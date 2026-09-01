# DELETE /groups/{id}

群主解散群聊，保留原成员关系和消息作为只读历史。

## Response `200`

```json
{
  "message": "group dissolved"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X DELETE 'http://127.0.0.1:9600/groups/21c6fd90-fdc1-4368-aed0-82ea267d050f' -H 'Authorization: Bearer <redacted>'
```
