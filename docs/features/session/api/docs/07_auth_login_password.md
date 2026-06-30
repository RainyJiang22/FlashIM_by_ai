# 07 `/auth/login` 密码登录

## 基本信息

- 请求方法：`POST`
- 请求链接：`http://127.0.0.1:9600/auth/login`
- 鉴权要求：无

## 请求参数

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `login_type` | `string` | 是 | 固定为 `password` |
| `identifier` | `string` | 是 | 手机号或登录标识 |
| `password` | `string` | 是 | 已设置好的密码 |

请求体：

```json
{
  "login_type": "password",
  "identifier": "13818164147",
  "password": "new-password-2"
}
```

## 响应结果

```json
{
  "token": "<jwt-token>",
  "account_id": 2,
  "password_setup_required": false
}
```

说明：密码链路打通后，`password_setup_required` 会变成 `false`。

## 完整 curl

```bash
curl -sS -X POST "http://127.0.0.1:9600/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"login_type":"password","identifier":"13818164147","password":"new-password-2"}'
```
