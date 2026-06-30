# im-proto v0.0.1 — 服务端任务清单

基于 [design.md](./design.md) 设计，拆分 `server/` 侧协议生成实现步骤。目标是新增共享 `proto/ws.proto`，创建 `server/modules/im-ws` crate，并通过 `prost-build` 在 `cargo build` 时生成 Rust proto 代码。

全局约束：
- 本清单只覆盖服务端 proto 生成能力；客户端生成、业务 WebSocket handler、连接管理、帧分发、路由注册均不在本版本实现。
- 本版本只定义 `WsFrameType`、`WsFrame`、`AuthRequest`、`AuthResult`，不要新增 `message.proto` 或消息收发协议。
- 生成代码不提交 Git，只通过 `OUT_DIR` 在构建时生成。
- `proto/ws.proto` 放在项目根目录，作为前后端共享协议定义。
- 新 crate 目录按设计使用 `server/modules/im-ws/`；Rust crate 导入名由 Cargo 自动映射为 `im_ws`。
- 本机不要求预装系统 `protoc`；`im-ws` 通过构建期依赖 `protoc-bin-vendored` 固化 proto 编译器来源。

---

## 执行顺序

1. ✅ 任务 1 — `proto/ws.proto` 新增 WebSocket 基础帧协议（无依赖）
   - ✅ 1.1 创建根目录 `proto/`
   - ✅ 1.2 定义 `im` package、帧类型枚举和认证请求/响应消息
2. ✅ 任务 2 — `server/Cargo.toml` 接入 `im-ws` workspace member（依赖任务 1）
   - ✅ 2.1 workspace members 新增 `modules/im-ws`
   - ✅ 2.2 不把 `im-ws` 加到宿主运行时依赖，避免引入未使用业务入口
3. ✅ 任务 3 — `server/modules/im-ws/Cargo.toml` 创建 proto 生成 crate 配置（依赖任务 2）
   - ✅ 3.1 配置 package 元数据
   - ✅ 3.2 添加 `prost` 运行时依赖
   - ✅ 3.3 添加 `prost-build` 与 `protoc-bin-vendored` 构建依赖
4. ✅ 任务 4 — `server/modules/im-ws/build.rs` 配置 prost 编译流程（依赖任务 3）
   - ✅ 4.1 指向根目录 `proto/ws.proto`
   - ✅ 4.2 配置 `cargo:rerun-if-changed`
   - ✅ 4.3 调用 `prost_build::compile_protos`
5. ✅ 任务 5 — `server/modules/im-ws/src/{lib.rs,proto.rs}` 暴露生成代码入口（依赖任务 4）
   - ✅ 5.1 `lib.rs` 公开 `proto` 模块
   - ✅ 5.2 `proto.rs` include `OUT_DIR/im.rs`
   - ✅ 5.3 增加最小导出约定，供后续业务 crate 复用
6. ✅ 最后 — 格式化、编译验证与测试路径（依赖任务 1-5）
   - ✅ 6.1 `cd server && cargo fmt --check`
   - ✅ 6.2 `cd server && cargo build -p im-ws`
   - ✅ 6.3 `cd server && cargo test -p im-ws`

---

## 任务 1：`proto/ws.proto` — 新增 WebSocket 基础帧协议 `✅ 已完成`

文件：`proto/ws.proto`

改动类型：`新建`

### 1.1 创建根目录 proto 目录 `✅`

在项目根目录创建共享协议目录：

```text
proto/
└── ws.proto
```

说明：
- 该目录不放在 `server/` 内，后续客户端也复用同一份协议定义。

### 1.2 定义基础帧和认证协议 `✅`

关键 proto 骨架：

```protobuf
syntax = "proto3";
package im;

enum WsFrameType {
  PING = 0;
  PONG = 1;
  AUTH = 2;
  AUTH_RESULT = 3;
}

message WsFrame {
  WsFrameType type = 1;
  bytes payload = 2;
}

message AuthRequest {
  string token = 1;
}

message AuthResult {
  bool success = 1;
  string message = 2;
}
```

说明：
- 暂不加入消息、同步、好友、群聊、撤回、已读等 frame type。
- 后续版本新增 frame type 时按编号继续追加，不改已有编号语义。

---

## 任务 2：`server/Cargo.toml` — 接入 `im-ws` workspace member `✅ 已完成`

文件：`server/Cargo.toml`

改动类型：`配置修改`

### 2.1 workspace members 新增 `modules/im-ws` `✅`

关键配置骨架：

```toml
[workspace]
members = [
    ".",
    "modules/flash_core",
    "modules/flash_auth",
    "modules/flash_user",
    "modules/im-ws",
]
resolver = "2"
```

说明：
- 如果当前文件仍是单行 members，可只追加 `"modules/im-ws"`，不强制重排整个文件。

