# Playground `conversation` 模块 0 到 1 开发汇报

## 1. 背景

本次工作发生在 `2026-06-02`，目标是在 `client` 的 playground 中，从零开始完成一个可运行的 `conversation` 模块，并逐步把它从“网络请求演示单元”演进为“会话列表视图层”。

这次协作的特点是：

- 用户主要以自然语言聊天方式提出目标、调整方向
- AI 负责主动读取仓库、理解上下文、落代码、运行命令、验证结果
- 开发过程不是先给大方案再手工实现，而是边沟通边直接推进到可运行结果

## 2. 最终结果

当前 `conversation` 模块已经具备以下能力：

- 可以从 Rust 服务端的 `/conversation` 接口拉取会话数据
- 使用 `dio` 作为网络请求库
- 网络地址可配置，避免局域网 IP 变化导致代码反复修改
- 数据层、实体层、视图层已分离
- 在实体映射阶段为每条会话增加 `avatarUrl`
- 头像通过 `picsum` 按会话种子生成随机图片
- 默认应用入口已经切到 playground 列表
- `conversation` 已从“请求测试页”升级为“会话列表页”
- 已补充独立测试，并通过 `flutter test` 和 `flutter analyze`

## 3. 关键过程回顾

### 3.1 启动并验证后端服务

AI 首先没有直接写前端，而是先确认后端服务是否真实可用。

处理动作：

- 检查仓库结构，识别出 `server/` 是 Rust Axum 服务端
- 阅读 `server/src/main.rs`，确认后端实际监听端口是 `9600`
- 启动服务端并验证接口返回

关键结论：

- 文档里部分内容写的是 `8080`
- 代码实际监听的是 `9600`
- `/conversation` 接口可返回会话列表 JSON

这一步很重要，因为它避免了前端先开发、后发现接口地址不对的返工。

### 3.2 固化接口样本数据

在确认服务端可用后，AI 通过 `curl` 请求真实接口，并将结果保存到本地：

```text
docs/data/playground/conversation/list.json
```

这里有两次关键尝试：

- 第一次请求 `192.168.1.75:9600` 失败，对端重置连接
- 第二次改用 `192.168.25.116:9600` 成功，并落盘 JSON

这一步的重要价值：

- 形成了本地可复用的数据样本
- 后续可以直接据此补 fixture、写测试、对齐 UI
- 让“接口结构”从口头描述变成仓库中的稳定输入

### 3.3 从零搭建 `conversation` 网络请求单元

用户提出的第一阶段目标，是在 playground 中先做一个“简单网络请求单元”，名称叫 `conversation`。

AI 在这一阶段完成了基础分层：

- `core/config`：集中管理默认服务地址
- `core/network`：封装 `Dio` 工厂
- `domain`：定义 `ConversationEntity`
- `data`：定义 `ConversationRequest` 和 `DioConversationApi`
- `presentation`：构建可触发请求的页面

同时补充了独立测试：

- 通过本地 `HttpServer` 模拟 `/conversation`
- 将真实接口返回整理为 fixture
- 单测验证 `dio` 请求和 JSON 解析逻辑

这一阶段的意义不是把 UI 做完，而是先把“可请求、可配置、可测试”的技术骨架搭起来。

### 3.4 将默认应用入口切换到 playground

后续方向变化很快，用户要求直接把首页切到 playground 列表，而不是继续保留独立 `main_playground`。

AI 做了以下调整：

- 保留 `main.dart` 作为唯一默认入口
- 将 `FlashImApp` 的首页改为 `PlaygroundHomePage`
- 删除 `main_playground.dart`
- 删除 `FlashImPlaygroundApp`
- 删除已经失效的旧首页 `HomePage`
- 同步更新测试

这一步的关键点在于：

- 入口统一后，后续演练页面不再需要双入口维护
- playground 从“附属调试入口”转成“当前主开发入口”
- 让后面的 `conversation` 重构可以直接围绕默认首页展开

### 3.5 根据截图将模块升级为会话视图层

用户随后给出截图，目标从“请求单元”升级为“会话页面实现”。

这里 AI 做了一个明显的架构调整：把原来的“请求演示页”重构为真正的“列表视图页”。

重构后的分层：

- `data/models/conversation_dto.dart`
  - 只负责承接接口原始字段
- `data/conversation_api.dart`
  - 只负责请求 `/conversation`
- `data/conversation_repository.dart`
  - 负责 DTO -> Entity 映射
  - 负责补充 `avatarUrl`
- `domain/conversation_entity.dart`
  - 作为视图消费的稳定实体
- `presentation/conversation_playground_page.dart`
  - 作为会话页面容器
- `presentation/widgets/conversation_list_tile.dart`
  - 拆分单条会话 cell
- `presentation/widgets/conversation_bottom_navigation_bar.dart`
  - 拆分底部导航

这一步说明，AI 没有把所有逻辑都堆进一个页面文件，而是在用户给出新目标后继续保持结构清晰。

### 3.6 为每个会话增加随机头像

用户明确要求：

- 数据仍然从 `conversation` 接口获取
- 增加 `avatar` 字段
- 使用 `picsum` 随机图片

AI 的处理方式不是去修改后端接口，而是在 repository 映射阶段为每条会话生成头像地址：

```text
https://picsum.photos/seed/{seed}/120/120
```

其中 `seed` 基于“会话标题 + 索引”生成。

这么做有几个优点：

- 不破坏当前后端接口结构
- 保持前端可独立演练
- 每条会话头像稳定可复现，不会每次刷新完全乱掉
- 将“临时展示字段”控制在数据映射层，而不是污染接口层

### 3.7 持续验证而不是只改代码

