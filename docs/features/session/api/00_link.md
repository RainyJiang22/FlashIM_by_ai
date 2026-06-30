# Session API Test Link

`docs/features/session/api` 统一维护 session 后端的接口文档、测试链和参考脚本。

- 基础地址：`http://127.0.0.1:9600`
- 验证时间：`2026-06-29`
- 主测试链文档：[request/test_lnk.md](request/test_lnk.md)
- 参考脚本：[`scripts/server/session_api_test_link.sh`](../../../../scripts/server/session_api_test_link.sh)
- 维护角色：[link_test_writer](roles/link_test_writer.md)

| 序号 | 状态 | 动作 | 接口文档 | 测试结果 |
| --- | --- | --- | --- | --- |
| 01 | 已验证 | 获取短信验证码 | [01_auth_sms.md](docs/01_auth_sms.md) | [跳转](request/test_lnk.md#step-01) |
| 02 | 已验证 | 短信验证码登录 | [02_auth_login_sms.md](docs/02_auth_login_sms.md) | [跳转](request/test_lnk.md#step-02) |
| 03 | 已验证 | 查询当前用户资料 | [03_user_profile_get.md](docs/03_user_profile_get.md) | [跳转](request/test_lnk.md#step-03) |
| 04 | 已验证 | 更新当前用户资料 | [04_user_profile_put.md](docs/04_user_profile_put.md) | [跳转](request/test_lnk.md#step-04) |
| 05 | 已验证 | 首次设置密码 | [05_user_password_post.md](docs/05_user_password_post.md) | [跳转](request/test_lnk.md#step-05) |
| 06 | 已验证 | 修改密码 | [06_user_password_put.md](docs/06_user_password_put.md) | [跳转](request/test_lnk.md#step-06) |
| 07 | 已验证 | 密码登录复测 | [07_auth_login_password.md](docs/07_auth_login_password.md) | [跳转](request/test_lnk.md#step-07) |

## 链路说明

1. `01 -> 02`：先取短信码，再完成短信登录。
2. `02 -> 03 -> 04`：拿到 `token` 后查询并更新资料。
3. `02 -> 05 -> 06`：用同一份登录态先设密码，再改密码。
4. `06 -> 07`：用新密码重新登录，确认密码链路闭环。

## 维护约定

1. `request/test_lnk.md` 维护可执行测试链和链路结果。
2. `docs/*.md` 每个测试步骤一份独立接口文档，按顺序编号。
3. 读者如果要本地复跑，优先使用 `scripts/server/session_api_test_link.sh`。
