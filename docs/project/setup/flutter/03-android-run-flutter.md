# 在 Android 平台运行 Flutter 项目

## 1. 前置条件

你需要先完成：

- 已安装 Flutter SDK
- 已安装 Android Studio
- `flutter doctor -v` 中 Android 相关问题已处理

## 2. 检查 Android 设备

执行：

```bash
flutter devices
```

如果你看到类似下面内容，说明 Flutter 找到了 Android 设备：

```text
emulator-5554 • sdk gphone64 arm64 • android-arm64 • Android 15
```

## 3. 使用 Android 模拟器

### 3.1 创建模拟器

1. 打开 Android Studio
2. 打开 `Device Manager`
3. 点击 `Create device`
4. 选择一个 Pixel 设备
5. 选择一个 Android 系统镜像
6. 完成创建

### 3.2 启动模拟器

在 Android Studio 的 `Device Manager` 里点击启动按钮。

也可以用命令查看：

```bash
flutter emulators
```

启动指定模拟器：

```bash
flutter emulators --launch <emulator_id>
```

## 4. 使用真机

Android 真机需要：

1. 打开手机开发者选项
2. 开启 USB 调试
3. 用 USB 连接电脑
4. 手机弹窗时允许调试
5. 执行：

```bash
flutter devices
```

Windows 用户如果识别不到设备，需要安装手机厂商 USB 驱动。

## 5. 创建并运行项目

创建示例项目：

```bash
flutter create hello_flutter
cd hello_flutter
```

运行：

```bash
flutter run
```

如果有多个设备，指定 Android 设备：

```bash
flutter run -d <device_id>
```

设备 ID 来自：

```bash
flutter devices
```

## 6. 常用命令

| 命令 | 作用 |
| --- | --- |
| `flutter devices` | 查看可用设备 |
| `flutter emulators` | 查看可用模拟器 |
| `flutter run` | 运行项目 |
| `flutter clean` | 清理构建缓存 |
| `flutter pub get` | 下载 Dart 依赖 |
| `flutter doctor -v` | 检查环境 |

## 7. 常见问题

### 7.1 提示 Android license 未接受

执行：

```bash
flutter doctor --android-licenses
```

一路输入 `y`。

### 7.2 真机识别不到

按顺序检查：

1. USB 线是否支持数据传输
2. 手机是否开启 USB 调试
3. 手机是否允许了当前电脑调试
4. Windows 是否安装了厂商 USB 驱动

### 7.3 模拟器很卡

建议：

1. 优先使用 x86_64 或 arm64 推荐镜像
2. 给模拟器分配更多内存
3. 关闭不必要的后台程序
4. 真机调试通常更稳定

## 8. 参考资料

- Android 开发配置：<https://docs.flutter.dev/platform-integration/android/setup>
- Android 构建发布：<https://docs.flutter.dev/deployment/android>
