# macOS Rust 环境安装说明

## 1. 文档信息

- 项目：`flash_im`
- 适用系统：`macOS`
- 当前环境：`Apple Silicon (arm64) + zsh`
- 适用人群：第一次在 macOS 上安装 Rust 的同学
- 推荐方案：使用 `rustup` 安装并管理 Rust 工具链
- 编写时间：`2026-06-01`

## 2. 这份文档会帮你装什么

安装完成后，你会得到这些常用工具：

- `rustup`：Rust 工具链管理器
- `rustc`：Rust 编译器
- `cargo`：Rust 包管理和构建工具
- `rustfmt`：代码格式化工具
- `clippy`：常用静态检查工具
- `rust-analyzer`：编辑器常用语言服务组件

对初学者来说，直接使用 `rustup` 就够了，不建议一开始用多种方式混装。

## 3. 安装前先知道两件事

### 3.1 为什么优先用脚本

这份文档尽量把重复步骤做成脚本，原因很简单：

- 少输命令，出错更少
- 可以重复执行
- 后续新机器也能直接复用

### 3.2 第一次安装可能会遇到一个系统弹窗

Rust 在 macOS 上依赖 `Xcode Command Line Tools`。

如果你的机器之前没有装过它，安装脚本会触发：

```bash
xcode-select --install
```

这一步会弹出系统安装窗口，不能完全静默自动化。你只需要完成安装，然后重新执行脚本即可。

## 4. 推荐安装方式

### 4.1 执行安装脚本

在项目根目录运行：

```bash
bash scripts/setup/install-rust-macos.sh
```

这个脚本会自动完成下面这些事情：

1. 检查当前系统是不是 `macOS`
2. 检查 `Xcode Command Line Tools` 是否已安装
3. 通过官方 `rustup` 安装 Rust stable 工具链
4. 安装 `rustfmt`、`clippy`、`rust-analyzer`
5. 输出版本信息，方便确认安装结果

脚本还包含一层额外保护：

- 首次下载失败时，会自动清理未完成的 `.partial` 下载文件
- 然后用更保守的下载参数再试一次
- 重试时会切到 `curl` 下载后端，并把并发降到 `1`
- 如果工具链元数据写入了，但 `rustc` / `cargo` 实际文件不完整，脚本会自动卸掉坏工具链再重装一次

### 4.2 如果脚本提示你先安装 Xcode 命令行工具

按下面顺序处理：

1. 完成系统弹出的安装流程
2. 关闭当前终端窗口，重新打开一个新终端
3. 回到项目根目录
4. 再执行一次：

```bash
bash scripts/setup/install-rust-macos.sh
```

### 4.3 如果你已经遇到 `unexpected EOF` 下载中断

你看到的典型报错通常像这样：

```text
peer closed connection without sending TLS close_notify
unexpected EOF
```

这通常表示下载连接被中途断开，常见原因是网络波动、代理链路不稳定，或者并发下载时连接质量不好。

先直接重跑安装脚本：

```bash
bash scripts/setup/install-rust-macos.sh
```

如果你想手动执行一次“保守模式”安装，可以运行：

```bash
source "$HOME/.cargo/env"
rm -f "$HOME/.rustup"/downloads/*.partial 2>/dev/null || true

RUSTUP_USE_CURL=1 \
RUSTUP_CONCURRENT_DOWNLOADS=1 \
RUSTUP_DOWNLOAD_TIMEOUT=600 \
RUSTUP_IO_THREADS=1 \
rustup toolchain install stable --profile minimal

rustup default stable

RUSTUP_USE_CURL=1 \
RUSTUP_CONCURRENT_DOWNLOADS=1 \
RUSTUP_DOWNLOAD_TIMEOUT=600 \
RUSTUP_IO_THREADS=1 \
rustup component add rustfmt clippy rust-analyzer
```

如果你在公司网络、代理网络或校园网环境下，还要额外确认 `https_proxy` 配置是否正确。

### 4.4 执行验证脚本

安装完成后，继续运行：

```bash
bash scripts/setup/verify-rust-macos.sh
```

这个脚本会：

- 检查 `rustup`、`rustc`、`cargo` 是否可用
- 创建一个临时 Rust 示例工程
- 运行 `cargo fmt --check`
- 运行 `cargo clippy`
- 运行 `cargo run`

如果最后输出 `hello, rust`，说明环境已经可以开始用了。

## 5. 你也可以看看脚本具体做了什么

### 5.1 安装脚本

文件位置：

- [install-rust-macos.sh](/Users/rainyjiang/AndroidStudioProjects/flash_im/scripts/setup/install-rust-macos.sh)

脚本核心逻辑：

- 没有 `Xcode Command Line Tools` 时，先提醒安装
- 没有 `rustup` 时，用官方安装脚本自动安装
- 已经装过 `rustup` 时，继续复用并更新工具链
- 默认切到 `stable`
- 安装常用组件

### 5.2 验证脚本

文件位置：

- [verify-rust-macos.sh](/Users/rainyjiang/AndroidStudioProjects/flash_im/scripts/setup/verify-rust-macos.sh)

验证脚本不会污染仓库：

- 它使用临时目录创建测试工程
- 运行结束后会自动清理

## 6. 安装成功后最常用的命令

你后面最常用的通常就是这几条：

```bash
rustc -V
cargo -V
rustup show active-toolchain
```

创建一个新项目：

```bash
cargo new hello_rust
cd hello_rust
cargo run
```

如果输出类似下面内容，就说明基本没问题：

```text
Hello, world!
```

## 7. 常见问题

### 7.1 终端里提示找不到 `cargo`

先执行：

```bash
source "$HOME/.cargo/env"
```

如果还是不行：

1. 关闭终端
2. 重新打开终端
3. 再执行 `cargo -V`

### 7.2 想更新 Rust

执行：

```bash
source "$HOME/.cargo/env"
RUSTUP_USE_CURL=1 \
RUSTUP_CONCURRENT_DOWNLOADS=1 \
RUSTUP_DOWNLOAD_TIMEOUT=600 \
rustup update stable

RUSTUP_USE_CURL=1 \
RUSTUP_CONCURRENT_DOWNLOADS=1 \
RUSTUP_DOWNLOAD_TIMEOUT=600 \
rustup component add rustfmt clippy rust-analyzer
```

### 7.3 想卸载 Rust

执行：

```bash
rustup self uninstall
```

### 7.4 脚本报错说不是 macOS

这份文档和脚本是按当前项目所在环境编写的，只适用于 `macOS`。

如果后面需要补 `Windows` 或 `Linux` 版本，建议单独写新的安装文档，不要混在同一份里。

### 7.5 反复出现下载中断怎么办

按这个顺序排查最有效：

1. 先重跑一次安装脚本，因为临时网络抖动很常见
2. 确认本机能正常访问 `https://static.rust-lang.org`
3. 如果在代理网络下，确认 `https_proxy` 配置正确
4. 用文档里的“保守模式”命令，强制单并发并改用 `curl` 后端
5. 如果你有稳定的本地镜像源，也可以通过 `RUSTUP_DIST_SERVER` 指向自己的镜像

## 8. 到什么程度算安装完成

满足下面 3 条，就可以认为 Rust 环境已经准备好了：

1. `bash scripts/setup/install-rust-macos.sh` 能正常完成
2. `bash scripts/setup/verify-rust-macos.sh` 能正常完成
3. 你自己执行 `cargo new hello_rust && cargo run` 时能看到程序输出

到这里，就可以开始本项目后续的 Rust 开发了。
