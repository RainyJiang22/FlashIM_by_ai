# POST /groups/{id}/join-requests/{rid}/handle

群主同意后在同一事务中写入成员、刷新群头像并更新申请状态。

## Request

```json
{
  "approved": true
}
```

## Response `200`

```json
{
  "id": "1e01fa05-1d32-4e42-8c2e-0cbbfb34b173",
  "conversation_id": "83dbb38f-2480-4bbd-8956-c3a88b0c3c11",
  "group_name": "审批入群-20260831111515146186",
  "group_avatar": "grid:identicon:2019,identicon:2020,identicon:2021,identicon:2023",
  "applicant_id": "2023",
  "applicant_name": "13800993005",
  "applicant_avatar": "identicon:2023",
  "message": "请群主通过",
  "status": "approved",
  "created_at": "2026-08-31T03:15:15.316043Z",
  "handled_at": "2026-08-31T03:15:15.369775Z"
}
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X POST 'http://127.0.0.1:9600/groups/83dbb38f-2480-4bbd-8956-c3a88b0c3c11/join-requests/1e01fa05-1d32-4e42-8c2e-0cbbfb34b173/handle' -H 'Authorization: Bearer <redacted>' -H 'Content-Type: application/json' -d '{"approved": true}'
```
