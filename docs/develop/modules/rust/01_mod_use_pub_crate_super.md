# Rust 模块拆分：`mod`、`use`、`pub`、`crate`、`super`

这篇文档结合当前 `flash_im/server` 的实际代码，简单介绍 Rust 里最常用的模块拆分手段，以及文件之间如何导入和使用。

## 1. 先看当前项目的拆分结果

当前 `server/src` 已经从单文件拆成了这些模块：

```text
server/src/
├── main.rs
├── lib.rs
├── config.rs
├── error.rs
├── response.rs
├── state.rs
├── auth/
│   ├── mod.rs
│   └── jwt.rs
├── models/
│   ├── mod.rs
│   ├── auth.rs
│   ├── chat.rs
│   ├── common.rs
│   └── user.rs
├── routes/
│   ├── mod.rs
│   ├── auth.rs
│   ├── conversation.rs
│   ├── health.rs
│   ├── user.rs
│   └── ws.rs
├── services/
│   ├── mod.rs
│   ├── auth_service.rs
│   ├── chat_room_service.rs
│   └── user_service.rs
└── store/
    ├── mod.rs
    └── memory.rs
```

这个结构本质上是在做两件事：

- 用 `mod` 声明模块边界
- 用 `use` 引入外部类型、函数、模块路径

## 2. `mod` 是“声明这个模块存在”

Rust 不会自动把目录下的文件都变成模块，必须先声明。

例如 [server/src/lib.rs](/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/lib.rs:1)：

```rust
pub mod auth;
pub mod config;
pub mod error;
pub mod models;
pub mod response;
pub mod routes;
pub mod services;
pub mod state;
pub mod store;
```

这几行的意思是：

- 当前 crate 里有 `auth` 模块，对应 `auth/mod.rs`
- 有 `config` 模块，对应 `config.rs`
- 有 `models` 模块，对应 `models/mod.rs`

也就是说：

- `mod xxx;` 常见映射一：`src/xxx.rs`
- `mod xxx;` 常见映射二：`src/xxx/mod.rs`

在子目录里也是一样。比如 [server/src/routes/mod.rs](/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/routes/mod.rs:7)：

```rust
pub mod auth;
pub mod conversation;
pub mod health;
pub mod user;
pub mod ws;
```

它声明了：

- `routes::auth` 对应 `routes/auth.rs`
- `routes::ws` 对应 `routes/ws.rs`

## 3. `use` 是“把路径引进当前作用域”

`use` 不会创建模块，它只是为了少写长路径。

例如 [server/src/main.rs](/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/main.rs:1)：

```rust
use falsh_im::{
    build_app,
    config::{HOST, PORT, print_access_urls},
    state::AppState,
};
```

这里的含义是：

- 从 crate `falsh_im` 导入 `build_app`
- 从 `falsh_im::config` 导入 `HOST`、`PORT`、`print_access_urls`
- 从 `falsh_im::state` 导入 `AppState`

如果不写 `use`，也可以直接写完整路径：

```rust
let state = std::sync::Arc::new(falsh_im::state::AppState::new("secret"));
```

只是这样会比较长，所以一般会先 `use` 再使用。

## 4. `pub` 决定“能不能被外部访问”

Rust 默认是私有的。

例如在 [server/src/lib.rs](/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/lib.rs:1) 里：

```rust
pub mod routes;
```

如果这里没有 `pub`，那么外部就不能通过 `falsh_im::routes` 访问该模块。

再看 [server/src/auth/jwt.rs](/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/auth/jwt.rs:7)：

```rust
pub(crate) fn sign_token(...)
pub(crate) fn decode_token(...)
pub fn extract_token(...)
fn unix_timestamp() -> u64
```

这里体现了 Rust 很实用的一套可见性控制：

- `pub`：对外公开，crate 外也能访问
- `pub(crate)`：只在当前 crate 内可见，适合内部基础能力
- 不写：只在当前模块内可见

这几个级别很适合做边界收口：

- `extract_token` 可以公开给路由层用
- `sign_token`、`decode_token` 只给当前 crate 内部业务使用
- `unix_timestamp` 只是 `jwt.rs` 内部辅助函数，不必暴露

## 5. `crate::` 表示“从当前 crate 根开始找”

在多文件项目里，`crate::` 很常用，也很稳。

例如 [server/src/auth/jwt.rs](/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/auth/jwt.rs:5)：

```rust
use crate::{config::JWT_TTL, models::auth::AuthClaims, state::AppState};
```

这里的 `crate::` 表示：

- 从当前 crate 的根模块开始找
- 当前 crate 的根，在这个项目里就是 `lib.rs`

