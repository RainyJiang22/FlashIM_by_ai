# IM Core v0.0.4_media — 客户端任务清单

基于 `docs/features/im/core/v0.0.4_media/client/design.md` 设计，拆出可直接执行的客户端实现清单。

全局约束：

- 只做图片、视频、文件三类消息；不实现语音、多图、本地缓存、撤回、长按菜单。
- 继续沿用当前正式 IM 链路：`HTTP 上传媒体` -> `WebSocket 发送消息元数据` -> `MESSAGE_ACK / CHAT_MESSAGE / CONVERSATION_UPDATE`。
- 保持 `flash_im_chat` 继续使用 Cubit，不引入 Event Bus 或额外状态框架。
- 历史消息、实时消息、自己发送中的本地占位消息，最终都收敛到同一个 `Message` 模型。
- 媒体上传逻辑按 design 放在 `MessageRepository`，不要额外再拆 `StorageRepository`。
- 文件下载状态由 `ChatState.fileDownloads` 统一管理，气泡与预览页共用同一份状态。
- 参考现有文本消息实现：
  - `client/modules/flash_im_chat/lib/src/data/message.dart`
  - `client/modules/flash_im_chat/lib/src/logic/chat_cubit.dart`
  - `client/modules/flash_im_chat/lib/src/view/message_bubble.dart`
  - `client/modules/flash_im_core/lib/src/logic/ws_client.dart`

---

## 执行顺序

1. ⬜ 任务 1 — 配置 `flash_im_chat` 依赖（无依赖）
2. ⬜ 任务 2 — 扩展消息模型 `message.dart`（依赖任务 1）
3. ⬜ 任务 3 — 扩展聊天状态 `chat_state.dart`（依赖任务 2）
4. ⬜ 任务 4 — 扩展仓储 `message_repository.dart`（依赖任务 2）
5. ⬜ 任务 5 — 新增视频元数据提取服务 `video_thumbnail_service.dart`（依赖任务 1）
6. ⬜ 任务 6 — 扩展 `WsClient` 媒体发送入口（依赖任务 2）
7. ⬜ 任务 7 — 改造 `ChatCubit` 媒体发送/接收/下载编排（依赖任务 3、4、5、6）
8. ⬜ 任务 8 — 改造 `ChatInput` 附件入口与功能面板（依赖任务 7）
9. ⬜ 任务 9 — 改造 `ChatPage` 组装媒体能力（依赖任务 7、8）
10. ⬜ 任务 10 — 拆分消息气泡组件（依赖任务 2、7、9）
11. ⬜ 任务 11 — 新增三类预览页（依赖任务 7、10）
12. ⬜ 任务 12 — 更新模块导出 `flash_im_chat.dart`（依赖任务 9、10、11）
13. ⬜ 任务 13 — Android 清流量配置（依赖任务 1）
14. ⬜ 任务 14 — 补齐单测与组件测试（依赖任务 2、4、7、10、11）
15. ⬜ 最后 — 编译验证 + 手工验收路径

---

## 任务 1：`client/modules/flash_im_chat/pubspec.yaml` — 新增媒体依赖 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_chat/pubspec.yaml`

改动类型：配置修改

### 1.1 增加依赖声明 `⬜`

在 `dependencies:` 下追加：

```yaml
image_picker: ^1.1.2
file_picker: ^8.1.7
video_player: ^2.9.2
fc_native_video_thumbnail: ^2.1.1
path_provider: ^2.1.5
```

说明：

- 保持 `dio`、`flutter_bloc`、`equatable` 现有版本不动。
- 不在根 `client/pubspec.yaml` 重复声明这些依赖，优先让 `flash_im_chat` 自洽。

---

## 任务 2：`client/modules/flash_im_chat/lib/src/data/message.dart` — 扩展富媒体消息模型 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_chat/lib/src/data/message.dart`

改动类型：修改文件

### 2.1 新增消息类型与扩展数据类 `⬜`

补充类型骨架：

```dart
enum MessageType { text, image, video, file }

class VideoExtra extends Equatable {
  const VideoExtra({
    required this.thumbnailUrl,
    required this.durationMs,
    required this.width,
    required this.height,
    required this.fileSize,
  });
}

class FileExtra extends Equatable {
  const FileExtra({
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.fileSize,
  });
}
```

### 2.2 扩展 `Message` 字段与工厂方法 `⬜`

在 `Message` 中增加：

