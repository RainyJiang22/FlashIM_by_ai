# 07 `GET /conversations/{id}` 单会话详情未鉴权拦截

## 基本信息

- 请求方法：`GET`
- 请求链接：`http://127.0.0.1:9600/conversations/00000000-0000-0000-0000-000000000001`
- 鉴权要求：本步骤故意不传 `Authorization`
- 预期状态码：`401 Unauthorized`

## 请求参数

| 参数 | 位置 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | Path | 是 | 会话 ID，UUID |

请求体：无。

## 响应结果

```json
{
  "message": "missing token"
}
```

## 完整 curl

```bash
curl -sS "http://127.0.0.1:9600/conversations/00000000-0000-0000-0000-000000000001"
```
