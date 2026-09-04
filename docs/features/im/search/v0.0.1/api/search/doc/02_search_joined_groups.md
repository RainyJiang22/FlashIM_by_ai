# GET /api/conversations/search-joined-groups?q=<keyword>

搜索当前用户已加入且未解散的群聊。

## Parameters

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| q | string | 是 | 群名关键词 |

## Response `200`

```json
[
  {
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
  }
]
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/api/conversations/search-joined-groups?q=%E7%BB%BC%E5%90%88%E6%90%9C%E7%B4%A2%E7%BE%A40904152647' -H 'Authorization: Bearer <redacted>'
```
