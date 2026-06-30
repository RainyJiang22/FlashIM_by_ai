# im-proto v0.0.1 — 客户端任务清单

基于 [design.md](./design.md) 设计，拆分 `client/` 侧协议生成实现步骤。目标是新增 `client/modules/flash_im_core` 模块，配置 `protoc + protoc-gen-dart` 生成 Dart Protobuf 代码，并验证生成代码可以被 Dart 正常 import 和编译。

全局约束：
- 本清单只覆盖客户端 proto 生成与模块骨架；`WsClient`、`ImConfig`、连接、认证、心跳、重连、业务 WebSocket 管理均不在本版本实现。
- 不接入 `client/lib/main.dart`，也不把 `flash_im_core` 加入主 app 依赖；本版本只验证 package 自身。
- 生成的 `ws.pb.dart`、`ws.pbenum.dart`、`ws.pbjson.dart` 需要提交 Git，避免 clone 后必须立即配置 protoc。
- `client/modules/flash_im_core/lib/flash_im_core.dart` 本版本只保留 package library 入口，不导出生成代码；下一版本有业务代码时再统一导出。
- proto 源文件复用项目根目录 `proto/ws.proto`，不要复制一份到 client 模块内。
- 生成脚本按设计落在 `scripts/proto/gen.ps1`，后续 proto 变更后手动执行。

---

## 执行顺序

1. ✅ 任务 1 — `client/modules/flash_im_core` 创建 Flutter package 配置（无依赖）
   - ✅ 1.1 配置 package 元数据与 SDK 约束
   - ✅ 1.2 添加 `protobuf` 运行时依赖
   - ✅ 1.3 添加 Flutter 测试与 lint 依赖
   - ✅ 1.4 添加 package 级 `.gitignore`
2. ✅ 任务 2 — `client/modules/flash_im_core/analysis_options.yaml` 对齐模块 lint 配置（依赖任务 1）
   - ✅ 2.1 include `flutter_lints`
3. ✅ 任务 3 — `client/modules/flash_im_core/lib/flash_im_core.dart` 创建模块入口（依赖任务 1）
   - ✅ 3.1 声明 library
   - ✅ 3.2 暂不导出生成代码
4. ✅ 任务 4 — `client/modules/flash_im_core/lib/src/{data,logic,view}` 创建三层目录骨架（依赖任务 1）
   - ✅ 4.1 创建 `data/proto/` 作为生成代码目录
   - ✅ 4.2 创建空的 `logic/` 和 `view/` 预留目录
5. ✅ 任务 5 — `scripts/proto/gen.ps1` 新增 Dart proto 生成脚本（依赖任务 4）
   - ✅ 5.1 检查 `protoc` 和 `protoc-gen-dart`
   - ✅ 5.2 从项目根目录读取 `proto/ws.proto`
   - ✅ 5.3 输出到 `client/modules/flash_im_core/lib/src/data/proto`
6. ✅ 任务 6 — `client/modules/flash_im_core/lib/src/data/proto/ws.*.dart` 生成并提交 Dart Protobuf 代码（依赖任务 5）
   - ✅ 6.1 执行生成脚本或等价 protoc 命令
   - ✅ 6.2 确认生成 `ws.pb.dart`
   - ✅ 6.3 确认生成 `ws.pbenum.dart`
   - ✅ 6.4 确认生成 `ws.pbjson.dart`
7. ✅ 任务 7 — `client/modules/flash_im_core/test/proto_compile_test.dart` 增加最小 import 编译测试（依赖任务 6）
   - ✅ 7.1 import 生成的 `ws.pb.dart`
   - ✅ 7.2 构造 `WsFrame`、`AuthRequest`、`AuthResult`
   - ✅ 7.3 验证枚举值与字段可访问
8. ✅ 最后 — 依赖安装、格式化、分析与测试验证（依赖任务 1-7）
   - ✅ 8.1 `cd client/modules/flash_im_core && flutter pub get`
   - ✅ 8.2 `cd client/modules/flash_im_core && dart format lib test`
   - ✅ 8.3 `cd client/modules/flash_im_core && flutter analyze`
   - ✅ 8.4 `cd client/modules/flash_im_core && flutter test`

---

## 任务 1：`client/modules/flash_im_core` — 创建 Flutter package 配置 `✅ 已完成`

文件：
- `client/modules/flash_im_core/pubspec.yaml`
- `client/modules/flash_im_core/.gitignore`

