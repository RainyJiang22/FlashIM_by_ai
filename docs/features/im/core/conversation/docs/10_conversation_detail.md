# 10 `GET /conversations/{id}` 查询单会话详情

## 基本信息

- 请求方法：`GET`
- 请求链接：`http://127.0.0.1:9600/conversations/<conversation-uuid>`
- 鉴权要求：`Authorization: Bearer <token>`

## 请求参数

| 参数 | 位置 | 必填 | 说明 |
| --- | --- | --- | --- |
| `Authorization` | Header | 是 | 登录态 token |
| `id` | Path | 是 | 第 04 步会话列表返回的 `id` |

请求体：无。

## 响应结果

```json
{
  "id": "<conversation-uuid>",
  "type": 0,
  "name": null,
  "peer_user_id": "3",
  "peer_nickname": "胭脂",
  "peer_avatar": "color:#C03F3C",
  "last_message_at": "2026-07-07T08:00:00Z",
  "last_message_preview": "今天的接口联调先看会话列表。",
  "unread_count": 3,
  "created_at": "2026-07-07T08:00:00Z"
}
```

说明：响应结构与 `GET /conversations` 数组中的单条 `ConversationListItem` 保持一致。

## 完整 curl

```bash
curl -sS "http://127.0.0.1:9600/conversations/<conversation-uuid>" \
  -H "Authorization: Bearer <jwt-token>"
```
