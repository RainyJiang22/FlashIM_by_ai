# Video Player Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为聊天视频播放详情页增加可拖动进度条、播放/暂停、后退 10 秒和快进 10 秒控制。

**Architecture:** 保留现有 `VideoPlayerController` 和本地/网络视频初始化逻辑，在 `VideoPlayerPage` 内监听播放状态并绘制原生 Flutter 控制栏。把无平台依赖的时间格式化与跳转边界计算保留为顶层函数，以便无需初始化原生播放器即可进行单元测试。

**Tech Stack:** Flutter、Dart、`video_player`、`flutter_test`

---

## 文件结构

- Modify: `client/modules/flash_im_chat/lib/src/view/video_player_page.dart` — 播放状态监听、时间/跳转计算和控制栏 UI。
- Create: `client/modules/flash_im_chat/test/video_player_page_test.dart` — 时间格式化及快退/快进边界测试。

### Task 1: 为时间与跳转计算补充测试

**Files:**
- Modify: `client/modules/flash_im_chat/lib/src/view/video_player_page.dart`
- Create: `client/modules/flash_im_chat/test/video_player_page_test.dart`

- [ ] **Step 1: 写入失败测试**

```dart
import 'package:flash_im_chat/src/view/video_player_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatVideoDuration', () {
    test('formats minute duration', () {
      expect(formatVideoDuration(const Duration(seconds: 65)), '01:05');
    });

    test('formats hour duration', () {
      expect(
        formatVideoDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '01:02:03',
      );
    });
  });

  group('offsetVideoPosition', () {
    const duration = Duration(seconds: 30);

    test('moves position by the requested offset', () {
      expect(
        offsetVideoPosition(
          position: const Duration(seconds: 15),
          duration: duration,
          offset: const Duration(seconds: 10),
        ),
        const Duration(seconds: 25),
      );
    });

    test('clamps rewind to zero', () {
      expect(
        offsetVideoPosition(
          position: const Duration(seconds: 5),
          duration: duration,
          offset: const Duration(seconds: -10),
        ),
        Duration.zero,
      );
    });

    test('clamps fast forward to duration', () {
      expect(
        offsetVideoPosition(
          position: const Duration(seconds: 25),
          duration: duration,
          offset: const Duration(seconds: 10),
        ),
        duration,
      );
    });
  });
}
```

- [ ] **Step 2: 运行测试并确认失败原因**

Run:

```bash
cd client/modules/flash_im_chat
flutter test test/video_player_page_test.dart
```

Expected: FAIL，提示 `formatVideoDuration` 和 `offsetVideoPosition` 未定义。

- [ ] **Step 3: 实现纯计算函数**

在 `video_player_page.dart` 的 import 之后加入：

```dart
String formatVideoDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

Duration offsetVideoPosition({
  required Duration position,
  required Duration duration,
  required Duration offset,
}) {
  final target = position + offset;
  if (target < Duration.zero) return Duration.zero;
  if (target > duration) return duration;
  return target;
}
```

- [ ] **Step 4: 运行针对性测试并确认通过**

Run:

```bash
cd client/modules/flash_im_chat
flutter test test/video_player_page_test.dart
```

Expected: PASS，5 个测试全部通过。

- [ ] **Step 5: 提交纯逻辑与测试**

```bash
git add client/modules/flash_im_chat/lib/src/view/video_player_page.dart client/modules/flash_im_chat/test/video_player_page_test.dart
git commit --only client/modules/flash_im_chat/lib/src/view/video_player_page.dart client/modules/flash_im_chat/test/video_player_page_test.dart -m "test: cover video playback seek controls"
```

### Task 2: 实现视频播放控制栏

**Files:**
- Modify: `client/modules/flash_im_chat/lib/src/view/video_player_page.dart`
- Test: `client/modules/flash_im_chat/test/video_player_page_test.dart`

- [ ] **Step 1: 增加播放器状态监听与拖动状态**

在 `_VideoPlayerPageState` 中增加状态，并在初始化、销毁时成对管理监听：

```dart
bool _isDragging = false;
Duration _dragPosition = Duration.zero;

@override
void initState() {
  super.initState();
  final file = File(widget.videoUrl);
  _controller = file.existsSync()
      ? VideoPlayerController.file(file)
      : VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
  _controller.addListener(_handleControllerChanged);
  _initialized = _controller.initialize().then((_) {
    if (mounted) setState(() {});
  });
}

void _handleControllerChanged() {
  if (!mounted || _isDragging) return;
  setState(() {});
}

@override
void dispose() {
  _controller.removeListener(_handleControllerChanged);
  _controller.dispose();
  super.dispose();
}
```

- [ ] **Step 2: 增加播放、快退、快进和拖动方法**

