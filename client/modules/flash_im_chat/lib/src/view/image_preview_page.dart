import 'dart:io';

import 'package:flutter/material.dart';

class ImagePreviewPage extends StatelessWidget {
  const ImagePreviewPage({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final local = File(imageUrl).existsSync();
    final image = local
        ? Image.file(File(imageUrl), fit: BoxFit.contain)
        : Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white70,
              size: 56,
            ),
          );
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(minScale: 0.8, maxScale: 4, child: image),
        ),
      ),
    );
  }
}