```dart
final MessageType type;
final Map<String, dynamic>? extra;
```

需要同步更新：

- `const Message(...)`
- `factory Message.fromJson(...)`
- `factory Message.fromChatMessage(...)`
- `factory Message.local(...)`
- `copyWith(...)`
- `props`

### 2.3 增加便捷 getter 与 proto/type 映射 `⬜`

补骨架：

```dart
bool get isImage => type == MessageType.image;
bool get isVideo => type == MessageType.video;
bool get isFile => type == MessageType.file;

VideoExtra? get videoExtra => ...;
FileExtra? get fileExtra => ...;

static MessageType mapProtoType(int value) { ... }
static int mapToProtoType(MessageType type) { ... }
```

说明：

- 自定义 `MessageType` 继续与 UI 层隔离，不直接在业务层传播 proto enum。
- `content` 继续保留：文本为正文，媒体为 URL / 本地占位路径。

---

## 任务 3：`client/modules/flash_im_chat/lib/src/logic/chat_state.dart` — 扩展上传与文件下载状态 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_chat/lib/src/logic/chat_state.dart`

改动类型：修改文件

### 3.1 新增下载状态数据类 `⬜`

增加：

```dart
enum FileDownloadStatus { idle, downloading, done, error }

class FileDownloadInfo extends Equatable {
  const FileDownloadInfo({
    required this.status,
    required this.progress,
    this.localPath,
    this.error,
  });
}
```

### 3.2 扩展 `ChatLoaded` 字段与 `copyWith` `⬜`

新增字段：

```dart
final double? uploadProgress;
final Map<String, FileDownloadInfo> fileDownloads;
```

同步修改：

- 构造函数默认值
- `copyWith(...)`
- `props`

---

## 任务 4：`client/modules/flash_im_chat/lib/src/data/message_repository.dart` — 新增上传/下载能力 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_chat/lib/src/data/message_repository.dart`

改动类型：修改文件

### 4.1 扩展仓储接口 `⬜`

在 `abstract interface class MessageRepository` 中补充：

```dart
Future<ImageUploadResult> uploadImage(
  String filePath, {
  void Function(int sent, int total)? onProgress,
});

Future<VideoUploadResult> uploadVideo(
  String videoPath,
  String thumbPath,
  int durationMs, {
  int? width,
  int? height,
  void Function(int sent, int total)? onProgress,
});

Future<FileUploadResult> uploadFile(
  String filePath, {
  void Function(int sent, int total)? onProgress,
});

Future<String> downloadFile(
  String url,
  String savePath, {
  void Function(int received, int total)? onProgress,
});
```

### 4.2 增加上传结果模型与 JSON 解析 `⬜`

可放在同文件内的轻量模型：

```dart
class ImageUploadResult { ... }
class VideoUploadResult { ... }
class FileUploadResult { ... }
```

字段至少覆盖：

- 图片：`originalUrl / thumbnailUrl / width / height / size / format`
- 视频：`videoUrl / thumbnailUrl / durationMs / width / height / fileSize`
- 文件：`fileUrl / fileName / fileSize / fileType`

### 4.3 在 `DioMessageRepository` 中实现 multipart 上传与下载 `⬜`

关键骨架：

```dart
final formData = FormData.fromMap({
  'file': await MultipartFile.fromFile(filePath),
});

await _dio.post<dynamic>(
  '/api/upload/image',
  data: formData,
  onSendProgress: onProgress,
);

await _dio.download(
  url,
  savePath,
  onReceiveProgress: onProgress,
);
```

说明：

- 历史消息 `getMessages()` 同时要把 `msg_type + extra` 映射为新的 `Message.fromJson(...)`。
- 继续只接受正式 `/conversations/{id}/messages`，不要误接 playground `/conversation`。

---

## 任务 5：`client/modules/flash_im_chat/lib/src/data/video_thumbnail_service.dart` — 新增视频元数据提取服务 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_chat/lib/src/data/video_thumbnail_service.dart`

改动类型：新建文件

### 5.1 定义结果对象与服务接口 `⬜`

```dart
class VideoThumbnailInfo {
  const VideoThumbnailInfo({
    required this.thumbnailPath,
    required this.durationMs,
    required this.width,
    required this.height,
  });
}

abstract interface class VideoThumbnailService {
  Future<VideoThumbnailInfo> extract(String videoPath);
}
```

### 5.2 提供基于插件的默认实现 `⬜`

