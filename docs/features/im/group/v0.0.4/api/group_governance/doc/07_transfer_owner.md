# PATCH /groups/{id}/owner

群主把所有权原子转让给另一活跃成员。

## Request

```json
{
  "owner_id": 2845
}
```

## Response `200`

```json
{
  "conversation_id": "21c6fd90-fdc1-4368-aed0-82ea267d050f",
  "name": "治理群",
  "avatar": "grid:identicon:2844,identicon:2845,identicon:2847,identicon:2846",
  "owner_id": "2845",
  "join_approval_required": false,
  "announcement": "周五 18:00 发布",
  "announcement_updated_at": "2026-09-01T02:15:25.084272Z",
  "announcement_updated_by": "2844",
  "announcement_updated_by_name": "13800994001",
  "is_dissolved": false,
  "current_user_role": "member",
  "member_count": 4,
  "members": [
    {
      "account_id": "2845",
      "nickname": "13800994002",
      "avatar": "identicon:2845",
      "is_owner": true,
      "joined_at": "2026-09-01T02:15:25.011215Z"
    },
    {
      "account_id": "2844",
      "nickname": "13800994001",
      "avatar": "identicon:2844",
      "is_owner": false,
      "joined_at": "2026-09-01T02:15:25.011215Z"
    },
    {
      "account_id": "2847",
      "nickname": "13800994004",
      "avatar": "identicon:2847",
      "is_owner": false,
      "joined_at": "2026-09-01T02:15:25.011215Z"
    },
    {
      "account_id": "2846",
      "nickname": "13800994003",
      "avatar": "identicon:2846",
      "is_owner": false,
      "joined_at": "2026-09-01T02:15:25.147805Z"
    }
  ]
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X PATCH 'http://127.0.0.1:9600/groups/21c6fd90-fdc1-4368-aed0-82ea267d050f/owner' -H 'Authorization: Bearer <redacted>' -H 'Content-Type: application/json' -d '{"owner_id": 2845}'
```
