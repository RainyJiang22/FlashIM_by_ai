# POST /api/friends/requests/{id}/accept

接收方接受好友申请，服务端建立双向好友关系并创建或复用私聊会话。

## Parameters

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | uuid | 是 | 好友申请 ID |

## Response `200`

```json
{
  "request_id": "9d7c8f9c-9a32-4a7e-8b03-15044c639e0f",
  "friend": {
    "account_id": 54,
    "nickname": "13800990001",
    "avatar": "identicon:54",
    "signature": "",
    "flash_id": "flash_54",
    "relation_status": "friend"
  },
  "conversation_id": "36a51874-a0d0-408f-bab1-ad57a77e2ecb"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X POST 'http://127.0.0.1:9600/api/friends/requests/9d7c8f9c-9a32-4a7e-8b03-15044c639e0f/accept' -H 'Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhY2NvdW50X2lkIjo1NSwiZXhwIjoxNzg0NjI2Nzk2fQ.J-oKaSpQiFU7374_9zi0yTGOFB0E_B76S67rUGSnE-U'
```
