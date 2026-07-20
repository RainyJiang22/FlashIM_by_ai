import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({super.key, required this.videoUrl});

  final String videoUrl;

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialized;
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
    try {
      await _controller.seekTo(Duration(milliseconds: milliseconds.round()));
    } finally {
      if (mounted) {
        setState(() {
          _isDragging = false;
          _dragPosition = _controller.value.position;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
      ),
      body: FutureBuilder<void>(
        future: _initialized,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('视频加载失败', style: TextStyle(color: Colors.white)),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final duration = _controller.value.duration;
          final position = _isDragging
              ? _dragPosition
              : _controller.value.position;
          final durationMilliseconds = duration.inMilliseconds;
          final sliderValue = position.inMilliseconds
              .clamp(0, durationMilliseconds)
              .toDouble();

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
                                    ? () =>
                                          _seekBy(const Duration(seconds: -10))
                                    : null,
                                icon: const Icon(Icons.replay_10),
                                color: Colors.white,
                              ),
                              const SizedBox(width: 20),
                              IconButton.filled(
                                tooltip: _controller.value.isPlaying
                                    ? '暂停'
                                    : '播放',
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
        },
      ),
    );
  }
}
