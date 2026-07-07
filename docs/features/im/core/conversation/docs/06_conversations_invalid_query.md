# 06 `GET /conversations` 非法分页参数校验

## 基本信息

- 请求方法：`GET`
- 请求链接：`http://127.0.0.1:9600/conversations?limit=0&offset=0`
- 鉴权要求：`Authorization: Bearer <token>`
- 预期状态码：`400 Bad Request`

## 请求参数

| 参数 | 位置 | 必填 | 说明 |
| --- | --- | --- | --- |
| `Authorization` | Header | 是 | 登录态 token |
| `limit` | Query | 否 | 必须大于等于 `1` |
| `offset` | Query | 否 | 必须大于等于 `0` |

请求体：无。

## 响应结果

```json
{
  "message": "invalid limit"
}
```

说明：当 `offset < 0` 时，预期返回：

```json
{
  "message": "invalid offset"
}
```

## 完整 curl

```bash
curl -sS "http://127.0.0.1:9600/conversations?limit=0&offset=0" \
  -H "Authorization: Bearer <jwt-token>"
```