整个过程里，每一个阶段都不是“写完就结束”，而是配套执行验证：

- 启动服务端并访问接口
- `curl` 请求并检查返回内容
- `dart format`
- `flutter test`
- `flutter analyze`

这说明 AI 在本次流程中承担的不只是代码生成，而是完整的执行闭环：

- 理解需求
- 实施改动
- 运行命令
- 发现问题
- 修正细节
- 再验证结果

## 4. 本次开发中比较重要的流程点

下面这些点，是本次从 0 到 1 最值得沉淀的方法论。

### 4.1 先验证真实依赖，再开发上层模块

不是先画页面，而是先确认后端能跑、接口真实可达、端口正确、返回结构明确。

如果跳过这一步，后面很容易出现：

- 请求地址错误
- 文档端口与代码端口不一致
- 前端先写死数据，后续对接返工

### 4.2 先落本地样本，再扩展测试和 UI

把真实返回先保存到：

```text
docs/data/playground/conversation/list.json
```

这使得后面三件事都变简单了：

- 写 fixture 有真实参考
- 测试不用凭空构造数据
- UI 可以围绕真实字段调整

### 4.3 先搭骨架，再做截图还原

本次不是一开始就还原微信列表，而是分两步：

1. 先搭建“请求单元”
2. 再重构成“会话视图层”

这种推进顺序比较稳，因为：

- 网络链路先打通
- 测试先具备
- 配置先抽离
- 后续再改 UI 时，不必重新处理网络基础设施

### 4.4 用户目标变化时，及时重构入口和结构

用户中途改变方向：

- 把默认首页切到 playground
- 删除 `main_playground`
- 将请求页升级为会话列表页

AI 没有在旧结构上硬补，而是及时做了两类整理：

- 入口整理：统一默认入口
- 模块整理：把 API、DTO、repository、entity、widgets 拆开

这保证了后续继续扩展时不会出现“演示代码越堆越乱”的问题。

### 4.5 临时展示字段放在 repository 层最合适

`avatarUrl` 并不是后端返回字段，而是本次为了 UI 演练新增的展示字段。

把它放在 repository 映射层处理，是这次实现中很关键的一个分层点：

- API 层保持纯净，只反映真实接口
- Entity 层得到可直接展示的数据
- UI 层不需要知道头像是后补的

这是一个很典型、也很值得复用的结构处理方式。

### 4.6 每个阶段都做自动验证

本次协作里，测试和分析不是最后才补，而是几乎每个阶段都紧跟执行。

这种方式的价值在于：

- 问题出现时更容易定位
- 用户每次改方向后都能快速确认没有引入回归
- 文档、代码、测试、运行状态保持同步

## 5. 本次产出清单

### 5.1 数据样本

- [docs/data/playground/conversation/list.json](/Users/rainyjiang/AndroidStudioProjects/flash_im/docs/data/playground/conversation/list.json)

### 5.2 核心前端代码

- [client/lib/core/config/playground_api_config.dart](/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/core/config/playground_api_config.dart)
- [client/lib/core/network/dio_factory.dart](/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/core/network/dio_factory.dart)
- [client/lib/playground/demos/conversation/data/models/conversation_dto.dart](/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/playground/demos/conversation/data/models/conversation_dto.dart)
- [client/lib/playground/demos/conversation/data/conversation_api.dart](/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/playground/demos/conversation/data/conversation_api.dart)
- [client/lib/playground/demos/conversation/data/conversation_repository.dart](/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/playground/demos/conversation/data/conversation_repository.dart)
- [client/lib/playground/demos/conversation/domain/conversation_entity.dart](/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/playground/demos/conversation/domain/conversation_entity.dart)
- [client/lib/playground/demos/conversation/presentation/conversation_playground_page.dart](/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/playground/demos/conversation/presentation/conversation_playground_page.dart)
- [client/lib/playground/demos/conversation/presentation/widgets/conversation_list_tile.dart](/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/playground/demos/conversation/presentation/widgets/conversation_list_tile.dart)
- [client/lib/playground/demos/conversation/presentation/widgets/conversation_bottom_navigation_bar.dart](/Users/rainyjiang/AndroidStudioProjects/flash_im/client/lib/playground/demos/conversation/presentation/widgets/conversation_bottom_navigation_bar.dart)

### 5.3 测试代码

- [client/test/playground/conversation/data/conversation_api_test.dart](/Users/rainyjiang/AndroidStudioProjects/flash_im/client/test/playground/conversation/data/conversation_api_test.dart)
- [client/test/playground/conversation/data/conversation_repository_test.dart](/Users/rainyjiang/AndroidStudioProjects/flash_im/client/test/playground/conversation/data/conversation_repository_test.dart)
- [client/test/playground/conversation/fixtures/conversation_list_fixture.json](/Users/rainyjiang/AndroidStudioProjects/flash_im/client/test/playground/conversation/fixtures/conversation_list_fixture.json)

## 6. 建议的后续事项

如果后续继续迭代这个模块，建议按下面顺序推进：

1. 将群聊九宫格头像、未读红点、静音图标等细节补齐
2. 把会话时间从静态字符串演进为更接近真实产品的格式化规则
3. 为会话列表增加 loading skeleton，而不只是转圈
4. 如果后端后续提供头像字段，再把 `picsum` 逻辑从 repository 中移除
5. 继续补 widget 测试，覆盖列表渲染和错误态

## 7. 一句话总结

这次 `conversation` 模块的完成过程，不是“AI 给建议，人工再落地”，而是“用户通过聊天给方向，AI 负责从仓库理解、服务验证、数据固化、代码实现、结构重构到测试校验的完整开发闭环”。
