<p align="center">
  <img src="./client/assets/branding/flash_im_logo_alpha.png" width="120" alt="Flash IM Logo" />
</p>

<h1 align="center">Flash IM（轻聊）</h1>

<p align="center">
  使用 Flutter、Rust、Axum、PostgreSQL 与 Protobuf WebSocket 构建的全栈即时通讯项目。
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.41.7-02569B?logo=flutter&logoColor=white" alt="Flutter 3.41.7" />
  <img src="https://img.shields.io/badge/Dart-3.11.5+-0175C2?logo=dart&logoColor=white" alt="Dart 3.11.5+" />
  <img src="https://img.shields.io/badge/Rust-2024-000000?logo=rust&logoColor=white" alt="Rust 2024" />
  <img src="https://img.shields.io/badge/Axum-0.8-6F4E37" alt="Axum 0.8" />
  <img src="https://img.shields.io/badge/PostgreSQL-required-4169E1?logo=postgresql&logoColor=white" alt="PostgreSQL" />
  <img src="https://img.shields.io/badge/status-active_development-F59E0B" alt="Active development" />
</p>

> [!IMPORTANT]
> 本项目处于持续开发阶段，适合学习、功能验证和二次开发，尚未按生产环境标准完成安全、部署与全平台验收。

## 项目简介

Flash IM 是一个客户端与服务端同仓维护的即时通讯项目。客户端采用 Flutter 与 Cubit/Bloc，服务端采用 Rust、Axum、Tokio 和 SQLx；业务数据写入 PostgreSQL，实时消息通过经过 JWT 认证的 Protobuf WebSocket 传输。

项目不只包含聊天页面，还覆盖账号与会话恢复、好友关系、单聊、群聊治理、在线状态、已读回执、媒体消息、本地文件存储与综合搜索链路。

## 当前完成度

状态说明：✅ 已接入主链路　🚧 开发中　🧪 调试/验证工具

| 系统 | 状态 | 当前能力 |
| --- | :---: | --- |
| 用户与认证 | ✅ | 短信验证码登录、密码登录、JWT 鉴权、登录态恢复、资料编辑、设置与修改密码 |
| 好友系统 | ✅ | 用户搜索、好友申请、收到/发出记录、接受/拒绝/撤回、删除好友、字母索引通讯录 |
| 会话系统 | ✅ | 单聊/群聊会话创建、列表与详情、分页、未读数、标记已读、实时会话更新；首页长按可隐藏会话并保留聊天记录，新消息到达后自动恢复显示 |
| 消息系统 | ✅ | 文本、图片、视频和文件消息，历史记录、发送确认、失败重试、媒体预览与下载 |
| 实时与状态 | ✅ | JWT WebSocket 认证、断线重连、心跳、好友在线状态、多端在线语义、消息已读回执 |
| 群聊系统 | ✅ | 建群、群搜索与加入、邀请/审批、群成员与管理员、群昵称、公告、转让、退出、移除与解散 |
| 群聊增强 | ✅ | 群系统消息、邀请卡片、九宫格群头像、`@成员`、`@所有人`、群消息已读成员明细 |
| 综合搜索 | ✅ | 联系人、已加入群、跨会话聊天记录与会话内消息搜索；支持搜索历史、关键词高亮、分区重试和结果导航 |
| Playground | 🧪 | 认证、会话、WebSocket 心跳与广播聊天室的独立调试页面和接口样例 |

当前没有实现或没有完成生产化验收的能力包括：音视频通话、语音消息、消息撤回/转发、推送通知、端到端加密、对象存储、集群部署、后台管理，以及所有 Flutter 目标平台的完整兼容性验证。

## 技术栈

| 层级 | 技术 |
| --- | --- |
| 客户端 | Flutter、Dart、Material 3、flutter_bloc、Dio、web_socket_channel |
| 服务端 | Rust 2024、Axum、Tokio、SQLx、Serde |
| 实时协议 | WebSocket + Protocol Buffers |
| 数据与认证 | PostgreSQL、JWT、Argon2 |
| 媒体能力 | image_picker、file_picker、video_player、本地文件存储 |
| 测试 | flutter_test、bloc_test、mocktail、Cargo Test、Tokio Test |

