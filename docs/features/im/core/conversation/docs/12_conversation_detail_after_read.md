# 12 `GET /conversations/{id}` 确认会话未读数归零

## 基本信息

- 请求方法：`GET`
- 请求链接：`http://127.0.0.1:9600/conversations/<conversation-uuid>`
- 鉴权要求：`Authorization: Bearer <token>`

## 请求参数

| 参数 | 位置 | 必填 | 说明 |
| --- | --- | --- | --- |
| `Authorization` | Header | 是 | 登录态 token |
| `id` | Path | 是 | 第 11 步已读接口使用的会话 ID |

请求体：无。

## 响应结果

```json
{
  "id": "<conversation-uuid>",
  "unread_count": 0
}
```

说明：实际响应会包含完整会话字段，本步骤重点校验 `unread_count` 已变为 `0`。

## 完整 curl

```bash
curl -sS "http://127.0.0.1:9600/conversations/<conversation-uuid>" \
  -H "Authorization: Bearer <jwt-token>"
```
