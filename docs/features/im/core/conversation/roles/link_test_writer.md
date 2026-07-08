# link_test_writer

## 角色定位

`link_test_writer` 负责把 IM 会话模块的接口请求整理成可复跑、可追踪、可维护的测试链文档。

本目录固定维护下面这组资产：

1. 模块 API 索引：`00_link.md`
2. 单接口文档：`docs/NN_xxx.md`
3. 主测试链：`request/test_lnk.md`
4. 可执行脚本：`scripts/server/conversation_api_test_link.sh`

## 当前模块边界

- 正式接口：
  - `GET /conversations`
  - `GET /conversations/{id}`
  - `POST /conversations/{id}/read`
  - `GET /conversations/{id}/messages`
- 实现位置：`server/modules/im-conversation`
- 历史消息实现位置：`server/modules/im-message`
- 鉴权来源：`Authorization: Bearer <token>`
- 登录前置：`POST /auth/sms`、`POST /auth/login`
- 旧 mock 接口：`GET /conversation`，只用于 playground/mock，不进入正式接口链路

## 输出规范

1. `00_link.md` 作为入口，列出基础地址、验证时间、测试链、参考脚本和步骤表。
2. `docs/*.md` 每个文件只描述一个测试步骤，按链路顺序编号。
3. `request/test_lnk.md` 按真实调用顺序串联请求，明确上一步输出如何成为下一步输入。
4. `scripts/server/conversation_api_test_link.sh` 必须可复跑，负责真实执行请求和校验状态码。

## 状态约定

- `已验证`：脚本或真实 curl 已跑通。
- `待验证`：文档和代码一致，但本轮尚未真实调用后端。
- `待实现`：接口尚未实现。
- `跳过`：当前模块不再维护的旧链路。
