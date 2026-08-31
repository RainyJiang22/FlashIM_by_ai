# POST /groups/{id}/join

关闭入群验证时直接恢复或新增成员，并返回群会话。

## Response `200`

```json
{
  "auto_approved": true,
  "request_id": null,
  "conversation": {
    "id": "6e2275d3-460f-4fa2-b9ae-7384516dbcc5",
    "type": 1,
    "name": "直接入群-20260831111515146186",
    "avatar": "grid:identicon:2019,identicon:2020,identicon:2021,identicon:2022",
    "owner_id": "2019",
    "member_avatars": [
      "identicon:2019",
      "identicon:2020",
      "identicon:2021",
      "identicon:2022"
    ],
    "peer_user_id": null,
    "peer_nickname": null,
    "peer_avatar": null,
    "last_message_at": "2026-08-31T03:15:15.287501Z",
    "last_message_preview": "13800993004 加入了群聊",
    "unread_count": 0,
    "created_at": "2026-08-31T03:15:15.165907Z"
  }
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X POST 'http://127.0.0.1:9600/groups/6e2275d3-460f-4fa2-b9ae-7384516dbcc5/join' -H 'Authorization: Bearer <redacted>' -H 'Content-Type: application/json' -d '{}'
```
