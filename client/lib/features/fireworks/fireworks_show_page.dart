import 'package:flutter/material.dart';

import 'widgets/fireworks_show_scene.dart';

class FireworksShowPage extends StatelessWidget {
  const FireworksShowPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: FireworksShowScene()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: '返回',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
