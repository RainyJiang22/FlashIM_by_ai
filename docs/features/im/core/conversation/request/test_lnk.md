# Conversation API 测试用例链

这份文档维护一条可直接复跑的 IM 会话列表后端测试链。链路按 `curl` 顺序执行，所有接口都基于本地后端 `http://127.0.0.1:9600`。

## 样例上下文

- 验证时间：`2026-07-07`
- 基础地址：`http://127.0.0.1:9600`
- 样例手机号：`13800010001`
- 样例账号：`account_id = 2`
- 会话列表入口：`GET /conversations`
- 旧 mock 入口：`GET /conversation`，本链路不使用

## 执行前提

1. 后端已启动，并能访问 `http://127.0.0.1:9600/v`。
2. `server/.env` 或当前 shell 已配置 `DATABASE_URL`、`JWT_SECRET`。
3. `EXPOSE_DEBUG_SMS_CODE=true`，否则 `/auth/sms` 不会直接返回验证码。
4. 如需看到种子会话数据，先执行 `scripts/database/seed_im_conversations.sh`。

## 推荐变量

```bash
BASE_URL="http://127.0.0.1:9600"
PHONE="13800010001"
TOKEN=""
CODE=""
```

<a id="step-01"></a>
## 01 会话列表未鉴权拦截

- 请求链接：`GET /conversations?limit=20&offset=0`
- 接口文档：[01_conversations_unauthorized.md](../docs/01_conversations_unauthorized.md)
- 预期状态码：`401`

请求参数：

| 参数 | 位置 | 必填 | 说明 |
| --- | --- | --- | --- |
| `limit` | Query | 否 | 每页数量 |
| `offset` | Query | 否 | 分页偏移量 |

完整 curl：

```bash
curl -sS "http://127.0.0.1:9600/conversations?limit=20&offset=0"
```

响应结果：

```json
{
  "message": "missing token"
}
```

<a id="step-02"></a>
## 02 获取短信验证码

- 请求链接：`POST /auth/sms`
- 接口文档：[02_auth_sms.md](../docs/02_auth_sms.md)

请求参数：

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `phone` | `string` | 是 | 手机号 |

完整 curl：

```bash
curl -sS -X POST "http://127.0.0.1:9600/auth/sms" \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800010001"}'
```

响应结果：

```json
{
  "phone": "13800010001",
  "code": "123456"
}
```

说明：第 02 步返回的 `code` 供第 03 步使用。

<a id="step-03"></a>
## 03 短信验证码登录

- 请求链接：`POST /auth/login`
- 接口文档：[03_auth_login_sms.md](../docs/03_auth_login_sms.md)

请求参数：

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `login_type` | `string` | 是 | 固定为 `sms_code` |
| `phone` | `string` | 是 | 第 02 步手机号 |
| `code` | `string` | 是 | 第 02 步验证码 |

完整 curl：

```bash
curl -sS -X POST "http://127.0.0.1:9600/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"login_type":"sms_code","phone":"13800010001","code":"123456"}'
```

响应结果：

```json
{
  "token": "<jwt-token>",
  "account_id": 2,
  "password_setup_required": true
}
```

说明：第 03 步返回的 `token` 供第 04 到第 06 步使用。

<a id="step-04"></a>
## 04 查询会话列表第一页

- 请求链接：`GET /conversations?limit=20&offset=0`
- 接口文档：[04_conversations_list.md](../docs/04_conversations_list.md)

请求参数：

| 参数 | 位置 | 必填 | 说明 |
| --- | --- | --- | --- |
| `Authorization` | Header | 是 | `Bearer <token>` |
| `limit` | Query | 否 | 每页数量 |
| `offset` | Query | 否 | 分页偏移量 |

完整 curl：

```bash
curl -sS "http://127.0.0.1:9600/conversations?limit=20&offset=0" \
  -H "Authorization: Bearer <jwt-token>"
```

响应结果：

```json
[
  {
    "id": "<conversation-uuid>",
    "type": 0,
    "name": null,
    "peer_user_id": "3",
    "peer_nickname": "胭脂",
    "peer_avatar": "color:#C03F3C",
    "last_message_at": "2026-07-07T08:00:00Z",
    "last_message_preview": "今天的接口联调先看会话列表。",
    "unread_count": 3,
    "created_at": "2026-07-07T08:00:00Z"
  }
]
```

<a id="step-05"></a>
## 05 查询会话列表分页

- 请求链接：`GET /conversations?limit=5&offset=5`
- 接口文档：[05_conversations_pagination.md](../docs/05_conversations_pagination.md)

请求参数：

| 参数 | 位置 | 必填 | 说明 |
| --- | --- | --- | --- |
| `Authorization` | Header | 是 | `Bearer <token>` |
| `limit` | Query | 否 | 本步骤使用 `5` |
| `offset` | Query | 否 | 本步骤使用 `5` |

完整 curl：

```bash
curl -sS "http://127.0.0.1:9600/conversations?limit=5&offset=5" \
  -H "Authorization: Bearer <jwt-token>"
```

响应结果：

```json
[
  {
    "id": "<conversation-uuid>",
    "type": 0,
    "name": null,
    "peer_user_id": "8",
    "peer_nickname": "酡颜",
    "peer_avatar": "color:#F9906F",
    "last_message_at": "2026-07-07T06:30:00Z",
    "last_message_preview": "会话模块先不接消息收发。",
    "unread_count": 2,
    "created_at": "2026-07-07T06:30:00Z"
  }
]
```

<a id="step-06"></a>
## 06 非法分页参数校验

- 请求链接：`GET /conversations?limit=0&offset=0`
- 接口文档：[06_conversations_invalid_query.md](../docs/06_conversations_invalid_query.md)
- 预期状态码：`400`

请求参数：

| 参数 | 位置 | 必填 | 说明 |
| --- | --- | --- | --- |
| `Authorization` | Header | 是 | `Bearer <token>` |
| `limit` | Query | 否 | 必须大于等于 `1` |
| `offset` | Query | 否 | 必须大于等于 `0` |

完整 curl：

```bash
curl -sS "http://127.0.0.1:9600/conversations?limit=0&offset=0" \
  -H "Authorization: Bearer <jwt-token>"
```

响应结果：

```json
{
  "message": "invalid limit"
}
```

## 链路结论

1. `GET /conversations` 是当前正式会话列表入口，需要登录态。
2. 短信登录后可通过 `Authorization: Bearer <token>` 查询当前账号可见会话。
3. `limit` 和 `offset` 由后端统一归一化：默认 `20/0`，`limit` 最大 `100`，非法值返回 `400`。
4. `/conversation` 是旧 mock 接口，本链路不作为正式会话接口使用。

## 本轮验证记录

- 验证时间：`2026-07-07`
- 验证命令：`scripts/server/conversation_api_test_link.sh`
- 基础地址：`http://127.0.0.1:9600`
- 样例手机号：`13800010001`
- 验证结果：脚本执行成功，完成 `401` 鉴权拦截、短信验证码登录、第一页会话列表、分页列表、非法 `limit` 返回 `400` 的闭环检查。
