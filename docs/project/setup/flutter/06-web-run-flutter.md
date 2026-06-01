# 在 Web 平台运行 Flutter 项目

## 1. 前置条件

你需要：

- 已安装 Flutter SDK
- 已安装 Chrome 或 Microsoft Edge

Flutter 官方推荐用 Chrome 或 Edge 调试 Web。

## 2. 检查浏览器设备

执行：

```bash
flutter devices
```

正常情况下会看到类似：

```text
Chrome (web) • chrome • web-javascript • Google Chrome
```

如果没有看到 Chrome 或 Edge，先确认浏览器已安装，并重新打开终端。

## 3. 创建并运行项目

```bash
flutter create hello_flutter
cd hello_flutter
flutter run -d chrome
```

如果使用 Edge：

```bash
flutter run -d edge
```

## 4. 使用 web-server 模式

如果你想用其他浏览器访问，可以运行：

```bash
flutter run -d web-server
```

终端会打印一个本地地址，例如：

```text
http://localhost:12345
```

然后用浏览器打开这个地址。

## 5. 构建 Web 产物

```bash
flutter build web
```

构建结果在：

```text
build/web/
```

这个目录就是可以部署到静态网站服务器的文件。

## 6. 常见问题

### 6.1 `flutter devices` 看不到 Chrome

处理：

1. 确认 Chrome 已安装
2. 关闭终端重新打开
3. 执行 `flutter doctor -v`
4. 执行 `flutter devices`

### 6.2 Web 页面空白

先尝试：

```bash
flutter clean
flutter pub get
flutter run -d chrome
```

如果依然空白，打开浏览器开发者工具查看 Console 错误。

### 6.3 Web 访问后端接口失败

常见原因是跨域限制。

解决方向：

- 后端配置 CORS
- Web 调试时确认接口地址正确
- 不要在真机或 Web 里写死 `127.0.0.1` 访问电脑上的后端

## 7. 参考资料

- Web 开发配置：<https://docs.flutter.dev/platform-integration/web/setup>
- Web 构建发布：<https://docs.flutter.dev/deployment/web>
