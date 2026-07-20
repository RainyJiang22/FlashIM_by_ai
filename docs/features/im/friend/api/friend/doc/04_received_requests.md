# GET /api/friends/requests/received

接收方查看收到的好友申请列表，默认只返回 pending。

## Response `200`

```json
[
  {
    "id": "9d7c8f9c-9a32-4a7e-8b03-15044c639e0f",
    "from_user": {
      "account_id": 54,
      "nickname": "13800990001",
      "avatar": "identicon:54",
      "signature": "",
      "flash_id": "flash_54"
    },
    "message": "我是小雨",
    "status": "pending",
    "created_at": "2026-07-20T09:39:56.176856Z"
  }
]
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/api/friends/requests/received' -H 'Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjo1NSwiZXhwIjoxNzg0NjI2Nzk2fQ.J-oKaSpQiFU7374_9zi0yTGOFB0E_B76S67rUGSnE-U'
```
