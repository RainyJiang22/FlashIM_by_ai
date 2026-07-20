# GET /api/users/search?q=<phone>

按手机号、闪讯号或昵称搜索用户，并返回当前关系状态。

## Parameters

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| q | string | 是 | 搜索关键词 |

## Response `200`

```json
[
  {
    "account_id": 55,
    "nickname": "13800990002",
    "avatar": "identicon:55",
    "signature": "",
    "flash_id": "flash_55",
    "relation_status": "none"
  }
]
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/api/users/search?q=13800990002' -H 'Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjo1NCwiZXhwIjoxNzg0NjI2Nzk2fQ.z-LyQwW5z2bYjtdHcFF30hNG72GucGTfRkVBO-p6W2A'
```
