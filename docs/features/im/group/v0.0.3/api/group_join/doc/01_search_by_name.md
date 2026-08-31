# GET /groups/search?keyword={keyword}

按群名模糊搜索未解散群，并返回成员数与入群状态。

## Parameters

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| keyword | string | 是 | 1～100 字群名或完整群号 |

## Response `200`

```json
{
  "groups": [
    {
      "conversation_id": "6e2275d3-460f-4fa2-b9ae-7384516dbcc5",
      "group_number": "6e2275d3-460f-4fa2-b9ae-7384516dbcc5",
      "name": "直接入群-20260831111515146186",
      "avatar": "grid:identicon:2019,identicon:2020,identicon:2021",
      "member_count": 3,
      "join_approval_required": false,
      "is_member": false,
      "has_pending_request": false
    }
  ]
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/groups/search?keyword=直接入群-20260831111515146186' -H 'Authorization: Bearer <redacted>'
```
