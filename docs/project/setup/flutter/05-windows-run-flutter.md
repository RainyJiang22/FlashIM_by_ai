# 在 Windows 平台运行 Flutter 项目

## 1. 前置条件

这里的 Windows 平台指 `Flutter Windows 桌面应用`，不是 Android。

你需要：

- Windows 10/11
- 已安装 Flutter SDK
- 已安装 Visual Studio
- Visual Studio 已安装 `Desktop development with C++` 工作负载

注意：Visual Studio 和 VS Code 不是同一个软件。Windows 桌面构建需要 Visual Studio 的 C++ 工具链。

## 2. 安装 Visual Studio

1. 打开：<https://visualstudio.microsoft.com/>
2. 下载 Visual Studio Community
3. 启动 Visual Studio Installer
4. 勾选 `Desktop development with C++`
5. 完成安装

如果已经安装 Visual Studio，可以打开 Visual Studio Installer，点击 `Modify`，补装这个工作负载。

## 3. 检查环境

执行：

```powershell
flutter doctor -v
```

重点看：

```text
[✓] Visual Studio - develop Windows apps
```

如果不是绿色，先根据提示修复。

## 4. 检查 Windows 设备

执行：

```powershell
flutter devices
```

正常情况下会看到类似：

```text
Windows (desktop) • windows • windows-x64
```

## 5. 创建并运行项目

```powershell
flutter create hello_flutter
cd hello_flutter
flutter run -d windows
```

如果项目原来没有 Windows 平台目录，可以补生成：

```powershell
flutter create --platforms=windows .
```

## 6. 构建 Windows 应用

```powershell
flutter build windows
```

构建产物通常在：

```text
build\windows\x64\runner\Release\
```

运行 `.exe` 文件即可启动应用。

## 7. 常见问题

### 7.1 找不到 Windows 设备

检查：

1. 是否在 Windows 系统上执行
2. 是否安装 Visual Studio
3. 是否安装 `Desktop development with C++`
4. `flutter doctor -v` 是否还有错误

### 7.2 Visual Studio 已安装但 Flutter 不识别

处理：

1. 打开 Visual Studio Installer
2. 选择 Modify
3. 确认 `Desktop development with C++` 已勾选
4. 安装完成后重新打开 PowerShell
5. 再执行 `flutter doctor -v`

## 8. 参考资料

- Windows 开发配置：<https://docs.flutter.dev/platform-integration/windows/setup>
- Windows 构建发布：<https://docs.flutter.dev/deployment/windows>
