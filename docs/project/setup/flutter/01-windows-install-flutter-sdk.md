# Windows 安装和配置 Flutter SDK

## 1. 文档信息

- 项目：`flash_im`
- 适用系统：`Windows 10/11`
- 适用人群：第一次安装 Flutter 的初学者
- 编写时间：`2026-06-01`
- 参考版本：Flutter 官方文档当前反映 `Flutter 3.44.0`

## 2. 你需要安装什么

Windows 上做 Flutter 开发，至少需要：

| 工具 | 作用 |
| --- | --- |
| Flutter SDK | Flutter 命令行和框架本体 |
| Git for Windows | Flutter 下载依赖、管理源码 |
| Android Studio | Android SDK、模拟器、设备管理 |
| VS Code 或 Android Studio | 写 Flutter 代码 |

如果你还要开发 Windows 桌面应用，需要额外安装 Visual Studio，见 `05-windows-run.md`。

## 3. 安装 Git

1. 打开 Git 官网：<https://git-scm.com/download/win>
2. 下载 Windows 安装包
3. 一路使用默认选项安装
4. 打开 PowerShell 验证：

```powershell
git --version
```

看到版本号就说明安装成功。

## 4. 下载 Flutter SDK

推荐把 Flutter 放到一个没有中文、没有空格的目录，例如：

```text
C:\src\flutter
```

操作步骤：

1. 新建目录 `C:\src`
2. 打开 PowerShell
3. 执行：

```powershell
cd C:\src
git clone https://github.com/flutter/flutter.git -b stable
```

如果你在国内网络下载很慢，可以参考 Flutter 官方的中国网络配置说明：<https://docs.flutter.dev/community/china>

## 5. 配置 PATH

Flutter 命令在这个目录里：

```text
C:\src\flutter\bin
```

配置步骤：

1. 打开 Windows 搜索
2. 搜索 `编辑系统环境变量`
3. 点击 `环境变量`
4. 在用户变量或系统变量里找到 `Path`
5. 点击 `编辑`
6. 新增：

```text
C:\src\flutter\bin
```

7. 保存后关闭所有终端
8. 重新打开 PowerShell

验证：

```powershell
flutter --version
```

## 6. 安装 Android Studio

1. 打开 Android Studio 官网：<https://developer.android.com/studio>
2. 下载并安装
3. 首次打开 Android Studio
4. 按引导安装 Android SDK、Platform Tools、Android Emulator
5. 打开 `Settings > Languages & Frameworks > Android SDK`
6. 确认至少安装一个 Android SDK Platform

## 7. 安装编辑器插件

如果使用 VS Code：

1. 打开 VS Code
2. 进入 Extensions
3. 搜索并安装 `Flutter`
4. Dart 插件会自动一起安装

如果使用 Android Studio：

1. 打开 `Settings > Plugins`
2. 搜索 `Flutter`
3. 安装后重启 Android Studio

## 8. 验证环境

执行：

```powershell
flutter doctor -v
```

你重点看这些项：

```text
[✓] Flutter
[✓] Android toolchain
[✓] Android Studio
[✓] VS Code 或 Android Studio
```

如果出现 `[!]` 或 `[x]`，按 `flutter doctor` 的提示逐项修复。

## 9. 常见问题

### 9.1 `flutter` 不是内部或外部命令

原因通常是 PATH 没配好。

处理：

1. 确认 `C:\src\flutter\bin` 存在
2. 确认它已经加到 `Path`
3. 关闭终端重新打开
4. 再执行 `flutter --version`

### 9.2 Android license 报错

执行：

```powershell
flutter doctor --android-licenses
```

根据提示输入 `y` 同意许可。

### 9.3 下载依赖很慢

可以配置国内镜像：

```powershell
setx PUB_HOSTED_URL "https://pub.flutter-io.cn"
setx FLUTTER_STORAGE_BASE_URL "https://storage.flutter-io.cn"
```

配置后重新打开 PowerShell。

## 10. 参考资料

- Flutter 安装入口：<https://docs.flutter.dev/install>
- Flutter 手动安装：<https://docs.flutter.dev/install/manual>
- Flutter 中国网络说明：<https://docs.flutter.dev/community/china>
- Android Studio：<https://developer.android.com/studio>
