---
module: im-proto
version: v0.0.1
date: 2026-03-28
tags: [protobuf, websocket, 协议, rust, prost]
---

# IM 协议 — 服务端设计报告

> 关联设计：[im-proto v0.0.1 client](../client/design.md)

## 1. 目标

- 在项目根目录创建 `proto/ws.proto`，定义帧结构和认证协议
- 在后端新增 `server/modules/im-ws` crate，配置 prost-build 自动生成 Rust 代码
- 验证 `cargo build` 能成功编译生成的 proto 代码

本版本不写任何业务逻辑（连接管理、帧分发等），只完成协议定义和代码生成。

## 2. 现状分析

- 后端 `server/src/ws/` 下有早期原型端点（echo、认证 echo、JSON 广播聊天室），属于验证代码
- 没有 .proto 文件，没有二进制协议
- Rust workspace 已配置，可新增 crate
- JWT 认证已实现（flash-core/jwt.rs），后续版本可复用

## 3. 数据模型与接口

### ws.proto 定义

```protobuf
syntax = "proto3";
package im;

enum WsFrameType {
  PING = 0;
  PONG = 1;
  AUTH = 2;
  AUTH_RESULT = 3;
  // 4+ 预留给后续版本：消息、同步、好友、群聊、撤回、已读等
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

### 关键设计决策

| 决策 | 方案 | 理由 |
|------|------|------|
| 帧结构 | type + payload | 稳定外壳，新增帧类型不改结构 |
| 编号策略 | 当前只定义 0~3 | 后续版本按需追加，编号连续递增 |

## 5. 项目结构与技术决策

### 项目结构

```
proto/
└── ws.proto                        # 协议定义（前后端共享）

server/modules/im-ws/
├── Cargo.toml                      # 依赖 prost，build-dep prost-build
├── build.rs                        # prost_build::compile_protos 配置
└── src/
    ├── lib.rs                      # 模块入口，pub mod proto
    └── proto.rs                    # include!(concat!(env!("OUT_DIR"), "/im.rs"))
```

### 技术决策

| 决策 | 方案 | 理由 |
|------|------|------|
| proto 文件位置 | 项目根目录 `proto/` | 前后端共享同一份定义 |
| 代码生成 | prost + prost-build | Rust 生态主流，cargo build 自动触发 |
| 生成代码提交 Git | 否（OUT_DIR 自动生成） | prost 生成到 OUT_DIR，不需要手动管理 |

### 第三方依赖（需新增）

| 依赖 | 类型 | 用途 |
|------|------|------|
| prost | dependencies | Protobuf 编解码运行时 |
| prost-build | build-dependencies | 构建时编译 .proto 文件 |

### Cargo.toml workspace 改动

`server/Cargo.toml` 的 workspace members 新增 `"modules/im-ws"`。

## 6. 暂不实现

| 功能 | 理由 |
|------|------|
| message.proto | 属于消息收发版本，本版本只定义帧结构 |
| 连接管理（handler/state） | 属于 im-ws 的业务逻辑，下一版本实现 |
| 帧分发（dispatcher） | 属于 im-ws 的业务逻辑，下一版本实现 |
| 路由注册 | 没有业务逻辑，不需要路由 |
