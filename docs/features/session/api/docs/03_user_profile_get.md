# 03 `GET /user/profile`

## 基本信息

- 请求方法：`GET`
- 请求链接：`http://127.0.0.1:9600/user/profile`
- 鉴权要求：`Authorization: Bearer <token>`

## 请求参数

| 参数 | 位置 | 必填 | 说明 |
| --- | --- | --- | --- |
| `Authorization` | Header | 是 | 登录态 token |

## 响应结果

```json
{
  "account_id": 2,
  "nickname": "13818164147",
  "avatar": "identicon:2",
  "phone": "13818164147",
  "signature": "",
  "has_password": false
}
```

## 完整 curl

```bash
curl -sS "http://127.0.0.1:9600/user/profile" \
  -H "Authorization: Bearer <jwt-token>"
```
