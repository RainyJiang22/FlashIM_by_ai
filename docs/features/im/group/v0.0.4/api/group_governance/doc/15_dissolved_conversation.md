# GET /conversations/{id}

原成员仍可读取已解散会话摘要。

## Response `200`

```json
{
  "id": "21c6fd90-fdc1-4368-aed0-82ea267d050f",
  "type": 1,
  "name": "治理群",
  "avatar": "grid:identicon:2844,identicon:2847",
  "owner_id": "2844",
  "member_avatars": [
    "identicon:2844",
    "identicon:2847"
  ],
  "peer_user_id": null,
  "peer_nickname": null,
  "peer_avatar": null,
  "last_message_at": "2026-09-01T02:15:25.347198Z",
  "last_message_preview": "群聊已解散",
  "unread_count": 9,
  "is_dissolved": true,
  "created_at": "2026-09-01T02:15:25.011215Z"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/conversations/21c6fd90-fdc1-4368-aed0-82ea267d050f' -H 'Authorization: Bearer <redacted>'
```
