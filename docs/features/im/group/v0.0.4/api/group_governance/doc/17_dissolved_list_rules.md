# GET /conversations

主列表保留解散历史，type=1 我的群聊继续只显示活跃群。

## Response `200`

```json
[
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
  },
  {
    "id": "60ba441f-8912-4f1f-af3e-1c6f79920919",
    "type": 0,
    "name": null,
    "avatar": null,
    "owner_id": null,
    "member_avatars": [],
    "peer_user_id": "2844",
    "peer_nickname": "13800994001",
    "peer_avatar": "identicon:2844",
    "last_message_at": "2026-09-01T02:15:24.995166Z",
    "last_message_preview": "群聊链路前置好友",
    "unread_count": 2,
    "is_dissolved": false,
    "created_at": "2026-08-31T09:09:55.783668Z"
  }
]
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/conversations?limit=100&offset=0' -H 'Authorization: Bearer <redacted>'
```

> 同一步额外验证 `/conversations?type=1` 不包含目标群。
