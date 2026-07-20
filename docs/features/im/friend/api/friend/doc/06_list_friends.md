# GET /api/friends

查询当前用户的好友列表。

## Response `200`

```json
[
  {
    "account_id": 55,
    "nickname": "13800990002",
    "avatar": "identicon:55",
    "signature": "",
    "flash_id": "flash_55",
    "relation_status": "friend",
    "created_at": "2026-07-20T09:39:56.201180Z"
  }
]
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/api/friends' -H 'Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjo1NCwiZXhwIjoxNzg0NjI2Nzk2fQ.z-LyQwW5z2bYjtdHcFF30hNG72GucGTfRkVBO-p6W2A'
```
