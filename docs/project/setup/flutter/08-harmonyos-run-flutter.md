# 在 HarmonyOS 平台运行 Flutter 项目

## 1. 先明确一件事

HarmonyOS / OpenHarmony 不是 Flutter 官方主线 SDK 默认支持的平台。  
如果要运行 Flutter 到 HarmonyOS，需要使用 OpenHarmony-SIG 维护的 Flutter 适配版 SDK。

这份文档适合初学者了解基本流程，不建议把它当作和 Android/iOS/Web 一样稳定的官方主线流程。

## 2. 你需要安装什么

| 工具 | 作用 |
| --- | --- |
| DevEco Studio | HarmonyOS / OpenHarmony 开发工具 |
| OpenHarmony SDK | HarmonyOS 构建依赖 |
| JDK 17 | 构建工具依赖 |
| OpenHarmony-SIG Flutter SDK | 支持 `ohos` 平台的 Flutter 适配版 |
| hdc | HarmonyOS 设备连接和安装工具 |

## 3. 安装 DevEco Studio

1. 打开华为开发者官网：<https://developer.huawei.com/consumer/cn/deveco-studio/>
2. 下载并安装 DevEco Studio
3. 首次启动时安装 HarmonyOS SDK
4. 确认 SDK、Node、ohpm、hvigor 已随 DevEco Studio 安装

## 4. 安装 JDK 17

HarmonyOS Flutter 适配文档要求配置 JDK 17。

验证：

```bash
java -version
```

如果版本不是 17，安装 JDK 17 后配置 `JAVA_HOME`。

## 5. 获取 HarmonyOS Flutter SDK

OpenHarmony-SIG 原 Gitee 仓库提示已归档，并指向 GitCode 新地址。  
如果 GitCode 页面无法正常访问，也可以先参考 Gitee 镜像文档。

示例：

```bash
git clone https://gitee.com/openharmony-sig/flutter_flutter.git
```

实际开发时建议按官方最新仓库地址为准：

```text
https://gitcode.com/openharmony-sig/flutter_flutter
```

## 6. 配置环境变量

### macOS 示例

按你的真实安装路径修改：

```bash
export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home
export TOOL_HOME=/Applications/DevEco-Studio.app/Contents
export DEVECO_SDK_HOME=$TOOL_HOME/sdk
export PATH=$JAVA_HOME/bin:$PATH
export PATH=$TOOL_HOME/tools/ohpm/bin:$PATH
export PATH=$TOOL_HOME/tools/hvigor/bin:$PATH
export PATH=$TOOL_HOME/tools/node/bin:$PATH
export PATH=/path/to/flutter_flutter/bin:$PATH
```

如果在国内网络，可以配置：

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

### Windows 示例

在系统环境变量中配置：

```text
JAVA_HOME=<JDK 17 安装路径>
TOOL_HOME=<DevEco Studio 安装路径>
DEVECO_SDK_HOME=%TOOL_HOME%\sdk
PATH=%JAVA_HOME%\bin
PATH=%TOOL_HOME%\tools\ohpm\bin
PATH=%TOOL_HOME%\tools\hvigor\bin
PATH=%TOOL_HOME%\tools\node
PATH=<flutter_flutter>\bin
```

Windows 下还要注意：Flutter 项目和依赖的插件项目尽量放在同一个磁盘。

## 7. 检查环境

执行：

```bash
flutter doctor -v
```

你需要看到 Flutter 和 OpenHarmony 相关检查通过。  
如果有缺失项，优先按 `flutter doctor` 的提示补环境变量或 SDK。

## 8. 创建 HarmonyOS 项目

```bash
flutter create --platforms ohos hello_ohos
cd hello_ohos
```

如果你还想同时生成 Android/iOS：

```bash
flutter create --platforms ohos,android,ios hello_ohos
```

## 9. 运行到 HarmonyOS 设备

先检查设备：

```bash
flutter devices
```

如果能看到 HarmonyOS / OpenHarmony 设备，运行：

```bash
flutter run --debug -d <device_id>
```

## 10. 构建 HAP

Debug 构建：

```bash
flutter build hap --debug
```

Release 构建：

```bash
flutter build hap --release
```

常见产物路径：

```text
ohos/entry/build/default/outputs/default/entry-default-signed.hap
```

也可以用 `hdc` 安装：

```bash
hdc -t <device_id> install <hap_file_path>
```

## 11. 常见问题

### 11.1 `flutter doctor` 找不到 OpenHarmony

重点检查：

1. `DEVECO_SDK_HOME` 是否正确
2. `ohpm`、`hvigor`、`node` 是否加入 PATH
3. 当前使用的是 OpenHarmony-SIG 适配版 Flutter SDK

### 11.2 构建时 hvigor 报 npmrc 错误

在用户目录创建 `.npmrc`：

```text
registry=https://repo.huaweicloud.com/repository/npm/
@ohos:registry=https://repo.harmonyos.com/npm/
```

### 11.3 真机识别不到

检查：

1. 设备是否开启开发者模式
2. USB 连接是否正常
3. `hdc list targets` 是否能看到设备
4. `flutter devices` 是否能看到设备

## 12. 参考资料

- OpenHarmony-SIG Flutter 适配仓库：<https://gitee.com/openharmony-sig/flutter_flutter>
- 新仓库地址提示：<https://gitcode.com/openharmony-sig/flutter_flutter>
- HarmonyOS DevEco Studio：<https://developer.huawei.com/consumer/cn/deveco-studio/>