```dart
Future<void> _togglePlayback() async {
  if (_controller.value.isPlaying) {
    await _controller.pause();
    return;
  }
  if (_controller.value.position >= _controller.value.duration) {
    await _controller.seekTo(Duration.zero);
  }
  await _controller.play();
}

Future<void> _seekBy(Duration offset) {
  return _controller.seekTo(
    offsetVideoPosition(
      position: _controller.value.position,
      duration: _controller.value.duration,
      offset: offset,
    ),
  );
}

void _startDragging(double milliseconds) {
  setState(() {
    _isDragging = true;
    _dragPosition = Duration(milliseconds: milliseconds.round());
  });
}

void _updateDragging(double milliseconds) {
  setState(() {
    _dragPosition = Duration(milliseconds: milliseconds.round());
  });
}

Future<void> _finishDragging(double milliseconds) async {
  await _controller.seekTo(
    Duration(milliseconds: milliseconds.round()),
  );
  if (!mounted) return;
  setState(() {
    _isDragging = false;
    _dragPosition = _controller.value.position;
  });
}
```

- [ ] **Step 3: 用控制完整的 Stack 替换初始化成功后的旧 GestureDetector**

初始化完成后计算安全的显示位置：

```dart
final duration = _controller.value.duration;
final position = _isDragging ? _dragPosition : _controller.value.position;
final durationMilliseconds = duration.inMilliseconds;
final sliderValue = position.inMilliseconds
    .clamp(0, durationMilliseconds)
    .toDouble();
```

返回包含画面、中央播放图标和底部控制区的 UI：

```dart
return Stack(
  fit: StackFit.expand,
  children: [
    Center(
      child: GestureDetector(
        onTap: _togglePlayback,
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio == 0
              ? 16 / 9
              : _controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller),
              if (!_controller.value.isPlaying)
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.black54,
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      formatVideoDuration(position),
                      style: const TextStyle(color: Colors.white),
                    ),
                    Expanded(
                      child: Slider(
                        value: sliderValue,
                        max: durationMilliseconds > 0
                            ? durationMilliseconds.toDouble()
                            : 1,
                        onChangeStart: durationMilliseconds > 0
                            ? _startDragging
                            : null,
                        onChanged: durationMilliseconds > 0
                            ? _updateDragging
                            : null,
                        onChangeEnd: durationMilliseconds > 0
                            ? _finishDragging
                            : null,
                      ),
                    ),
                    Text(
                      formatVideoDuration(duration),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: '后退 10 秒',
                      onPressed: durationMilliseconds > 0
                          ? () => _seekBy(const Duration(seconds: -10))
                          : null,
                      icon: const Icon(Icons.replay_10),
                      color: Colors.white,
                    ),
                    const SizedBox(width: 20),
                    IconButton.filled(
                      tooltip: _controller.value.isPlaying ? '暂停' : '播放',
                      onPressed: _togglePlayback,
                      icon: Icon(
                        _controller.value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                      ),
                    ),
                    const SizedBox(width: 20),
                    IconButton(
                      tooltip: '快进 10 秒',
                      onPressed: durationMilliseconds > 0
                          ? () => _seekBy(const Duration(seconds: 10))
                          : null,
                      icon: const Icon(Icons.forward_10),
                      color: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ],
);
```

- [ ] **Step 4: 格式化并运行针对性验证**

Run:

```bash
cd client/modules/flash_im_chat
dart format lib/src/view/video_player_page.dart test/video_player_page_test.dart
flutter analyze
flutter test test/video_player_page_test.dart
```

Expected: `flutter analyze` 显示 `No issues found!`，针对性测试 5 个全部通过。

- [ ] **Step 5: 提交播放器控制 UI**

```bash
git add client/modules/flash_im_chat/lib/src/view/video_player_page.dart
git commit --only client/modules/flash_im_chat/lib/src/view/video_player_page.dart -m "feat: add video playback controls"
```

### Task 3: 完成模块回归验证

**Files:**
- Verify: `client/modules/flash_im_chat/lib/src/view/video_player_page.dart`
- Verify: `client/modules/flash_im_chat/test/video_player_page_test.dart`

- [ ] **Step 1: 检查差异范围与空白错误**

Run:

```bash
git diff HEAD~2 --check -- client/modules/flash_im_chat/lib/src/view/video_player_page.dart client/modules/flash_im_chat/test/video_player_page_test.dart
git diff HEAD~2 --stat -- client/modules/flash_im_chat/lib/src/view/video_player_page.dart client/modules/flash_im_chat/test/video_player_page_test.dart
```

Expected: 无空白错误，差异只包含视频详情页与新增测试文件。

- [ ] **Step 2: 顺序运行完整模块验证**

Run:

```bash
cd client/modules/flash_im_chat
flutter analyze
flutter test
```

Expected: 静态分析零问题，模块全部测试通过。

- [ ] **Step 3: 确认未包含用户已有工作区内容**

Run:

```bash
git status --short
```

Expected: 用户原有的 Python 缓存暂存项和 `server/uploads/` 未跟踪目录仍保持原状，没有进入本功能提交。

## 执行结果

- 已完成视频进度拖动、播放/暂停、后退 10 秒和快进 10 秒。
- `flutter analyze`：通过，零问题。
- `flutter test`：通过，31 个测试全部成功，其中新增播放器边界测试 5 个。
- 实现提交：`5a30cfd feat: add video playback controls`。
