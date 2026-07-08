# Conversation API Test Link

`docs/features/im/core/conversation` 统一维护 IM 会话模块的接口文档、测试链和参考脚本。

- 基础地址：`http://127.0.0.1:9600`
- 验证时间：`2026-07-08`
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
| 07 | 已验证 | 单会话详情未鉴权拦截 | [07_conversation_detail_unauthorized.md](docs/07_conversation_detail_unauthorized.md) | [跳转](request/test_lnk.md#step-07) |
| 08 | 已验证 | 标记已读未鉴权拦截 | [08_conversation_read_unauthorized.md](docs/08_conversation_read_unauthorized.md) | [跳转](request/test_lnk.md#step-08) |
| 09 | 已验证 | 历史消息未鉴权拦截 | [09_conversation_messages_unauthorized.md](docs/09_conversation_messages_unauthorized.md) | [跳转](request/test_lnk.md#step-09) |
| 10 | 已验证 | 查询单会话详情 | [10_conversation_detail.md](docs/10_conversation_detail.md) | [跳转](request/test_lnk.md#step-10) |
| 11 | 已验证 | 标记会话已读 | [11_conversation_mark_read.md](docs/11_conversation_mark_read.md) | [跳转](request/test_lnk.md#step-11) |
| 12 | 已验证 | 确认会话未读数归零 | [12_conversation_detail_after_read.md](docs/12_conversation_detail_after_read.md) | [跳转](request/test_lnk.md#step-12) |
| 13 | 已验证 | 查询历史消息 | [13_conversation_messages_list.md](docs/13_conversation_messages_list.md) | [跳转](request/test_lnk.md#step-13) |
| 14 | 已验证 | 历史消息分页 | [14_conversation_messages_pagination.md](docs/14_conversation_messages_pagination.md) | [跳转](request/test_lnk.md#step-14) |
| 15 | 已验证 | 非法历史消息参数校验 | [15_conversation_messages_invalid_query.md](docs/15_conversation_messages_invalid_query.md) | [跳转](request/test_lnk.md#step-15) |

## 链路说明

1. `01`：先确认正式会话接口 `GET /conversations` 必须登录态访问。
2. `02 -> 03`：通过短信验证码登录拿到 `token`。
3. `03 -> 04 -> 05`：复用登录态查询会话列表第一页和后续分页，并从第 04 步提取 `conversation_id`。
4. `06`：复用登录态验证非法分页参数会返回业务错误。
5. `07 -> 09`：覆盖新增会话详情、已读和历史消息接口的未鉴权拦截。
6. `10 -> 12`：查询单会话详情、标记已读、再次查询确认 `unread_count = 0`。
7. `13 -> 15`：查询历史消息、验证 `before_seq` 分页和非法参数。

## 接口边界

- 正式会话接口：
  - `GET /conversations`，由 `server/modules/im-conversation` 提供。
  - `GET /conversations/{id}`，由 `server/modules/im-conversation` 提供。
  - `POST /conversations/{id}/read`，由 `server/modules/im-conversation` 提供。
  - `GET /conversations/{id}/messages`，由 `server/modules/im-message` 提供。
- 旧演示接口：`GET /conversation`，仍存在于 `server/src/routes/conversation.rs`，只用于 playground/mock，不作为当前正式会话接口文档入口。

## 维护约定

1. `request/test_lnk.md` 维护可执行测试链和链路结果。
2. `docs/*.md` 每个测试步骤一份独立接口文档，按顺序编号。
3. 读者如果要本地复跑，优先使用 `scripts/server/conversation_api_test_link.sh`。
