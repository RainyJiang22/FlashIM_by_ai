# macOS / Linux 安装和配置 Flutter SDK

## 1. 文档信息

- 项目：`flash_im`
- 适用系统：`macOS`、`Linux`
- 适用人群：第一次安装 Flutter 的初学者
- 编写时间：`2026-06-01`
- 参考版本：Flutter 官方文档当前反映 `Flutter 3.44.0`

## 2. 你需要安装什么

| 工具 | 作用 |
| --- | --- |
| Git | 下载 Flutter SDK 和项目依赖 |
| Flutter SDK | Flutter 命令行和框架本体 |
| VS Code 或 Android Studio | 写代码 |
| Android Studio | Android SDK 和模拟器 |
| Xcode | 仅 macOS 开发 iOS/macOS 时需要 |

## 3. 安装 Git

### macOS

执行：

```bash
git --version
```

如果系统提示安装 Command Line Tools，按提示完成安装。

也可以手动执行：

```bash
xcode-select --install
```

### Linux

Ubuntu / Debian：

```bash
sudo apt update
sudo apt install -y git curl unzip xz-utils zip
```

验证：

```bash
git --version
```

## 4. 下载 Flutter SDK

推荐放在用户目录下，例如：

```text
$HOME/development/flutter
```

执行：

```bash
mkdir -p "$HOME/development"
cd "$HOME/development"
git clone https://github.com/flutter/flutter.git -b stable
```

## 5. 配置 PATH

Flutter 命令目录：

```text
$HOME/development/flutter/bin
```

### zsh

macOS 默认通常是 zsh：

```bash
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### bash

Linux 常见 bash：

```bash
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

验证：

```bash
flutter --version
```

## 6. 配置国内镜像

如果下载依赖慢，可以配置：

```bash
echo 'export PUB_HOSTED_URL=https://pub.flutter-io.cn' >> ~/.zshrc
echo 'export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn' >> ~/.zshrc
source ~/.zshrc
```

如果你用 bash，把 `~/.zshrc` 改成 `~/.bashrc`。

## 7. 安装 Android Studio

Android 开发需要 Android Studio：

1. 下载 Android Studio：<https://developer.android.com/studio>
2. 安装并首次打开
3. 按引导安装 Android SDK、Platform Tools、Android Emulator
4. 在 SDK Manager 里确认至少安装一个 Android SDK Platform

## 8. macOS 安装 Xcode

如果要运行 iOS 或 macOS 应用，需要安装 Xcode。

1. 从 Mac App Store 或 Apple Developer 下载 Xcode
2. 执行：

```bash
sudo sh -c 'xcode-select -s /Applications/Xcode.app/Contents/Developer && xcodebuild -runFirstLaunch'
sudo xcodebuild -license
```

如果要运行 iOS 模拟器，还可以执行：

```bash
xcodebuild -downloadPlatform iOS
```

## 9. 验证环境

执行：

```bash
flutter doctor -v
```

初学者不用追求一开始全部绿色。你先根据目标平台处理对应项：

| 目标 | 重点检查 |
| --- | --- |
| Android | `Android toolchain`、`Android Studio` |
| iOS | `Xcode`、`CocoaPods` |
| Web | `Chrome` 或 `Edge` |
| Linux 桌面 | `Linux toolchain` |
| macOS 桌面 | `Xcode` |

## 10. 参考资料

- Flutter 安装入口：<https://docs.flutter.dev/install>
- Flutter 手动安装：<https://docs.flutter.dev/install/manual>
- Android 开发配置：<https://docs.flutter.dev/platform-integration/android/setup>
- iOS 开发配置：<https://docs.flutter.dev/platform-integration/ios/setup>
- macOS 开发配置：<https://docs.flutter.dev/platform-integration/macos/setup>
- Linux 开发配置：<https://docs.flutter.dev/platform-integration/linux/setup>
