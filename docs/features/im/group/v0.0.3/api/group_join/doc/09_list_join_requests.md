# GET /groups/join-requests

查询当前用户作为群主的全部入群申请，pending 优先。

## Response `200`

```json
{
  "pending_count": 2,
  "requests": [
    {
      "id": "1e01fa05-1d32-4e42-8c2e-0cbbfb34b173",
      "conversation_id": "83dbb38f-2480-4bbd-8956-c3a88b0c3c11",
      "group_name": "审批入群-20260831111515146186",
      "group_avatar": "grid:identicon:2019,identicon:2020,identicon:2021",
      "applicant_id": "2023",
      "applicant_name": "13800993005",
      "applicant_avatar": "identicon:2023",
      "message": "请群主通过",
      "status": "pending",
      "created_at": "2026-08-31T03:15:15.316043Z",
      "handled_at": null
    },
    {
      "id": "a2ef34c7-0b50-4e9a-803c-84df9be37333",
      "conversation_id": "6ea39738-b24e-45fb-82b1-a337fa2b9dfd",
      "group_name": "审批入群-20260831111449753678",
      "group_avatar": "grid:identicon:2019,identicon:2020,identicon:2021",
      "applicant_id": "2023",
      "applicant_name": "13800993005",
      "applicant_avatar": "identicon:2023",
      "message": "请群主通过",
      "status": "pending",
      "created_at": "2026-08-31T03:14:49.909581Z",
      "handled_at": null
    }
  ]
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/groups/join-requests' -H 'Authorization: Bearer <redacted>'
```
