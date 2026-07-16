import 'dart:io';

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class VideoThumbnailInfo {
  const VideoThumbnailInfo({
    required this.thumbnailPath,
    required this.durationMs,
    required this.width,
    required this.height,
  });

  final String thumbnailPath;
  final int durationMs;
  final int width;
  final int height;
}

abstract interface class VideoThumbnailService {
  Future<VideoThumbnailInfo> extract(String videoPath);
}

class NativeVideoThumbnailService implements VideoThumbnailService {
  NativeVideoThumbnailService({FcNativeVideoThumbnail? thumbnailer})
    : _thumbnailer = thumbnailer ?? FcNativeVideoThumbnail();

  final FcNativeVideoThumbnail _thumbnailer;

  @override
  Future<VideoThumbnailInfo> extract(String videoPath) async {
    final temp = await getTemporaryDirectory();
    final thumbnailPath =
        '${temp.path}/flash_im_thumb_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final generated = await _thumbnailer.saveThumbnailToFile(
      srcFile: videoPath,
      destFile: thumbnailPath,
      width: 640,
      height: 640,
      quality: 85,
    );
    if (!generated || !File(thumbnailPath).existsSync()) {
      throw StateError('无法生成视频缩略图');
    }

    final controller = VideoPlayerController.file(File(videoPath));
    try {
      await controller.initialize();
      return VideoThumbnailInfo(
        thumbnailPath: thumbnailPath,
        durationMs: controller.value.duration.inMilliseconds,
        width: controller.value.size.width.round(),
        height: controller.value.size.height.round(),
      );
    } finally {
      await controller.dispose();
    }
  }
}