改动类型：`新建`

### 1.1 配置 package 元数据与 SDK 约束 `✅`

关键配置骨架：

```yaml
name: flash_im_core
description: "Flash IM core protocol package."
version: 0.0.1
publish_to: none

environment:
  sdk: ^3.11.5
  flutter: ">=1.17.0"
```

说明：
- 命名沿用现有 `flash_auth`、`flash_session` 的 `flash_` 前缀。

### 1.2 添加 protobuf 运行时依赖 `✅`

关键配置骨架：

```yaml
dependencies:
  flutter:
    sdk: flutter
  protobuf: ^6.0.0
```

说明：
- 生成的 `ws.pb.dart` 会依赖 Dart `protobuf` 运行时。

### 1.3 添加 Flutter 测试与 lint 依赖 `✅`

关键配置骨架：

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
```

### 1.4 添加 package 级 `.gitignore` `✅`

关键配置骨架：

```gitignore
/pubspec.lock
.dart_tool/
/build/
/coverage/
```

说明：
- 与现有 `flash_auth` / `app_starter` package 保持一致，避免 `flutter pub get` 和 `flutter test` 产物进入提交范围。

---

## 任务 2：`client/modules/flash_im_core/analysis_options.yaml` — 对齐模块 lint 配置 `✅ 已完成`

文件：`client/modules/flash_im_core/analysis_options.yaml`

改动类型：`新建`

### 2.1 include flutter_lints `✅`

关键配置骨架：

```yaml
include: package:flutter_lints/flutter.yaml
```

说明：
- 与现有 `client/modules/flash_auth`、`client/modules/flash_session` 模块保持一致。

---

## 任务 3：`client/modules/flash_im_core/lib/flash_im_core.dart` — 创建模块入口 `✅ 已完成`

文件：`client/modules/flash_im_core/lib/flash_im_core.dart`

改动类型：`新建`

### 3.1 声明 library `✅`

关键代码骨架：

```dart
library;
```

### 3.2 暂不导出生成代码 `✅`

本版本不要添加：

```dart
// export 'src/data/proto/ws.pb.dart';
// export 'src/data/proto/ws.pbenum.dart';
// export 'src/data/proto/ws.pbjson.dart';
```

说明：
- 设计中已明确 barrel 导出暂不实现；下一版本有业务 API 后再统一整理导出面。

---

## 任务 4：`client/modules/flash_im_core/lib/src/{data,logic,view}` — 创建三层目录骨架 `✅ 已完成`

文件：
- `client/modules/flash_im_core/lib/src/data/proto/`
- `client/modules/flash_im_core/lib/src/logic/.gitkeep`
- `client/modules/flash_im_core/lib/src/view/.gitkeep`

改动类型：`新建`

### 4.1 创建 data/proto 目录 `✅`

目录骨架：

```text
client/modules/flash_im_core/lib/src/data/proto/
```

说明：
- 生成的 Dart proto 类属于数据层，统一放在 `data/proto/`。

### 4.2 创建 logic 和 view 预留目录 `✅`

目录骨架：

```text
client/modules/flash_im_core/lib/src/logic/
client/modules/flash_im_core/lib/src/view/
```

说明：
- 本版本不放业务代码。为避免空目录无法提交，`logic/` 与 `view/` 使用 `.gitkeep` 占位；`data/proto/` 由生成的 `ws.*.dart` 文件占位。

---

## 任务 5：`scripts/proto/gen.ps1` — 新增 Dart proto 生成脚本 `✅ 已完成`

文件：`scripts/proto/gen.ps1`

改动类型：`新建`

### 5.1 检查 protoc 和 protoc-gen-dart `✅`

关键脚本骨架：

```powershell
$ErrorActionPreference = "Stop"

$PubCacheBin = Join-Path $HOME ".pub-cache/bin"
if (Test-Path $PubCacheBin) {
  $env:PATH = "$PubCacheBin$([System.IO.Path]::PathSeparator)$env:PATH"
}

$Protoc = $env:PROTOC
if (-not $Protoc) {
  $ProtocCommand = Get-Command protoc -ErrorAction SilentlyContinue
  if (-not $ProtocCommand) {
    throw "Missing protoc. Install protobuf compiler first, or set PROTOC to the protoc binary path."
  }
  $Protoc = $ProtocCommand.Source
}

