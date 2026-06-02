import 'package:flutter/material.dart';

import '../playground/playground_home_page.dart';

class FlashImApp extends StatelessWidget {
  const FlashImApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flash_im',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF7A18),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF090B16),
      ),
      home: const PlaygroundHomePage(),
    );
  }
}
