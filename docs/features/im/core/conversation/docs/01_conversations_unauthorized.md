# 01 `GET /conversations` 会话列表未鉴权拦截

## 基本信息

- 请求方法：`GET`
- 请求链接：`http://127.0.0.1:9600/conversations?limit=20&offset=0`
- 鉴权要求：本步骤故意不传 `Authorization`
- 预期状态码：`401 Unauthorized`

## 请求参数

| 参数 | 位置 | 必填 | 说明 |
| --- | --- | --- | --- |
| `limit` | Query | 否 | 每页数量，默认 `20`，最大 `100` |
| `offset` | Query | 否 | 分页偏移量，默认 `0` |

请求体：无。

## 响应结果

```json
{
  "message": "missing token"
}
```

## 完整 curl

```bash
curl -sS "http://127.0.0.1:9600/conversations?limit=20&offset=0"
```
