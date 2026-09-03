# 消息已读回执

WebSocket URL: `ws://127.0.0.1:9600/ws/im`

## Result

```json
{
  "message_id": "5f2657c8-d20a-48ee-959c-a34106814632",
  "conversation_id": "08f3d59a-5d4c-49b1-8e2d-f0a11950fdd5",
  "reader_id": 3677,
  "previous_read_seq": 24,
  "read_seq": 26
}
```

> 脚本故意伪造 reader_id/previous_read_seq，结果必须以认证账号和数据库旧值为准。
