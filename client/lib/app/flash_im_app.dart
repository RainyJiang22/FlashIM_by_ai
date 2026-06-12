import 'package:flutter/material.dart';

import '../features/startup/data/startup_coordinator_impl.dart';
import 'app_router.dart';

class FlashImApp extends StatelessWidget {
  const FlashImApp({super.key, this.startupCoordinator});

  final StartupCoordinator? startupCoordinator;

  @override
  Widget build(BuildContext context) {
    const appBackgroundColor = Color(0xFFF6F7F9);

    return MaterialApp(
      title: 'Flash IM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF7A18),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: appBackgroundColor,
        canvasColor: appBackgroundColor,
      ),
      initialRoute: AppRoutes.startup,
      onGenerateRoute: (settings) =>
          onGenerateAppRoute(settings, startupCoordinator: startupCoordinator),
    );
  }
}
