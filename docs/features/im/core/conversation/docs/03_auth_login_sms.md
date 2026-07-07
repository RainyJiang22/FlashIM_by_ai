# 03 `POST /auth/login` 短信验证码登录

## 基本信息

- 请求方法：`POST`
- 请求链接：`http://127.0.0.1:9600/auth/login`
- 鉴权要求：无

## 请求参数

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `login_type` | `string` | 是 | 固定为 `sms_code` |
| `phone` | `string` | 是 | 第 02 步使用的手机号 |
| `code` | `string` | 是 | 第 02 步返回的验证码 |

请求体：

```json
{
  "login_type": "sms_code",
  "phone": "13800010001",
  "code": "123456"
}
```

## 响应结果

```json
{
  "token": "<jwt-token>",
  "account_id": 2,
  "password_setup_required": true
}
```

说明：`token` 是运行时动态值，后续会话列表请求都要通过 `Authorization: Bearer <jwt-token>` 传递。

## 完整 curl

```bash
curl -sS -X POST "http://127.0.0.1:9600/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"login_type":"sms_code","phone":"13800010001","code":"123456"}'
```