关键步骤：

1. 用 `fc_native_video_thumbnail` 提取首帧缩略图
2. 用 `video_player` 临时初始化控制器读取 `duration` 和 `size`
3. 用 `path_provider` 组织缩略图缓存路径

骨架：

```dart
class NativeVideoThumbnailService implements VideoThumbnailService {
  @override
  Future<VideoThumbnailInfo> extract(String videoPath) async {
    // 1. prepare temp dir
    // 2. generate thumbnail file
    // 3. init VideoPlayerController.file
    // 4. read duration/size
    // 5. dispose controller
  }
}
```

---

## 任务 6：`client/modules/flash_im_core/lib/src/logic/ws_client.dart` — 扩展媒体发送入口 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_core/lib/src/logic/ws_client.dart`

改动类型：修改文件

### 6.1 新增媒体友好的发送包装方法 `⬜`

在不破坏现有 `sendChatMessage(SendMessageRequest request)` 的前提下，增加包装：

```dart
void sendMessage({
  required String conversationId,
  required String content,
  required int type,
  List<int>? extra,
  String? clientId,
}) {
  sendChatMessage(
    SendMessageRequest(
      conversationId: conversationId,
      type: type,
      content: content,
      extra: extra == null ? '' : utf8.decode(extra),
      clientId: clientId ?? '',
    ),
  );
}
```

说明：

- 保留 `sendChatMessage`，避免影响已有文本链路和现有测试。
- 新包装方法供 `ChatCubit` 直接调用。

---

## 任务 7：`client/modules/flash_im_chat/lib/src/logic/chat_cubit.dart` — 编排媒体发送/接收/下载状态 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_chat/lib/src/logic/chat_cubit.dart`

改动类型：修改文件

### 7.1 注入新依赖并扩展构造器 `⬜`

新增字段：

```dart
final VideoThumbnailService _videoThumbnailService;
```

构造器增加：

```dart
required VideoThumbnailService videoThumbnailService,
```

### 7.2 新增媒体发送入口 `⬜`

增加方法签名：

```dart
Future<void> sendImageFromFile(String filePath);
Future<void> sendVideoFromFile(String filePath);
Future<void> sendFileFromPicker(String filePath);
Future<void> downloadFile(String messageId, String fileUrl, String fileName);
FileDownloadInfo? getDownloadInfo(String messageId);
```

### 7.3 媒体发送状态机骨架 `⬜`

以图片为例写骨架步骤：

```dart
// 1. create local placeholder Message(type=image, content=filePath, status=sending)
// 2. emit uploadProgress updates
// 3. await repository.uploadImage(...)
// 4. update message.extra with server metadata
// 5. wsClient.sendMessage(type: 1, content: originalUrl, extra: utf8.encode(json))
// 6. ack success -> status sent
// 7. failure -> mark failed
```

视频流程额外接 `videoThumbnailService.extract(filePath)`；文件流程用文件名占位。

### 7.4 扩展 ACK 与实时接收处理 `⬜`

修改：

- `_handleAck(...)`
- `_handleIncomingMessage(...)`
- `_sortMessages(...)`

接收消息时要解析：

```dart
final type = Message.mapProtoType(message.type);
final extra = message.extra.isEmpty
    ? null
    : jsonDecode(message.extra) as Map<String, dynamic>;
```

### 7.5 扩展文件下载状态更新 `⬜`

`downloadFile(...)` 需要：

1. 先把 `fileDownloads[messageId]` 置为 `downloading`
2. 按 `onReceiveProgress` 更新 `progress`
3. 下载成功写 `done + localPath`
4. 下载失败写 `error`

---

## 任务 8：`client/modules/flash_im_chat/lib/src/view/chat_input.dart` — 附件按钮与功能面板 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_chat/lib/src/view/chat_input.dart`

改动类型：修改文件

### 8.1 扩展组件回调签名 `⬜`

把组件接口扩为：

```dart
final ValueChanged<String> onSend;
final ValueChanged<String> onSendImage;
final ValueChanged<String> onSendVideo;
final ValueChanged<String> onSendFile;
```

### 8.2 新增 “+” 按钮与底部功能面板 `⬜`

关键结构骨架：