if (-not (Get-Command protoc-gen-dart -ErrorAction SilentlyContinue)) {
  throw "Missing protoc-gen-dart. Run: dart pub global activate protoc_plugin"
}
```

### 5.2 解析项目根目录和输入输出路径 `✅`

关键脚本骨架：

```powershell
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "../..")
$ProtoFile = Join-Path $RepoRoot "proto/ws.proto"
$ProtoDir = Join-Path $RepoRoot "proto"
$OutDir = Join-Path $RepoRoot "client/modules/flash_im_core/lib/src/data/proto"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
```

### 5.3 执行 Dart proto 生成 `✅`

关键脚本骨架：

```powershell
& $Protoc `
  --proto_path=$ProtoDir `
  --dart_out=$OutDir `
  $ProtoFile
```

说明：
- 脚本只负责生成 Dart 代码，不修改 pubspec、不执行 Flutter 测试。

---

## 任务 6：`client/modules/flash_im_core/lib/src/data/proto/ws.*.dart` — 生成并提交 Dart Protobuf 代码 `✅ 已完成`

文件：
- `client/modules/flash_im_core/lib/src/data/proto/ws.pb.dart`
- `client/modules/flash_im_core/lib/src/data/proto/ws.pbenum.dart`
- `client/modules/flash_im_core/lib/src/data/proto/ws.pbjson.dart`

改动类型：`新建`

### 6.1 执行生成脚本或等价 protoc 命令 `✅`

推荐执行：

```powershell
pwsh scripts/proto/gen.ps1
```

等价命令：

```bash
protoc --proto_path=proto --dart_out=client/modules/flash_im_core/lib/src/data/proto proto/ws.proto
```

### 6.2 确认生成 `ws.pb.dart` `✅`

生成文件应包含的类型：

```dart
class WsFrame extends $pb.GeneratedMessage {
  // fields: type, payload
}

class AuthRequest extends $pb.GeneratedMessage {
  // field: token
}

class AuthResult extends $pb.GeneratedMessage {
  // fields: success, message
}
```

### 6.3 确认生成 `ws.pbenum.dart` `✅`

生成文件应包含的枚举：

```dart
class WsFrameType extends $pb.ProtobufEnum {
  static const WsFrameType PING = ...;
  static const WsFrameType PONG = ...;
  static const WsFrameType AUTH = ...;
  static const WsFrameType AUTH_RESULT = ...;
}
```

### 6.4 确认生成 `ws.pbjson.dart` `✅`

生成文件应包含各 message / enum 的 JSON descriptor 常量，供反射和调试使用。

---

## 任务 7：`client/modules/flash_im_core/test/proto_compile_test.dart` — 增加最小 import 编译测试 `✅ 已完成`

文件：`client/modules/flash_im_core/test/proto_compile_test.dart`

改动类型：`新建`

### 7.1 import 生成代码 `✅`

关键代码骨架：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_im_core/src/data/proto/ws.pb.dart';
```

### 7.2 构造生成类型 `✅`

关键代码骨架：

```dart
test('generated proto classes can be constructed', () {
  final authRequest = AuthRequest(token: 'token');
  final authResult = AuthResult(success: true, message: 'ok');
  final frame = WsFrame(
    type: WsFrameType.AUTH,
    payload: authRequest.writeToBuffer(),
  );

  // expectations...
});
```

### 7.3 验证枚举值与字段可访问 `✅`

关键断言骨架：

```dart
expect(frame.type, WsFrameType.AUTH);
expect(authRequest.token, 'token');
expect(authResult.success, isTrue);
expect(authResult.message, 'ok');
expect(frame.payload, isNotEmpty);
```

说明：
- 该测试只证明生成代码可 import、可构造、可编译，不引入 WebSocket 业务逻辑。

---

## 任务 8：依赖安装、格式化、分析与测试验证 `✅ 已完成`

文件：无单一目标文件，验证 `client/modules/flash_im_core/` 整体可用。

改动类型：`验证`

### 8.1 安装 package 依赖 `✅`

执行：

```bash
cd client/modules/flash_im_core && flutter pub get
```

### 8.2 格式化 `✅`

执行：

```bash
cd client/modules/flash_im_core && dart format lib test
```

### 8.3 静态分析 `✅`

执行：

```bash
cd client/modules/flash_im_core && flutter analyze
```

### 8.4 自动化测试 `✅`

执行：

```bash
cd client/modules/flash_im_core && flutter test
```

说明：
- 不需要运行主 app，也不需要修改 `client/pubspec.yaml`。
