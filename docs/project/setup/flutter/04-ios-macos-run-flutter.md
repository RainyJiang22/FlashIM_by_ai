# 在 iOS / macOS 平台运行 Flutter 项目

## 1. 前置条件

iOS 和 macOS Flutter 开发都必须在 macOS 上进行。

你需要：

- 已安装 Flutter SDK
- 已安装 Xcode
- 已配置 Xcode command-line tools
- 已同意 Xcode license
- 已安装 CocoaPods

## 2. 配置 Xcode

执行：

```bash
sudo sh -c 'xcode-select -s /Applications/Xcode.app/Contents/Developer && xcodebuild -runFirstLaunch'
sudo xcodebuild -license
```

如果要运行 iOS 模拟器：

```bash
xcodebuild -downloadPlatform iOS
```

## 3. 安装 CocoaPods

推荐用 Homebrew：

```bash
brew install cocoapods
```

验证：

```bash
pod --version
```

## 4. 检查环境

执行：

```bash
flutter doctor -v
```

重点看：

```text
[✓] Xcode
[✓] CocoaPods
```

如果不是绿色，先按 `flutter doctor` 的提示处理。

## 5. 在 iOS 模拟器运行

启动模拟器：

```bash
open -a Simulator
```

创建并运行项目：

```bash
flutter create hello_flutter
cd hello_flutter
flutter run
```

如果有多个设备，先看设备 ID：

```bash
flutter devices
```

指定 iOS 模拟器运行：

```bash
flutter run -d <device_id>
```

## 6. 在 iPhone 真机运行

真机运行需要 Apple 开发者账号配置签名。

基本流程：

1. 用 USB 连接 iPhone
2. 在 iPhone 上信任当前电脑
3. 打开项目里的 `ios/Runner.xcworkspace`
4. 在 Xcode 中选择 `Runner`
5. 配置 `Signing & Capabilities`
6. 选择自己的 Team
7. 回到终端执行：

```bash
flutter run -d <iphone_device_id>
```

## 7. 在 macOS 桌面运行

先确认 macOS 桌面支持：

```bash
flutter devices
```

如果看到 `macOS` 设备，执行：

```bash
flutter run -d macos
```

构建 macOS 应用：

```bash
flutter build macos
```

构建产物通常在：

```text
build/macos/Build/Products/Release/
```

## 8. 常见问题

### 8.1 iOS 运行失败，提示签名问题

处理：

1. 打开 `ios/Runner.xcworkspace`
2. 找到 `Signing & Capabilities`
3. 选择有效 Team
4. 确认 Bundle Identifier 唯一

### 8.2 CocoaPods 报错

常用处理：

```bash
cd ios
pod repo update
pod install
cd ..
flutter clean
flutter pub get
```

### 8.3 找不到 iOS 模拟器

执行：

```bash
xcodebuild -downloadPlatform iOS
open -a Simulator
flutter devices
```

## 9. 参考资料

- iOS 开发配置：<https://docs.flutter.dev/platform-integration/ios/setup>
- macOS 开发配置：<https://docs.flutter.dev/platform-integration/macos/setup>
- iOS 构建发布：<https://docs.flutter.dev/deployment/ios>
- macOS 构建发布：<https://docs.flutter.dev/deployment/macos>
