# WebSocket 群消息复用链路

通过现有 `/ws/im`、`CHAT_MESSAGE`、`MESSAGE_ACK` 和 `CONVERSATION_UPDATE` 验证群成员消息收发。

WebSocket URL: `ws://127.0.0.1:9600/ws/im`

## Result

```json
{
  "conversation_id": "ec1ba6b5-68e3-4a2b-945d-4c608fe791e4",
  "content": "群聊复用链路 2026-08-16T20:08:56",
  "message_id": "9b855521-af89-444d-a342-d24802bfc878",
  "seq": 1,
  "sender_name": "13800991001",
  "sender_avatar": "identicon:56",
  "receiver_unread_count": 1,
  "receiver_total_unread": 4
}
```

> 本步骤不新增群消息协议；二进制帧编码完全沿用现有消息链路。
