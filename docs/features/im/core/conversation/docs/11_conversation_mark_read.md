# 11 `POST /conversations/{id}/read` 标记会话已读

## 基本信息

- 请求方法：`POST`
- 请求链接：`http://127.0.0.1:9600/conversations/<conversation-uuid>/read`
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
  "message": "conversation marked as read"
}
```

说明：该接口只清零当前用户在当前会话中的 `unread_count`，不表示对端已读回执。

## 完整 curl

```bash
curl -sS -X POST "http://127.0.0.1:9600/conversations/<conversation-uuid>/read" \
  -H "Authorization: Bearer <jwt-token>"
```
