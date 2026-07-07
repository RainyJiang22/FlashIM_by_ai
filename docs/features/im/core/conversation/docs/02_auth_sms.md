# 02 `POST /auth/sms` 获取短信验证码

## 基本信息

- 请求方法：`POST`
- 请求链接：`http://127.0.0.1:9600/auth/sms`
- 鉴权要求：无

## 请求参数

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `phone` | `string` | 是 | 用于登录的手机号 |

请求体：

```json
{
  "phone": "13800010001"
}
```

## 响应结果

```json
{
  "phone": "13800010001",
  "code": "123456"
}
```

说明：`code` 是运行时动态值。只有后端配置 `EXPOSE_DEBUG_SMS_CODE=true` 时，本地调试响应才会直接返回验证码。

## 完整 curl

```bash
curl -sS -X POST "http://127.0.0.1:9600/auth/sms" \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800010001"}'
```