## 系统架构

```mermaid
flowchart LR
    subgraph Client[Flutter Client]
        App[App Shell]
        Features[Auth / Session / Friend / Group / Chat / Search]
        WSClient[Protobuf WebSocket Client]
        App --> Features
        App --> WSClient
    end

    subgraph Server[Rust Axum Server]
        Router[HTTP + WebSocket Router]
        Modules[Auth / User / Conversation / Message / Friend / Group]
        Storage[Local Media Storage]
        Router --> Modules
        Router --> Storage
    end

    DB[(PostgreSQL)]

    Features -->|REST + JWT| Router
    WSClient <-->|Binary Protobuf Frames| Router
    Modules -->|SQLx| DB
```

服务端按 `routes -> service -> repository` 分层；客户端将认证、会话、聊天、好友、群聊、搜索等能力拆为本地 packages，由宿主应用负责依赖注入、路由和跨模块接线。

## 项目结构

```text
flash_im/
├── client/                    # Flutter 宿主应用
│   ├── lib/                   # 应用装配、首页、路由与 Playground
│   ├── modules/               # 可独立测试的业务 packages
│   │   ├── flash_auth/
│   │   ├── flash_session/
│   │   ├── flash_im_core/
│   │   ├── flash_im_conversation/
│   │   ├── flash_im_chat/
│   │   ├── flash_im_friend/
│   │   ├── flash_im_group/
│   │   ├── flash_im_search/
│   │   ├── flash_shared/
│   │   └── flash_starter/
│   └── test/                  # 宿主应用测试
├── server/                    # Rust workspace 与服务端入口
│   ├── modules/               # 服务端领域模块
│   ├── migrations/            # SQLx 数据库迁移
│   ├── src/                   # Router、运行入口与集成测试
│   └── tests/                 # 跨模块集成测试
├── proto/                     # WebSocket Protobuf 协议源文件
├── docs/                      # 分版本的分析、设计、任务和 API 验证文档
└── scripts/                   # 开发辅助脚本
```

## 快速开始

### 1. 环境要求

- Flutter `3.41.7` 或兼容 Dart `>= 3.11.5 < 4.0.0` 的版本
- Rust `1.85+`（项目使用 Rust 2024 Edition）
- PostgreSQL；当前 migrations 会启用 `pgcrypto` 与 `pg_trgm` 扩展
- Android Studio、Xcode 或对应桌面平台工具链，按实际运行目标安装

### 2. 获取代码

```bash
git clone https://github.com/RainyJiang22/FlashIM_by_ai.git
cd FlashIM_by_ai
```

### 3. 准备 PostgreSQL

先创建本地数据库：

```bash
createdb flash_im
```

复制服务端配置并按本机数据库账号修改：

```bash
cd server
cp .env.example .env
```

至少确认以下配置可用：

```dotenv
DATABASE_URL=postgres://your_user:your_password@127.0.0.1:5432/flash_im
JWT_SECRET=replace-with-a-long-random-secret
JWT_TTL_SECS=86400
SMS_CODE_TTL_SECS=300
EXPOSE_DEBUG_SMS_CODE=true
```

> [!NOTE]
> 当前服务端不会自动加载 `.env`。启动前需要将配置导入当前 shell；服务连接数据库后会自动执行 `server/migrations/` 下的迁移。

### 4. 启动服务端

```bash
cd server
set -a
source .env
set +a
cargo run
```

默认监听 `0.0.0.0:9600`。可用健康接口确认服务已经启动：

```bash
curl http://127.0.0.1:9600/v
```

上传的图片、视频和文件默认写入 `server/uploads/`，并通过 `/uploads/*` 提供访问。

### 5. 启动 Flutter 客户端

另开一个终端：

```bash
cd client
flutter pub get
flutter run
```

客户端默认 API 地址为 `http://127.0.0.1:9600`，配置位于 [`client/lib/core/config/local_config_store.dart`](./client/lib/core/config/local_config_store.dart)。

