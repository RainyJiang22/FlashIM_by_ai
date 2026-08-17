# GET /conversations/{id}

群成员查询群聊详情，响应包含群主和组合头像成员数据。

## Parameters

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | uuid | 是 | 群会话 ID |

## Response `200`

```json
{
  "id": "ec1ba6b5-68e3-4a2b-945d-4c608fe791e4",
  "type": 1,
  "name": "群聊链路-200856",
  "avatar": null,
  "owner_id": "56",
  "member_avatars": [
    "identicon:56",
    "identicon:57",
    "identicon:58"
  ],
  "peer_user_id": null,
  "peer_nickname": null,
  "peer_avatar": null,
  "last_message_at": null,
  "last_message_preview": null,
  "unread_count": 0,
  "created_at": "2026-08-16T12:08:56.224821Z"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/conversations/ec1ba6b5-68e3-4a2b-945d-4c608fe791e4' -H 'Authorization: Bearer <redacted>'
```
