# GET /api/messages/search?q=<keyword>

跨当前用户可见会话搜索普通消息，并按会话分组。

## Parameters

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| q | string | 是 | 消息内容关键词 |

## Response `200`

```json
[
  {
    "conversation": {
      "id": "25a928f0-83b3-4948-b8a6-441d4abe7473",
      "type": 1,
      "name": "综合搜索群0904152647",
      "avatar": "grid:identicon:2844,identicon:2845,identicon:2846",
      "owner_id": "2844",
      "member_avatars": [
        "identicon:2844",
        "identicon:2845",
        "identicon:2846"
      ],
      "member_count": 3,
      "peer_user_id": null,
      "peer_nickname": null,
      "peer_avatar": null,
      "last_message_at": "2026-09-04T07:26:47.656510Z",
      "last_message_preview": "普通消息 needle0904152647",
      "unread_count": 0,
      "announcement": "",
      "is_dissolved": false,
      "created_at": "2026-09-04T07:26:47.609427Z"
    },
    "match_count": 1,
    "messages": [
      {
        "id": "ae549c90-5d3d-4491-a5fd-5a0417e5b9ab",
        "conversation_id": "25a928f0-83b3-4948-b8a6-441d4abe7473",
        "sender_id": "2844",
        "sender_name": "搜索发起人0904152647",
        "sender_avatar": "identicon:2844",
        "seq": 2,
        "msg_type": 0,
        "content": "普通消息 needle0904152647",
        "extra": null,
        "status": 0,
        "created_at": "2026-09-04T07:26:47.656510Z",
        "read_count": 0
      }
    ]
  }
]
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/api/messages/search?q=needle0904152647' -H 'Authorization: Bearer <redacted>'
```

> 系统事件消息不会进入结果。