所以：

- `crate::config::JWT_TTL`
- `crate::models::auth::AuthClaims`
- `crate::state::AppState`

都属于“从整个工程根部往下找”的写法。

这类写法适合：

- 跨目录引用
- 公共模块引用
- 避免相对路径在文件移动后变得难读

## 6. `super::` 表示“从父模块开始找”

`super::` 是相对路径，表示当前模块的上一层。

虽然当前这次重构里更偏向使用 `crate::`，但 `super::` 也很常见。假设你在 `routes/auth.rs` 里想访问同级的 `routes::user`，可以通过父级 `routes` 来中转：

```rust
use super::user;
```

它的语义是：

- 先回到父模块 `routes`
- 再找到 `user`

常见对比：

- `crate::routes::user`：从根开始，路径更完整
- `super::user`：从当前文件的父级开始，路径更短

经验上：

- 跨大模块时优先 `crate::`
- 同一个目录下的兄弟模块之间，可以考虑 `super::`

## 7. `main.rs` 和 `lib.rs` 分工

Rust 项目里，二进制入口和库入口经常会分开。

当前项目就是这个思路：

- [server/src/main.rs](/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/main.rs:1) 只负责启动服务
- [server/src/lib.rs](/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/lib.rs:12) 负责暴露 `build_app`

这样做的好处是：

- `main.rs` 很薄，便于阅读
- 测试可以直接调用库层能力
- 业务代码不和启动流程绑死

例如现在测试就直接写在 `lib.rs` 下的 `#[cfg(test)] mod tests` 中，并调用：

```rust
let app = build_app(state);
```

这比在测试里硬依赖 `main.rs` 更自然。

## 8. 为什么会有这么多 `mod.rs`

像 `auth/mod.rs`、`routes/mod.rs`、`models/mod.rs` 这种文件，通常承担的是“目录入口”角色。

以 [server/src/routes/mod.rs](/Users/rainyjiang/AndroidStudioProjects/flash_im/server/src/routes/mod.rs:1) 为例，它做了两件事：

- 声明 `routes` 目录下有哪些子模块
- 提供 `build_router()` 作为这个目录的统一出口

所以 `mod.rs` 很像这个目录的“门面文件”。

适合放在 `mod.rs` 的内容：

- 子模块声明
- 当前模块的聚合入口
- 少量模块级公共函数

不适合放太多具体业务实现，否则会再次长胖。

## 9. 当前这个项目里的拆分思路

这次 `server` 的拆分不是随便按文件名切，而是按职责切：

- `routes/`：只放 HTTP 或 WebSocket 协议入口
- `services/`：只放业务动作
- `store/`：只放内存存储细节
- `models/`：只放请求、响应、事件、记录结构
- `auth/`：只放 JWT 相关能力

这种拆法的关键收益是：

- handler 不再直接操作所有 `RwLock<HashMap<...>>`
- 存储实现不再散落在多个 handler 里
- 后续如果换数据库，优先改 `store/` 和 `services/`

## 10. 一个简单判断：什么时候该拆文件

在 Rust 项目里，通常出现下面这些信号时，就该拆模块了：

- 一个文件同时包含路由、状态、模型、工具函数、测试
- 某个文件已经超过自己明确的单一职责
- 多个函数总是一起修改，说明它们属于同一领域模块
- `use` 区域越来越大，而且一眼看不出这个文件到底负责什么

对于当前项目，原来的 `main.rs` 就是典型例子，所以才拆成了现在的结构。

## 11. 新手最常见的几个误区

- 误区一：以为创建了 `xxx.rs` 就自动成为模块。  
  实际上还需要上层写 `mod xxx;`

- 误区二：把 `use` 当成“创建模块”。  
  实际上 `use` 只是导入路径别名

- 误区三：所有函数都写 `pub`。  
  实际上可见性越小越安全，优先默认私有，再按需开放

- 误区四：到处都写很长的相对路径。  
  实际上跨模块时优先 `crate::`，可读性通常更稳定

## 12. 一套够用的实践建议

- 根模块用 `lib.rs` 做总装配
- 子目录用 `mod.rs` 管理内部模块
- 跨模块引用优先用 `crate::`
- 只在同层级、短距离引用时考虑 `super::`
- 默认私有，按需开放 `pub(crate)` 和 `pub`
- `main.rs` 尽量只保留启动逻辑

如果后面你愿意，我可以继续写第二篇，把当前 `server/src` 每个模块之间的依赖关系也画成一张简图，放到 `docs/develop/modules/rust/02_*.md`。
