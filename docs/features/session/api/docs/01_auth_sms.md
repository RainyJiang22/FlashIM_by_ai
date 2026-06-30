# 01 `/auth/sms`

## 基本信息

- 请求方法：`POST`
- 请求链接：`http://127.0.0.1:9600/auth/sms`
- 鉴权要求：无

## 请求参数

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `phone` | `string` | 是 | 手机号 |

请求体：

```json
{
  "phone": "13818164147"
}
```

## 响应结果

```json
{
  "phone": "13818164147",
  "code": "088806"
}
```

说明：只有 `EXPOSE_DEBUG_SMS_CODE=true` 时，响应里才会直接带 `code`。

## 完整 curl

```bash
curl -sS -X POST "http://127.0.0.1:9600/auth/sms" \
  -H "Content-Type: application/json" \
  -d '{"phone":"13818164147"}'
```
