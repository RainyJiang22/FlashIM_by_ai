# Session API 测试用例链

这份文档维护一条可直接复跑的 session 后端测试链。链路按 `curl` 顺序执行，所有接口都基于本地后端 `http://127.0.0.1:9600`。

## 样例上下文

- 验证时间：`2026-06-29`
- 基础地址：`http://127.0.0.1:9600`
- 样例手机号：`13818164147`
- 样例账号：`account_id = 2`
- 样例昵称：`Alice`
- 样例签名：`hello`
- 样例头像：`identicon:new-seed`

## 执行前提

1. 后端已启动，并能访问 `http://127.0.0.1:9600/v`。
2. `server/.env` 或当前 shell 已配置 `DATABASE_URL`、`JWT_SECRET`。
3. `EXPOSE_DEBUG_SMS_CODE=true`，否则 `/auth/sms` 不会直接返回验证码。

## 推荐变量

```bash
BASE_URL="http://127.0.0.1:9600"
PHONE="13818164147"
TOKEN=""
CODE=""
NEW_PASSWORD="new-password"
CHANGED_PASSWORD="new-password-2"
```

<a id="step-01"></a>
## 01 获取短信验证码

- 请求链接：`POST /auth/sms`
- 接口文档：[01_auth_sms.md](../docs/01_auth_sms.md)

请求参数：

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `phone` | `string` | 是 | 手机号 |

完整 curl：

```bash
curl -sS -X POST "http://127.0.0.1:9600/auth/sms" \
  -H "Content-Type: application/json" \
  -d '{"phone":"13818164147"}'
```

响应结果：

```json
{
  "phone": "13818164147",
  "code": "088806"
}
```

<a id="step-02"></a>
## 02 短信验证码登录

- 请求链接：`POST /auth/login`
- 接口文档：[02_auth_login_sms.md](../docs/02_auth_login_sms.md)

请求参数：

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `login_type` | `string` | 是 | 固定为 `sms_code` |
| `phone` | `string` | 是 | 手机号 |
| `code` | `string` | 是 | 第 01 步返回的验证码 |

完整 curl：

```bash
curl -sS -X POST "http://127.0.0.1:9600/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"login_type":"sms_code","phone":"13818164147","code":"088806"}'
```

响应结果：

```json
{
  "token": "<jwt-token>",
  "account_id": 2,
  "password_setup_required": true
}
```

说明：`token` 为运行时动态值，后续第 03 到第 06 步都要复用。

<a id="step-03"></a>
## 03 查询当前用户资料

- 请求链接：`GET /user/profile`
- 接口文档：[03_user_profile_get.md](../docs/03_user_profile_get.md)

请求参数：

| 参数 | 位置 | 必填 | 说明 |
| --- | --- | --- | --- |
| `Authorization` | Header | 是 | `Bearer <token>` |

完整 curl：

```bash
curl -sS "http://127.0.0.1:9600/user/profile" \
  -H "Authorization: Bearer <jwt-token>"
```

响应结果：

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

<a id="step-04"></a>
## 04 更新当前用户资料

- 请求链接：`PUT /user/profile`
- 接口文档：[04_user_profile_put.md](../docs/04_user_profile_put.md)

请求参数：

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `Authorization` | `string` | 是 | `Bearer <token>` |
| `nickname` | `string` | 否 | 昵称，非空且最多 50 字符 |
| `avatar` | `string` | 否 | 头像地址，非空 |
| `signature` | `string` | 否 | 个性签名，最多 100 字符 |

完整 curl：

```bash
curl -sS -X PUT "http://127.0.0.1:9600/user/profile" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <jwt-token>" \
  -d '{"nickname":"Alice","signature":"hello","avatar":"identicon:new-seed"}'
```

响应结果：

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

<a id="step-05"></a>
## 05 首次设置密码

- 请求链接：`POST /user/password`
- 接口文档：[05_user_password_post.md](../docs/05_user_password_post.md)

请求参数：

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `Authorization` | `string` | 是 | `Bearer <token>` |
| `new_password` | `string` | 是 | 新密码，至少 6 个字符 |

完整 curl：

```bash
curl -sS -X POST "http://127.0.0.1:9600/user/password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <jwt-token>" \
  -d '{"new_password":"new-password"}'
```

响应结果：

```json
{
  "message": "password set successfully"
}
```

<a id="step-06"></a>
## 06 修改密码

- 请求链接：`PUT /user/password`
- 接口文档：[06_user_password_put.md](../docs/06_user_password_put.md)

请求参数：

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `Authorization` | `string` | 是 | `Bearer <token>` |
| `old_password` | `string` | 是 | 旧密码 |
| `new_password` | `string` | 是 | 新密码，至少 6 个字符 |

完整 curl：

```bash
curl -sS -X PUT "http://127.0.0.1:9600/user/password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <jwt-token>" \
  -d '{"old_password":"new-password","new_password":"new-password-2"}'
```

响应结果：

```json
{
  "message": "password changed successfully"
}
```

<a id="step-07"></a>
## 07 密码登录复测

- 请求链接：`POST /auth/login`
- 接口文档：[07_auth_login_password.md](../docs/07_auth_login_password.md)

请求参数：

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `login_type` | `string` | 是 | 固定为 `password` |
| `identifier` | `string` | 是 | 手机号或登录标识 |
| `password` | `string` | 是 | 第 06 步的新密码 |

完整 curl：

```bash
curl -sS -X POST "http://127.0.0.1:9600/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"login_type":"password","identifier":"13818164147","password":"new-password-2"}'
```

响应结果：

```json
{
  "token": "<jwt-token>",
  "account_id": 2,
  "password_setup_required": false
}
```

## 链路结论

1. 短信验证码登录链路可用。
2. 登录态下的用户资料查询和资料修改可用。
3. 首次设置密码和修改密码可用。
4. 修改后的密码可再次登录，session 链路闭环完成。
