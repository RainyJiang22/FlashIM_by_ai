# POST /conversations

从当前用户好友中选择至少两人创建群聊，服务端自动加入群主。

## Parameters

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| type | string | 是 | 固定为 group |
| name | string | 是 | 1～100 字群名 |
| member_ids | int[] | 是 | 2～199 个好友 ID |

## Request

```json
{
  "type": "group",
  "name": "群聊链路-200856",
  "member_ids": [
    57,
    58
  ]
}
```

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
%{http_code}' -X POST 'http://127.0.0.1:9600/conversations' -H 'Authorization: Bearer <redacted>' -H 'Content-Type: application/json' -d '{"type": "group", "name": "群聊链路-200856", "member_ids": [57, 58]}'
```
