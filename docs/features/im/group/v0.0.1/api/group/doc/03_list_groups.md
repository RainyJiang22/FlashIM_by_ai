# GET /conversations?type=1&limit=100&offset=0

只查询当前用户有效加入的群聊，保留现有分页与排序。

## Parameters

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| type | int | 否 | 1 表示群聊，0 表示私聊 |
| limit | int | 否 | 1～100 |
| offset | int | 否 | 分页偏移 |

## Response `200`

```json
[
  {
    "id": "8e1bc0e3-ad75-4dc8-a838-31d9d0fc95ce",
    "type": 1,
    "name": "群聊链路-205535",
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
    "last_message_at": "2026-08-14T12:55:37.357382Z",
    "last_message_preview": "群聊复用链路 2026-08-14T20:55:37",
    "unread_count": 0,
    "created_at": "2026-08-14T12:55:35.731476Z"
  },
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
]
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/conversations?type=1&limit=100&offset=0' -H 'Authorization: Bearer <redacted>'
```
