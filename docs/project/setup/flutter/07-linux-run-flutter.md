# 在 Linux 平台运行 Flutter 项目

## 1. 前置条件

这里的 Linux 平台指 `Flutter Linux 桌面应用`。

你需要：

- 已安装 Flutter SDK
- Linux 桌面环境
- 已安装 Linux 构建依赖

## 2. 安装构建依赖

Ubuntu / Debian 执行：

```bash
sudo apt update
sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev libstdc++-12-dev
```

这些工具分别用于：

| 工具 | 作用 |
| --- | --- |
| `clang` | C/C++ 编译 |
| `cmake` | 构建配置 |
| `ninja-build` | 构建执行 |
| `pkg-config` | 查找系统库 |
| `libgtk-3-dev` | Linux 桌面 UI 依赖 |
| `libstdc++-12-dev` | C++ 标准库开发文件 |

## 3. 检查环境

执行：

```bash
flutter doctor -v
```

重点看：

```text
[✓] Linux toolchain - develop for Linux desktop
```

## 4. 检查 Linux 设备

```bash
flutter devices
```

正常会看到类似：

```text
Linux (desktop) • linux • linux-x64
```

## 5. 创建并运行项目

```bash
flutter create hello_flutter
cd hello_flutter
flutter run -d linux
```

如果已有项目没有 Linux 目录，可以补生成：

```bash
flutter create --platforms=linux .
```

## 6. 构建 Linux 应用

```bash
flutter build linux
```

构建产物通常在：

```text
build/linux/x64/release/bundle/
```

## 7. 常见问题

### 7.1 找不到 Linux 设备

检查：

1. 当前是否在 Linux 桌面系统
2. 是否安装了构建依赖
3. `flutter doctor -v` 是否还有错误

### 7.2 缺少 GTK 相关库

重新安装：

```bash
sudo apt install -y libgtk-3-dev pkg-config
```

### 7.3 构建缓存异常

执行：

```bash
flutter clean
flutter pub get
flutter run -d linux
```

## 8. 参考资料

- Linux 开发配置：<https://docs.flutter.dev/platform-integration/linux/setup>
- Linux 构建发布：<https://docs.flutter.dev/deployment/linux>