### 2.2 不新增宿主运行时依赖 `✅`

保持根 package `[dependencies]` 不新增：

```toml
# 本版本不要添加：
# im-ws = { path = "modules/im-ws" }
```

说明：
- 设计明确本版本不注册路由、不写业务逻辑；只验证 `im-ws` crate 自身可生成和编译。

---

## 任务 3：`server/modules/im-ws/Cargo.toml` — 创建 proto 生成 crate 配置 `✅ 已完成`

文件：`server/modules/im-ws/Cargo.toml`

改动类型：`新建`

### 3.1 配置 package 元数据 `✅`

关键配置骨架：

```toml
[package]
name = "im-ws"
version = "0.1.0"
edition = "2024"
build = "build.rs"
```

说明：
- package 名使用 `im-ws`，Rust 代码引用时 crate 名会映射为 `im_ws`。

### 3.2 添加 prost 运行时依赖 `✅`

关键配置骨架：

```toml
[dependencies]
prost = "0.14"
```

### 3.3 添加 prost-build 与 vendored protoc 构建依赖 `✅`

关键配置骨架：

```toml
[build-dependencies]
prost-build = "0.14"
protoc-bin-vendored = "3"
```

说明：
- 不额外添加 `tokio`、`axum`、`flash_core` 等业务依赖。
- 使用 `protoc-bin-vendored` 避免本机未安装 `protoc` 时构建失败。

---

## 任务 4：`server/modules/im-ws/build.rs` — 配置 prost 编译流程 `✅ 已完成`

文件：`server/modules/im-ws/build.rs`

改动类型：`新建`

### 4.1 指向根目录 proto 文件 `✅`

关键路径骨架：

```rust
use std::path::PathBuf;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let manifest_dir = PathBuf::from(std::env::var("CARGO_MANIFEST_DIR")?);
    let repo_root = manifest_dir
        .parent()
        .and_then(|path| path.parent())
        .and_then(|path| path.parent())
        .ok_or("failed to resolve repo root")?;
    let proto_file = repo_root.join("proto/ws.proto");
    let proto_dir = repo_root.join("proto");

    // compile...
    Ok(())
}
```

说明：
- `CARGO_MANIFEST_DIR` 指向 `server/modules/im-ws`，需要向上回到项目根目录再访问 `proto/`。

### 4.2 配置重新生成触发条件 `✅`

关键代码骨架：

```rust
println!("cargo:rerun-if-changed={}", proto_file.display());
println!("cargo:rerun-if-changed={}", proto_dir.display());
```

### 4.3 调用 prost-build 编译 `✅`

关键代码骨架：

```rust
let protoc = protoc_bin_vendored::protoc_bin_path()?;
let mut config = prost_build::Config::new();
config.protoc_executable(protoc);
config.compile_protos(&[proto_file], &[proto_dir])?;
```

说明：
- 不自定义输出目录，保持 prost 默认写入 `OUT_DIR`。

---

## 任务 5：`server/modules/im-ws/src/{lib.rs,proto.rs}` — 暴露生成代码入口 `✅ 已完成`

文件：
- `server/modules/im-ws/src/lib.rs`
- `server/modules/im-ws/src/proto.rs`

改动类型：`新建`

### 5.1 `lib.rs` 公开 proto 模块 `✅`

关键代码骨架：

```rust
pub mod proto;
```

### 5.2 `proto.rs` include 生成代码 `✅`

关键代码骨架：

```rust
include!(concat!(env!("OUT_DIR"), "/im.rs"));
```

说明：
- `package im;` 对应 prost 生成文件名 `im.rs`。

### 5.3 保持模块职责单一 `✅`

本任务不要新增：

```rust
// 不要在本版本添加：
// pub mod handler;
// pub mod dispatcher;
// pub mod state;
// pub fn router(...)
```

说明：
- 本版本只保证协议定义可被 Rust 编译和引用。

---

## 任务 6：编译验证与测试路径 `✅ 已完成`

文件：无单一目标文件，验证 `proto/` 与 `server/modules/im-ws/` 整体可用。

改动类型：`验证`

### 6.1 Rust 格式检查 `✅`

执行：

```bash
cd server && cargo fmt --check
```

### 6.2 指定 crate 编译验证 `✅`

执行：

```bash
cd server && cargo build -p im-ws
```

期望：
- `prost-build` 能找到 `proto/ws.proto`。
- `OUT_DIR/im.rs` 能成功生成。
- `server/modules/im-ws/src/proto.rs` 能成功 include 生成代码。

### 6.3 指定 crate 测试验证 `✅`

执行：

```bash
cd server && cargo test -p im-ws
```

说明：
- 本版本没有业务测试时，`cargo test -p im-ws` 仍应完成编译与测试 harness 验证。
