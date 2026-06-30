# 06 `PUT /user/password`

## 基本信息

- 请求方法：`PUT`
- 请求链接：`http://127.0.0.1:9600/user/password`
- 鉴权要求：`Authorization: Bearer <token>`

## 请求参数

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `old_password` | `string` | 是 | 旧密码 |
| `new_password` | `string` | 是 | 新密码，至少 6 个字符 |

请求体：

```json
{
  "old_password": "new-password",
  "new_password": "new-password-2"
}
```

## 响应结果

```json
{
  "message": "password changed successfully"
}
```

## 完整 curl

```bash
curl -sS -X PUT "http://127.0.0.1:9600/user/password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <jwt-token>" \
  -d '{"old_password":"new-password","new_password":"new-password-2"}'
```
