import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/message.dart';

class VideoBubble extends StatelessWidget {
  const VideoBubble({
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
    final local = File(message.content).existsSync();
    final thumbnail = '${message.extra?['thumbnail_url'] ?? ''}';
    final image = local
        ? Image.file(File(message.content), fit: BoxFit.cover)
        : Image.network(
            thumbnail,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: Color(0xFF202124),
              child: Center(
                child: Icon(Icons.videocam_off_outlined, color: Colors.white70),
              ),
            ),
          );
    return GestureDetector(
      key: const Key('video_bubble'),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 200,
          height: 140,
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              const ColoredBox(color: Colors.black12),
              const Center(
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.play_arrow, color: Colors.white),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 6,
                child: Text(
                  message.videoExtra?.formattedDuration ?? '0:00',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              if (message.status == MessageStatus.sending &&
                  uploadProgress != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: LinearProgressIndicator(
                    value: uploadProgress,
                    minHeight: 4,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
