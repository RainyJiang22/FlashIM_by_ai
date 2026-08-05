import 'dart:io';

import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

import '../../data/message.dart';

class ImageBubble extends StatelessWidget {
  const ImageBubble({
    super.key,
    required this.message,
    required this.onTap,
    this.uploadProgress,
  });

  final Message message;
  final VoidCallback? onTap;
  final double? uploadProgress;

  @override
  Widget build(BuildContext context) {
    final source = message.content;
    final local = File(source).existsSync();
    final thumbnail = '${message.extra?['thumbnail_url'] ?? ''}';
    final image = local
        ? Image.file(File(source), fit: BoxFit.cover)
        : Image.network(
            thumbnail.isNotEmpty ? thumbnail : source,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: FlashPalette.primarySoft,
              child: Center(child: Icon(Icons.broken_image_outlined)),
            ),
          );
    return GestureDetector(
      key: const Key('image_bubble'),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 190,
          height: 150,
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              if (message.status == MessageStatus.sending &&
                  uploadProgress != null)
                ColoredBox(
                  color: Colors.black38,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: uploadProgress,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
