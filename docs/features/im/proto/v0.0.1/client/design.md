---
module: im-proto
version: v0.0.1
date: 2026-03-28
tags: [protobuf, websocket, 协议, flutter, dart]
---

# IM 协议 — 客户端设计报告

> 关联设计：[im-proto v0.0.1 server](../server/design.md)

## 1. 目标

- 新增 `client/modules/flash_im_core` 模块，遵循三层架构（data/logic/view）
- 配置 protoc + protoc-gen-dart，从 `proto/ws.proto` 生成 Dart 代码
- 验证生成的代码可以正常 import 和编译

本版本不写任何业务逻辑（WebSocket 管理器、连接、心跳等），只完成模块骨架和代码生成。

## 2. 现状分析

- 前端正式模块（flash_auth、flash_session、flash_starter）中没有任何 WebSocket 或 Protobuf 相关代码
- `client/lib/playground/` 下有早期 WebSocket 测试代码，已废弃
- 模块化 package 体系已建立（`client/modules/` 下），三层架构规范已确立（data/logic/view）
- 无现有 .proto 文件或 protobuf 依赖

## 3. 数据模型与接口

### 生成的 Dart 类

从 `proto/ws.proto` 生成以下 Dart 类（自动生成，不手动编辑）：

| 类 | 说明 |
|----|------|
| WsFrameType | 帧类型枚举：PING/PONG/AUTH/AUTH_RESULT |
| WsFrame | 帧结构：type + payload |
| AuthRequest | 认证请求：token |
| AuthResult | 认证结果：success + message |

## 5. 项目结构与技术决策

### 项目结构

```
client/modules/flash_im_core/
├── pubspec.yaml                    # 依赖 protobuf
└── lib/
    ├── flash_im_core.dart          # barrel 导出
    └── src/
        ├── data/
        │   └── proto/
        │       ├── ws.pb.dart      # protoc 生成
        │       ├── ws.pbenum.dart  # protoc 生成
        │       └── ws.pbjson.dart  # protoc 生成
        ├── logic/                  # 本版本为空，下一版本放 WsClient
        └── view/                   # 本版本为空，预留
```

### 技术决策

| 决策 | 方案 | 理由 |
|------|------|------|
| 模块名 | flash_im_core | 遵循项目 flash_ 前缀命名规范 |
| 三层架构 | data/logic/view | 与 flash_auth、flash_session 保持一致 |
| proto 生成代码位置 | data/proto/ | proto 属于数据层，生成的类是数据结构 |
| 生成代码提交 Git | 是 | 避免每次 clone 后都要配置 protoc 环境 |
| 生成脚本 | 项目根目录 `scripts/proto/gen.ps1` | 统一管理，proto 变更后手动执行一次 |

### 第三方依赖（需新增）

| 依赖 | 类型 | 用途 |
|------|------|------|
| protobuf (Dart) | pubspec dependencies | Protobuf 运行时编解码 |

### 系统工具（需安装）

| 工具 | 用途 | 安装方式 |
|------|------|---------|
| protoc | proto 编译器 | 系统包管理器或官方下载 |
| protoc-gen-dart | proto → Dart 插件 | `dart pub global activate protoc_plugin` |

### 代码生成命令

```powershell
protoc --dart_out=client/modules/flash_im_core/lib/src/data/proto proto/ws.proto
```

可封装为 `scripts/proto/gen.ps1` 脚本，后续新增 .proto 文件时只需修改脚本。

## 6. 暂不实现

| 功能 | 理由 |
|------|------|
| WsClient（WebSocket 管理器） | 属于 logic 层，下一版本实现 |
| ImConfig（IM 配置） | 随 WsClient 一起实现 |
| 连接、认证、心跳、重连 | 属于业务逻辑，下一版本实现 |
| main.dart 集成 | 没有业务逻辑，不需要集成 |
| barrel 导出 | 生成代码可以先不导出，下一版本有业务代码时再统一导出 |