```dart
Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Row(
      children: [
        IconButton(icon: Icon(Icons.add)), 
        Expanded(child: TextField(...)),
        FilledButton(...)
      ],
    ),
    AnimatedContainer(
      height: _panelVisible ? 112 : 0,
      child: Row(
        children: [
          _ActionItem(label: '照片'),
          _ActionItem(label: '拍照'),
          _ActionItem(label: '视频'),
          _ActionItem(label: '文件'),
        ],
      ),
    ),
  ],
)
```

### 8.3 接入 picker 并回调到 Cubit `⬜`

动作映射：

- 照片/拍照：`ImagePicker.pickImage`
- 视频：`ImagePicker.pickVideo`
- 文件：`FilePicker.pickFiles`

只传 `file.path` 给上层，不在 View 层做上传。

---

## 任务 9：`client/modules/flash_im_chat/lib/src/view/chat_page.dart` — 组装媒体能力与新回调 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_chat/lib/src/view/chat_page.dart`

改动类型：修改文件

### 9.1 构造 `ChatCubit` 时注入 `VideoThumbnailService` `⬜`

骨架：

```dart
create: (context) => ChatCubit(
  repository: context.read<MessageRepository>(),
  wsClient: context.read<WsClient>(),
  conversation: conversation,
  currentUserId: currentUserId,
  currentUserName: currentUserName,
  currentUserAvatar: currentUserAvatar,
  videoThumbnailService: NativeVideoThumbnailService(),
)..loadMessages(),
```

### 9.2 把媒体回调传给 `ChatInput` 与 `MessageBubble` `⬜`

```dart
ChatInput(
  onSend: context.read<ChatCubit>().sendText,
  onSendImage: context.read<ChatCubit>().sendImageFromFile,
  onSendVideo: context.read<ChatCubit>().sendVideoFromFile,
  onSendFile: context.read<ChatCubit>().sendFileFromPicker,
)
```

`MessageBubble` 需要额外传：

- `onOpenImage`
- `onOpenVideo`
- `onOpenFile`
- `downloadInfo`

---

## 任务 10：消息气泡拆分 — 文本/图片/视频/文件 `⬜ 待处理`

文件：

- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_chat/lib/src/view/bubble/message_bubble.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_chat/lib/src/view/bubble/text_bubble.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_chat/lib/src/view/bubble/image_bubble.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_chat/lib/src/view/bubble/video_bubble.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_chat/lib/src/view/bubble/file_bubble.dart`

改动类型：1 个修改 + 4 个新建（紧耦合任务）

### 10.1 新建 `text_bubble.dart`，迁移现有文本气泡结构 `⬜`

保留当前文本气泡的圆角、头像、状态图标风格，不改变文本消息视觉。

### 10.2 改造 `message_bubble.dart` 为外壳 + 分发入口 `⬜`

分发骨架：

```dart
switch (message.type) {
  case MessageType.text:
    return TextBubble(...);
  case MessageType.image:
    return ImageBubble(...);
  case MessageType.video:
    return VideoBubble(...);
  case MessageType.file:
    return FileBubble(...);
}
```

### 10.3 新建 `image_bubble.dart` `⬜`

关键结构：

```dart
GestureDetector(
  onTap: onTap,
  child: Stack(
    children: [
      ClipRRect(child: imageWidget),
      if (message.status == MessageStatus.sending) _UploadingMask(...),
    ],
  ),
)
```

图片来源优先级：

1. 自己发送中的本地路径 -> `Image.file`
2. `extra.thumbnail_url`
3. `content` 中服务端 URL

### 10.4 新建 `video_bubble.dart` `⬜`

需要展示：

- 缩略图
- 播放按钮
- 时长文案
- sending/failed 状态

### 10.5 新建 `file_bubble.dart` `⬜`

需要展示：

- 文件图标
- 文件名 / 文件大小 / 文件类型
- 下载状态图标或进度条
- 点击进入文件预览页

---

## 任务 11：预览页组 — 图片 / 视频 / 文件 `⬜ 待处理`

文件：

- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_chat/lib/src/view/image_preview_page.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_chat/lib/src/view/video_player_page.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_chat/lib/src/view/file_preview_page.dart`

改动类型：新建文件

### 11.1 新建 `image_preview_page.dart` `⬜`

骨架：

```dart
Scaffold(
  backgroundColor: Colors.black,
  body: SafeArea(
    child: InteractiveViewer(
      child: imageWidget,
    ),
  ),
)
```

### 11.2 新建 `video_player_page.dart` `⬜`

骨架：

