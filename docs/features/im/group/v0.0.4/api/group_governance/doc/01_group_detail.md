# GET /groups/{id}

读取群角色、成员、公告和解散状态。

## Response `200`

```json
{
  "conversation_id": "21c6fd90-fdc1-4368-aed0-82ea267d050f",
  "name": "治理链路-20260901101524999545",
  "avatar": "grid:identicon:2844,identicon:2845,identicon:2847",
  "owner_id": "2844",
  "join_approval_required": false,
  "announcement": "",
  "announcement_updated_at": null,
  "announcement_updated_by": null,
  "announcement_updated_by_name": "",
  "is_dissolved": false,
  "current_user_role": "owner",
  "member_count": 3,
  "members": [
    {
      "account_id": "2844",
      "nickname": "13800994001",
      "avatar": "identicon:2844",
      "is_owner": true,
      "joined_at": "2026-09-01T02:15:25.011215Z"
    },
    {
      "account_id": "2845",
      "nickname": "13800994002",
      "avatar": "identicon:2845",
      "is_owner": false,
      "joined_at": "2026-09-01T02:15:25.011215Z"
    },
    {
      "account_id": "2847",
      "nickname": "13800994004",
      "avatar": "identicon:2847",
      "is_owner": false,
      "joined_at": "2026-09-01T02:15:25.011215Z"
    }
  ]
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/groups/21c6fd90-fdc1-4368-aed0-82ea267d050f' -H 'Authorization: Bearer <redacted>'
```
