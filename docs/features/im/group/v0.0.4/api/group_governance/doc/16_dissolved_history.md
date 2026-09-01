# GET /conversations/{id}/messages

解散后仍可读取完整 type=5 治理消息历史。

## Response `200`

```json
[
  {
    "id": "db328f10-a923-4cac-b19e-482eed663093",
    "conversation_id": "21c6fd90-fdc1-4368-aed0-82ea267d050f",
    "sender_id": "2844",
    "sender_name": "13800994001",
    "sender_avatar": "identicon:2844",
    "seq": 9,
    "msg_type": 5,
    "content": "群聊已解散",
    "extra": {
      "system_event": "group_dissolved"
    },
    "status": 0,
    "created_at": "2026-09-01T02:15:25.347198Z"
  },
  {
    "id": "994ac836-2f06-44f4-a10d-54989cfed520",
    "conversation_id": "21c6fd90-fdc1-4368-aed0-82ea267d050f",
    "sender_id": "2844",
    "sender_name": "13800994001",
    "sender_avatar": "identicon:2844",
    "seq": 8,
    "msg_type": 5,
    "content": "13800994002 被 13800994001 移出群聊",
    "extra": {
      "system_event": "member_removed"
    },
    "status": 0,
    "created_at": "2026-09-01T02:15:25.327314Z"
  },
  {
    "id": "cc8a8654-f196-4a6c-a0d1-61e5c35ad925",
    "conversation_id": "21c6fd90-fdc1-4368-aed0-82ea267d050f",
    "sender_id": "2844",
    "sender_name": "13800994001",
    "sender_avatar": "identicon:2844",
    "seq": 7,
    "msg_type": 5,
    "content": "13800994003 退出了群聊",
    "extra": {
      "system_event": "member_left"
    },
    "status": 0,
    "created_at": "2026-09-01T02:15:25.281838Z"
  },
  {
    "id": "220bcc29-4f81-40d3-85bf-c1ffd1cea7b2",
    "conversation_id": "21c6fd90-fdc1-4368-aed0-82ea267d050f",
    "sender_id": "2845",
    "sender_name": "13800994002",
    "sender_avatar": "identicon:2845",
    "seq": 6,
    "msg_type": 5,
    "content": "13800994002 将群主转让给了 13800994001",
    "extra": {
      "system_event": "owner_transferred"
    },
    "status": 0,
    "created_at": "2026-09-01T02:15:25.254670Z"
  },
  {
    "id": "a15adfbe-6265-4380-b1ff-250cf60d7e8f",
    "conversation_id": "21c6fd90-fdc1-4368-aed0-82ea267d050f",
    "sender_id": "2844",
    "sender_name": "13800994001",
    "sender_avatar": "identicon:2844",
    "seq": 5,
    "msg_type": 5,
    "content": "13800994001 将群主转让给了 13800994002",
    "extra": {
      "system_event": "owner_transferred"
    },
    "status": 0,
    "created_at": "2026-09-01T02:15:25.203345Z"
  },
  {
    "id": "a00d56ab-3e25-4c41-a2b5-853b67399a42",
    "conversation_id": "21c6fd90-fdc1-4368-aed0-82ea267d050f",
    "sender_id": "2846",
    "sender_name": "13800994003",
    "sender_avatar": "identicon:2846",
    "seq": 4,
    "msg_type": 5,
    "content": "13800994003 加入了群聊",
    "extra": {
      "system_event": "member_joined"
    },
    "status": 0,
    "created_at": "2026-09-01T02:15:25.166675Z"
  },
  {
    "id": "fbb476c9-edf3-4073-a328-dd79f851603b",
    "conversation_id": "21c6fd90-fdc1-4368-aed0-82ea267d050f",
    "sender_id": "2844",
    "sender_name": "13800994001",
    "sender_avatar": "identicon:2844",
    "seq": 3,
    "msg_type": 5,
    "content": "13800994001 将群名修改为「治理群」",
    "extra": {
      "system_event": "group_name_updated"
    },
    "status": 0,
    "created_at": "2026-09-01T02:15:25.127056Z"
  },
  {
    "id": "f90a4f9a-80c8-4471-9520-501e2d9cc48b",
    "conversation_id": "21c6fd90-fdc1-4368-aed0-82ea267d050f",
    "sender_id": "2844",
    "sender_name": "13800994001",
    "sender_avatar": "identicon:2844",
    "seq": 2,
    "msg_type": 5,
    "content": "13800994001 更新了群公告",
    "extra": {
      "system_event": "announcement_updated"
    },
    "status": 0,
    "created_at": "2026-09-01T02:15:25.088614Z"
  },
  {
    "id": "72b68b41-7903-4bd5-a8a2-55647be21fb6",
    "conversation_id": "21c6fd90-fdc1-4368-aed0-82ea267d050f",
    "sender_id": "2844",
    "sender_name": "13800994001",
    "sender_avatar": "identicon:2844",
    "seq": 1,
    "msg_type": 5,
    "content": "13800994001 创建了群聊",
    "extra": {
      "system_event": "group_created"
    },
    "status": 0,
    "created_at": "2026-09-01T02:15:25.031137Z"
  }
]
```

## curl

```bash
/usr/bin/curl -sS -w '
%{http_code}' -X GET 'http://127.0.0.1:9600/conversations/21c6fd90-fdc1-4368-aed0-82ea267d050f/messages' -H 'Authorization: Bearer <redacted>'
```