```dart
class VideoPlayerPage extends StatefulWidget { ... }

// init VideoPlayerController.file / .networkUrl
// initialize -> AspectRatio -> VideoPlayer
// simple play / pause overlay
```

### 11.3 新建 `file_preview_page.dart` `⬜`

骨架：

```dart
BlocBuilder<ChatCubit, ChatState>(
  builder: (_, state) {
    final info = state.fileDownloads[message.id];
    // show file name, size, type, progress, local path, download button
  },
)
```

说明：

- 文件预览页只负责展示和触发下载，不直接做网络请求。

---

## 任务 12：`client/modules/flash_im_chat/lib/flash_im_chat.dart` — 更新模块导出 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_chat/lib/flash_im_chat.dart`

改动类型：修改文件

### 12.1 导出新模型与页面 `⬜`

补充导出：

```dart
export 'src/data/message.dart'
    show Message, MessageStatus, MessageType, VideoExtra, FileExtra;
export 'src/data/video_thumbnail_service.dart'
    show VideoThumbnailInfo, VideoThumbnailService, NativeVideoThumbnailService;
export 'src/logic/chat_state.dart'
    show FileDownloadInfo, FileDownloadStatus;
```

说明：

- 只导出外部需要直接引用的类型。

---

## 任务 13：`client/android/app/src/main/AndroidManifest.xml` — 允许明文视频访问 `⬜ 待处理`

文件：`/Users/rainyjiang/AndroidStudioProjects/flash_im/client/android/app/src/main/AndroidManifest.xml`

改动类型：配置修改

### 13.1 在 `<application>` 上增加 cleartext 开关 `⬜`

```xml
<application
    android:name="${applicationName}"
    android:label="flash_im"
    android:icon="@mipmap/ic_launcher"
    android:usesCleartextTraffic="true">
```

说明：

- 仅按 design 处理 Android。
- 本任务不扩展 iOS ATS 配置。

---

## 任务 14：客户端测试补齐 `⬜ 待处理`

文件：

- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_chat/test/message_test.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_chat/test/message_repository_test.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_chat/test/chat_cubit_test.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_chat/test/message_bubble_test.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_chat/test/chat_page_test.dart`
- `/Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_core/test/ws_client_test.dart`

改动类型：修改文件

### 14.1 `message_test.dart` — 覆盖类型映射与 extra 解析 `⬜`

至少补：

- `Message.fromJson` 解析图片/视频/文件
- `videoExtra` / `fileExtra` getter
- `local` 消息类型创建

### 14.2 `message_repository_test.dart` — 覆盖上传/下载 API shape `⬜`

至少补：

- `uploadImage` 解析响应
- `uploadVideo` 解析响应
- `uploadFile` 解析响应
- `downloadFile` 调用下载参数

### 14.3 `chat_cubit_test.dart` — 覆盖媒体发送与文件下载状态 `⬜`

至少补：

- 图片上传成功 -> 发送 -> ACK
- 视频缩略图提取后上传
- 文件下载状态 `idle -> downloading -> done/error`

### 14.4 `message_bubble_test.dart` / `chat_page_test.dart` — 覆盖 UI 分发与功能面板 `⬜`

至少补：

- `MessageType` 对应正确 bubble
- `+` 按钮展开功能面板
- 文件气泡展示下载状态

### 14.5 `ws_client_test.dart` — 覆盖媒体发送包装方法 `⬜`

至少补：

- `sendMessage(type, content, extra)` 最终封装成 `SendMessageRequest`

---

## 最后：编译验证 + 测试路径 `⬜ 待处理`

按顺序执行：

```bash
cd /Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_chat
flutter pub get
flutter analyze
flutter test
```

```bash
cd /Users/rainyjiang/AndroidStudioProjects/flash_im/client/modules/flash_im_core
flutter analyze
flutter test
```

```bash
cd /Users/rainyjiang/AndroidStudioProjects/flash_im/client
flutter analyze lib test
```

手工验收路径：

1. 打开聊天页，点击 `+`，确认出现“照片 / 拍照 / 视频 / 文件”
2. 选择图片，确认出现本地图片占位 + 上传进度 + ACK 后 sent
3. 选择视频，确认缩略图、时长、播放页正常
4. 选择文件，确认文件卡片、预览页、下载进度正常
5. 接收方实时收到三类媒体消息并渲染正确
6. 回到会话列表，确认 preview 为 `[图片] / [视频] / [文件]`
7. 退出聊天页再进入，确认历史消息仍可正确渲染

