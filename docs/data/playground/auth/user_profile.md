# GET /user/profile 测试记录

## 接口信息

- 方法：`GET`
- 路径：`/user/profile`
- 完整地址：`http://127.0.0.1:9600/user/profile`
- 用途：从请求头里的 Token 解析 `user_id`，返回模拟用户资料

## 请求头要求

推荐使用：

```text
Authorization: Bearer <token>
```

## curl 模板

先调用 `/auth/login` 拿到 token，再替换到下面命令里：

```bash
curl -s -i http://127.0.0.1:9600/user/profile \
  -H 'Authorization: Bearer 替换成实际token'
```

## 本次实际验证

- 验证时间：`2026-06-03`
- 前置条件：已先调用 `/auth/login`，拿到可用 token
- 测试目标：验证有效 token 能返回资料，无 token 或非法 token 返回 `401`

### 成功案例

#### 实际执行命令

```bash
curl -s -i http://127.0.0.1:9600/user/profile \
  -H 'Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJleHAiOjE3ODA1ODA5NTR9.FyrwotLMPsNSLSQH2zNiFoUeBdhkdfOagtZ8tUjTnVM'
```

#### 实际返回结果

```http
HTTP/1.1 200 OK
content-type: application/json; charset=utf-8
content-length: 127
date: Wed, 03 Jun 2026 13:49:22 GMT

{"user_id":1,"nickname":"13800138000","avatar":"https://picsum.photos/seed/16202134045674204030/120/120","phone":"13800138000"}
```

### 失败案例一：缺少 token

#### 实际执行命令

```bash
curl -s -i http://127.0.0.1:9600/user/profile
```

#### 实际返回结果

```http
HTTP/1.1 401 Unauthorized
content-type: application/json; charset=utf-8
content-length: 27
date: Wed, 03 Jun 2026 13:49:09 GMT

{"message":"missing token"}
```

### 失败案例二：非法 token

#### 实际执行命令

```bash
curl -s -i http://127.0.0.1:9600/user/profile \
  -H 'Authorization: Bearer invalid-token'
```

#### 实际返回结果

```http
HTTP/1.1 401 Unauthorized
content-type: application/json; charset=utf-8
content-length: 27
date: Wed, 03 Jun 2026 13:49:22 GMT

{"message":"invalid token"}
```

## 结果判断

- 有效 token 时，接口成功返回 `user_id`、昵称、头像、手机号
- 缺少 token 时，接口返回 `401 Unauthorized`
- 非法 token 时，接口返回 `401 Unauthorized`

## 本接口结论

`GET /user/profile` 工作正常，鉴权逻辑符合预期：只有带有效 token 才能获取资料，缺失或无效 token 都会被拒绝。
