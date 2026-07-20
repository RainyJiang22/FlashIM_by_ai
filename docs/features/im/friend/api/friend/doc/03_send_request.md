# POST /api/friends/requests

向目标用户发送好友申请；重复发送会覆盖留言并保持 pending 状态。

## Request

```json
{
  "to_user_id": 55,
  "message": "我是小雨"
}
```

## Response `200`

```json
{
  "id": "9d7c8f9c-9a32-4a7e-8b03-15044c639e0f",
  "from_user_id": 54,
  "to_user_id": 55,
  "message": "我是小雨",
  "status": "pending",
  "created_at": "2026-07-20T09:39:56.176856Z"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X POST 'http://127.0.0.1:9600/api/friends/requests' -H 'Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjo1NCwiZXhwIjoxNzg0NjI2Nzk2fQ.z-LyQwW5z2bYjtdHcFF30hNG72GucGTfRkVBO-p6W2A' -H 'Content-Type: application/json' -d '{"to_user_id": 55, "message": "我是小雨"}'
```
