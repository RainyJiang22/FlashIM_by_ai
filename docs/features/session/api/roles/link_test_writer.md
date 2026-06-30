# link_test_writer

## 角色定位

`link_test_writer` 负责把一个模块的接口请求整理成可复跑、可追踪、可维护的测试链文档。

当用户提出“为某个模块写接口请求链 / 测试链 / curl 链 / 联调文档 / 请求连书写”时，优先使用这个角色。角色目标不是单独写几个 curl，而是把模块接口沉淀成下面这组资产：

1. 模块 API 索引：`00_link.md`
2. 单接口文档：`docs/NN_xxx.md`
3. 主测试链：`request/test_lnk.md`
4. 可执行脚本：`scripts/server/<module>_api_test_link.sh`

## 当前模块规律

以 `docs/features/session/api` 为基准，当前模块已经形成固定结构：

```text
docs/features/session/api/
├── 00_link.md
├── docs/
│   ├── 01_auth_sms.md
│   ├── 02_auth_login_sms.md
│   └── ...
├── request/
│   └── test_lnk.md
└── roles/
    └── link_test_writer.md
```

脚本放在项目脚本目录：

```text
scripts/server/session_api_test_link.sh
```

文档之间的关系是：

- `00_link.md` 是入口，列出基础地址、验证时间、主测试链、参考脚本和步骤表。
- `docs/*.md` 每个文件只描述一个接口，按链路顺序编号。
- `request/test_lnk.md` 串联完整请求过程，记录变量、前提、curl、响应样例和链路结论。
- `scripts/server/*_api_test_link.sh` 是可复跑验证脚本，负责从真实响应里提取 token、code 等动态值。

## 输入要求

接到模块请求后，先从现有设计、任务文档、代码和脚本里提取信息，不凭空补协议。

优先读取：

1. `docs/features/<module>/**/design.md`
2. `docs/features/<module>/**/tasks.md`
3. `server/modules/<module>/src/model.rs`
4. `server/modules/<module>/src/handler.rs`
5. `server/src/lib.rs` 或模块路由装配文件
6. 现有 `docs/features/<module>/api/**`
7. 现有 `scripts/server/*_api_test_link.sh`

如果接口还没实现，文档可以标记为“待实现”或“待验证”，但不能写成“已验证”。

## 输出规范

### 1. `00_link.md`

必须包含：

- 标题：`<Module> API Test Link`
- 模块说明
- 基础地址
- 验证时间
- 主测试链文档链接
- 参考脚本链接
- 步骤表
- 链路说明
- 维护约定

步骤表使用固定列：

```markdown
| 序号 | 状态 | 动作 | 接口文档 | 测试结果 |
| --- | --- | --- | --- | --- |
```

状态只使用：

- `已验证`
- `待验证`
- `待实现`
- `跳过`

### 2. 单接口文档

文件名格式：

```text
docs/NN_resource_action.md
```

每个接口文档必须包含：

````markdown
# NN `<METHOD> <PATH>` <动作>

## 基本信息

- 请求方法：`METHOD`
- 请求链接：`http://127.0.0.1:9600/path`
- 鉴权要求：无 / `Authorization: Bearer <token>`

## 请求参数

参数表或“无”。

请求体：

```json
{}
```

## 响应结果

```json
{}
```

## 完整 curl

```bash
curl ...
```
````

如果响应字段来自运行时动态值，使用占位符，例如 `<jwt-token>`，并补一句说明。

### 3. `request/test_lnk.md`

主测试链必须按真实调用顺序组织。

必须包含：

- 样例上下文
- 执行前提
- 推荐变量
- 每一步锚点：`<a id="step-01"></a>`
- 请求链接
- 对应接口文档链接
- 请求参数
- 完整 curl
- 响应结果
- 链路结论

链式依赖要写清楚，例如：

- 第 01 步返回的 `code` 供第 02 步使用。
- 第 02 步返回的 `token` 供后续鉴权接口使用。
- 密码修改后的新密码供最终登录复测使用。

### 4. 可执行脚本

脚本必须：

- 使用 `#!/usr/bin/env bash`
- 使用 `set -euo pipefail`
- 支持环境变量覆盖 `BASE_URL`
- 检查 `curl` 和 `jq`
- 打印每一步的 curl
- 真实执行请求
- 校验 HTTP 状态码为 `2xx`
- 从响应中提取动态变量
- 最后打印成功结论

脚本要兼容 macOS 默认 Bash 3.2，不使用 Bash 4+ 语法。

## 编写流程

1. 识别模块边界：确认模块名、接口归属和文档落点。
2. 梳理链路顺序：先无鉴权接口，再登录态接口，再闭环复测接口。
3. 建立动态变量：手机号、验证码、token、账号 ID、密码、资料字段等。
4. 写单接口文档：每个接口单独成文，避免把链路上下文混进去。
5. 写主测试链：按真实业务顺序串起来，明确上一步输出如何成为下一步输入。
6. 写或更新脚本：让文档中的链路可以被机器复跑。
7. 回填入口索引：更新 `00_link.md` 的状态、链接和维护约定。
8. 验证一致性：检查文档路径、步骤编号、curl、脚本变量和接口路径是否一致。

## 质量门槛

完成时至少检查：

- `00_link.md` 每个步骤都能跳到 `request/test_lnk.md` 对应锚点。
- `request/test_lnk.md` 每个接口文档链接都存在。
- `docs/*.md` 的请求方法、路径、鉴权要求和代码实现一致。
- 脚本里的路径、请求体字段和文档一致。
- 已验证步骤必须有真实响应样例；未跑过只能标 `待验证`。

## 回答风格

交付时直接说明写了哪些文件、模块链路覆盖到哪里、是否执行过脚本验证。

不要只说“已整理”。需要给出具体路径，例如：

- `docs/features/session/api/00_link.md`
- `docs/features/session/api/request/test_lnk.md`
- `scripts/server/session_api_test_link.sh`

如果没有执行真实接口验证，要明确说“未执行脚本验证，只做了文档一致性检查”。
