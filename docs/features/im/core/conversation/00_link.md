# Conversation API Test Link

`docs/features/im/core/conversation` 统一维护 IM 会话列表模块的接口文档、测试链和参考脚本。

- 基础地址：`http://127.0.0.1:9600`
- 验证时间：`2026-07-07`
- 主测试链文档：[request/test_lnk.md](request/test_lnk.md)
- 参考脚本：[`scripts/server/conversation_api_test_link.sh`](../../../../../scripts/server/conversation_api_test_link.sh)
- 维护角色：[link_test_writer](roles/link_test_writer.md)

| 序号 | 状态 | 动作 | 接口文档 | 测试结果 |
| --- | --- | --- | --- | --- |
| 01 | 已验证 | 会话列表未鉴权拦截 | [01_conversations_unauthorized.md](docs/01_conversations_unauthorized.md) | [跳转](request/test_lnk.md#step-01) |
| 02 | 已验证 | 获取短信验证码 | [02_auth_sms.md](docs/02_auth_sms.md) | [跳转](request/test_lnk.md#step-02) |
| 03 | 已验证 | 短信验证码登录 | [03_auth_login_sms.md](docs/03_auth_login_sms.md) | [跳转](request/test_lnk.md#step-03) |
| 04 | 已验证 | 查询会话列表第一页 | [04_conversations_list.md](docs/04_conversations_list.md) | [跳转](request/test_lnk.md#step-04) |
| 05 | 已验证 | 查询会话列表分页 | [05_conversations_pagination.md](docs/05_conversations_pagination.md) | [跳转](request/test_lnk.md#step-05) |
| 06 | 已验证 | 非法分页参数校验 | [06_conversations_invalid_query.md](docs/06_conversations_invalid_query.md) | [跳转](request/test_lnk.md#step-06) |

## 链路说明

1. `01`：先确认正式会话接口 `GET /conversations` 必须登录态访问。
2. `02 -> 03`：通过短信验证码登录拿到 `token`。
3. `03 -> 04 -> 05`：复用登录态查询会话列表第一页和后续分页。
4. `06`：复用登录态验证非法分页参数会返回业务错误。

## 接口边界

- 正式会话列表接口：`GET /conversations`，由 `server/modules/im-conversation` 提供。
- 旧演示接口：`GET /conversation`，仍存在于 `server/src/routes/conversation.rs`，只用于 playground/mock，不作为当前正式会话接口文档入口。

## 维护约定

1. `request/test_lnk.md` 维护可执行测试链和链路结果。
2. `docs/*.md` 每个测试步骤一份独立接口文档，按顺序编号。
3. 读者如果要本地复跑，优先使用 `scripts/server/conversation_api_test_link.sh`。
