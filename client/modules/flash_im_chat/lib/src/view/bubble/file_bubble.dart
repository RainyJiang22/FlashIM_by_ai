import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

import '../../data/message.dart';
import '../../logic/chat_state.dart';

class FileBubble extends StatelessWidget {
  const FileBubble({
    super.key,
    required this.message,
    required this.onTap,
    this.downloadInfo,
  });

  final Message message;
  final VoidCallback? onTap;
  final FileDownloadInfo? downloadInfo;

  @override
  Widget build(BuildContext context) {
    final extra = message.fileExtra;
    return Material(
      key: const Key('file_bubble'),
      color: FlashPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: FlashPalette.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 230,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(
                  Icons.insert_drive_file,
                  color: FlashPalette.primary,
                  size: 36,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        extra?.fileName.isNotEmpty == true
                            ? extra!.fileName
                            : message.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${extra?.formattedSize ?? '0 B'}  ${extra?.fileType.toUpperCase() ?? ''}',
                        style: const TextStyle(
                          color: FlashPalette.secondaryInk,
                          fontSize: 12,
                        ),
                      ),
                      if (downloadInfo?.status ==
                          FileDownloadStatus.downloading) ...[
                        const SizedBox(height: 6),
                        LinearProgressIndicator(value: downloadInfo!.progress),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _DownloadStatusIcon(info: downloadInfo),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadStatusIcon extends StatelessWidget {
  const _DownloadStatusIcon({this.info});
  final FileDownloadInfo? info;

  @override
  Widget build(BuildContext context) => switch (info?.status) {
    FileDownloadStatus.downloading => const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
    FileDownloadStatus.done => const Icon(
      Icons.check_circle,
      color: FlashPalette.success,
    ),
    FileDownloadStatus.error => const Icon(
      Icons.error_outline,
      color: FlashPalette.danger,
    ),
    _ => const Icon(Icons.download_outlined),
  };
}
