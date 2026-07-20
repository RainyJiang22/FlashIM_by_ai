# GET /api/users/{account_id}

查看用户公开资料，并返回当前用户与对方的关系状态。

## Parameters

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| account_id | int | 是 | 目标账号 ID |

## Response `200`

```json
{
  "account_id": 55,
  "nickname": "13800990002",
  "avatar": "identicon:55",
  "signature": "",
  "flash_id": "flash_55",
  "relation_status": "none"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/api/users/55' -H 'Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjo1NCwiZXhwIjoxNzg0NjI2Nzk2fQ.z-LyQwW5z2bYjtdHcFF30hNG72GucGTfRkVBO-p6W2A'
```
