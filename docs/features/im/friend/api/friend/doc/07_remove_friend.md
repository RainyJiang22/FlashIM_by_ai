# DELETE /api/friends/{friend_user_id}

解除双方好友关系，不删除历史会话和消息。

## Parameters

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| friend_user_id | int | 是 | 好友账号 ID |

## Response `200`

```json
{
  "message": "friend removed"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X DELETE 'http://127.0.0.1:9600/api/friends/55' -H 'Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjo1NCwiZXhwIjoxNzg0NjI2Nzk2fQ.z-LyQwW5z2bYjtdHcFF30hNG72GucGTfRkVBO-p6W2A'
```
