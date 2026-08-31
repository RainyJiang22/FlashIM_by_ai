# GET /groups/search?keyword={uuid}

输入完整 UUID 群号时精确匹配群聊。

## Response `200`

```json
{
  "groups": [
    {
      "conversation_id": "83dbb38f-2480-4bbd-8956-c3a88b0c3c11",
      "group_number": "83dbb38f-2480-4bbd-8956-c3a88b0c3c11",
      "name": "审批入群-20260831111515146186",
      "avatar": "grid:identicon:2019,identicon:2020,identicon:2021",
      "member_count": 3,
      "join_approval_required": true,
      "is_member": false,
      "has_pending_request": false
    }
  ]
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/groups/search?keyword=83dbb38f-2480-4bbd-8956-c3a88b0c3c11' -H 'Authorization: Bearer <redacted>'
```
