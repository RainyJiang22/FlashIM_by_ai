# 15 `GET /conversations/{id}/messages` 非法历史消息参数校验

## 基本信息

- 请求方法：`GET`
- 请求链接：`http://127.0.0.1:9600/conversations/<conversation-uuid>/messages?before_seq=0&limit=5`
- 鉴权要求：`Authorization: Bearer <token>`
- 预期状态码：`400 Bad Request`

## 请求参数

| 参数 | 位置 | 必填 | 说明 |
| --- | --- | --- | --- |
| `Authorization` | Header | 是 | 登录态 token |
| `id` | Path | 是 | 会话 ID |
| `before_seq` | Query | 否 | 必须大于等于 `1` |
| `limit` | Query | 否 | 必须大于等于 `1` |

请求体：无。

## 响应结果

```json
{
  "message": "invalid before_seq"
}
```

说明：当 `limit < 1` 时，预期返回：

```json
{
  "message": "invalid limit"
}
```

## 完整 curl

```bash
curl -sS "http://127.0.0.1:9600/conversations/<conversation-uuid>/messages?before_seq=0&limit=5" \
  -H "Authorization: Bearer <jwt-token>"
```
