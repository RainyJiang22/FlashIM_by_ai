# POST /auth/login 测试记录

## 接口信息

- 方法：`POST`
- 路径：`/auth/login`
- 完整地址：`http://127.0.0.1:9600/auth/login`
- 用途：接收手机号和验证码，验证码正确时返回 JWT `token` 和 `user_id`

## 请求体

```json
{
  "phone": "13800138000",
  "code": "526047"
}
```

## curl 模板

先调用 `/auth/sms` 拿到验证码，再把验证码替换到下面命令里：

```bash
curl -s -X POST http://127.0.0.1:9600/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"phone":"13800138000","code":"替换成实际验证码"}'
```

## 本次实际验证

- 验证时间：`2026-06-03`
- 前置条件：已先调用 `/auth/sms`，收到验证码 `526047`
- 测试目标：确认验证码登录成功后返回真实 JWT token 和 `user_id`

### 成功案例

#### 实际执行命令

```bash
curl -s -X POST http://127.0.0.1:9600/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"phone":"13800138000","code":"526047"}'
```

#### 实际返回结果

```json
{"token":"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJleHAiOjE3ODA1ODA5NTR9.FyrwotLMPsNSLSQH2zNiFoUeBdhkdfOagtZ8tUjTnVM","user_id":1}
```

### 失败案例

#### 实际执行命令

```bash
curl -s -i -X POST http://127.0.0.1:9600/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"phone":"13800138000","code":"000000"}'
```

#### 实际返回结果

```http
HTTP/1.1 401 Unauthorized
content-type: application/json; charset=utf-8
content-length: 37
date: Wed, 03 Jun 2026 13:49:14 GMT

{"message":"invalid or expired code"}
```

## 结果判断

- 正确验证码时，接口返回成功
- 响应中包含真实 JWT 字符串 `token`
- 响应中包含 `user_id`
- 错误验证码时，接口正确返回 `401 Unauthorized`

## 本接口结论

`POST /auth/login` 工作正常，已验证成功登录和错误验证码两种场景。成功返回的不是假字符串，而是可继续用于 `/user/profile` 验证的真实 JWT token。
