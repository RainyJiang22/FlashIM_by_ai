# 04 `PUT /user/profile`

## 基本信息

- 请求方法：`PUT`
- 请求链接：`http://127.0.0.1:9600/user/profile`
- 鉴权要求：`Authorization: Bearer <token>`

## 请求参数

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `nickname` | `string` | 否 | 昵称，非空且最多 50 字符 |
| `avatar` | `string` | 否 | 头像地址，非空 |
| `signature` | `string` | 否 | 个性签名，最多 100 字符 |

请求体：

```json
{
  "nickname": "Alice",
  "signature": "hello",
  "avatar": "identicon:new-seed"
}
```

## 响应结果

```json
{
  "account_id": 2,
  "nickname": "Alice",
  "avatar": "identicon:new-seed",
  "phone": "13818164147",
  "signature": "hello",
  "has_password": false
}
```

## 完整 curl

```bash
curl -sS -X PUT "http://127.0.0.1:9600/user/profile" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <jwt-token>" \
  -d '{"nickname":"Alice","signature":"hello","avatar":"identicon:new-seed"}'
```
