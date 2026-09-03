# GET /conversations/{conversation_id}/messages/{message_id}/read-status

仅消息发送者查看当前成员的已读与未读分组。

## Response `200`

```json
{
  "message_id": "5f2657c8-d20a-48ee-959c-a34106814632",
  "conversation_id": "08f3d59a-5d4c-49b1-8e2d-f0a11950fdd5",
  "seq": 26,
  "read_members": [
    {
      "user_id": "3677",
      "nickname": "13800995002",
      "avatar": "identicon:3677"
    }
  ],
  "unread_members": []
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/conversations/08f3d59a-5d4c-49b1-8e2d-f0a11950fdd5/messages/5f2657c8-d20a-48ee-959c-a34106814632/read-status' -H 'Authorization: Bearer <redacted>'
```