不同运行目标的地址通常应这样设置：

| 运行目标 | API 地址示例 |
| --- | --- |
| iOS Simulator / macOS / Windows / Linux | `http://127.0.0.1:9600` |
| Android Emulator | `http://10.0.2.2:9600` |
| Android / iOS 真机 | `http://<开发电脑局域网 IP>:9600` |

真机与开发电脑需要位于可互访的网络中，并允许 `9600` 端口通过本机防火墙。WebSocket 地址会由客户端根据 API 地址自动转换为 `/ws/im`。

## 核心接口概览

用户、好友、会话、消息和群聊 REST 接口使用 `Authorization: Bearer <token>`；`/ws/im` 会在连接后的首个 Protobuf 帧中完成 JWT 认证。当前上传接口尚未接入鉴权。

| 领域 | 主要入口 |
| --- | --- |
| 健康检查 | `GET /v` |
| 认证 | `POST /auth/sms`、`POST /auth/login` |
| 用户 | `GET/PUT /user/profile`、`POST/PUT /user/password` |
| 会话 | `GET/POST /conversations`、`GET /conversations/{id}`、`GET /conversations/private/{peer_user_id}`、`POST /conversations/{id}/read`、`DELETE /conversations/{id}`（仅从首页隐藏） |
| 消息 | `GET /conversations/{id}/messages`、`GET /conversations/{id}/messages/{message_id}/read-status` |
| 好友 | `/api/users/*`、`/api/friends/*` |
| 群聊 | `/groups/*`、`/group-invitations/*` |
| 搜索 | `GET /api/friends/search`、`GET /api/conversations/search-joined-groups`、`GET /api/messages/search`、`GET /conversations/{id}/messages/search` |
| 文件 | `POST /api/upload/image`、`POST /api/upload/video`、`POST /api/upload/file` |
| 实时 IM | `GET /ws/im` |

接口行为、测试链和历史设计可从 [`docs/features/im/`](./docs/features/im/) 继续查看；`/ws` 与 `/chat_room/ws` 属于 Playground，正式 IM 链路使用 `/ws/im`。

## 开发与验证

### 服务端

以下命令均应在 `server/` 目录执行：

```bash
cargo fmt --all -- --check
cargo test --workspace
cargo clippy --workspace --all-targets -- -D warnings
```

涉及 PostgreSQL 的路由和集成测试需要先加载有效的服务端环境变量。仅运行内存单测不能替代真实数据库与 WebSocket 链路验证。

### 客户端

```bash
cd client
flutter analyze
flutter test
```

业务 package 有各自的测试目录，修改对应模块后应进入该 package 执行测试，例如：

```bash
cd client/modules/flash_im_chat
flutter test
```

## 开发约定

- 协议变更以根目录 `proto/*.proto` 为源，不直接手改生成的 Dart/Rust 协议代码。
- 服务端新业务保持 `routes -> service -> repository` 边界，并补齐权限校验与数据库测试。
- 客户端模块通过公开接口和回调协作，宿主应用负责跨模块路由，避免 package 之间形成循环依赖。
- 新功能按 `analysis.md -> design.md -> tasks.md -> tests/quality` 留存过程文档，并及时回写任务状态。
- 不要将真实 Token、短信验证码、数据库密码或生产 JWT Secret 提交到仓库。

## 安全与部署说明

- `EXPOSE_DEBUG_SMS_CODE=true` 只用于本地联调，生产环境必须关闭，并接入真实短信服务。
- 当前上传接口尚未接入身份认证与用户级配额控制，不应直接暴露到公网。
- 当前媒体文件保存在本机磁盘，不具备对象存储、CDN、备份和多实例一致性能力。
- 示例配置中的 JWT Secret 不能用于公网部署。
- 仓库目前没有提供 TLS、反向代理、容器编排、限流、监控告警和生产密钥管理方案。
- 在上述能力补齐并完成安全审计、压力测试和目标平台验收前，不应直接用于生产环境。
