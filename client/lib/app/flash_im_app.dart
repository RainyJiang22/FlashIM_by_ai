import 'package:flash_auth/flash_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/config/app_config.dart';
import '../core/config/local_config_store.dart';
import '../core/network/dio_factory.dart';
import 'app_router.dart';

class FlashImApp extends StatefulWidget {
  const FlashImApp({
    super.key,
    this.appConfig,
    this.authRepository,
    this.appSessionCubit,
  });

  final LocalAppConfig? appConfig;
  final AuthRepository? authRepository;
  final AppSessionCubit? appSessionCubit;

  @override
  State<FlashImApp> createState() => _FlashImAppState();
}

class _FlashImAppState extends State<FlashImApp> {
  late final Future<LocalAppConfig> _configFuture;
  AuthRepository? _defaultAuthRepository;
  AppSessionCubit? _defaultAppSessionCubit;

  @override
  void initState() {
    super.initState();
    _configFuture = widget.appConfig != null
        ? Future<LocalAppConfig>.value(widget.appConfig)
        : const DefaultLocalConfigStore().load();
  }

  @override
  void dispose() {
    _defaultAppSessionCubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const appBackgroundColor = Color(0xFFF6F7F9);
    const appPrimaryColor = Color(0xFF1C4EFF);
    const appSurfaceColor = Colors.white;
    const appMutedBlue = Color(0xFFEAF1FF);
    const appOutlineColor = Color(0xFFD5E2F3);
    const appTextPrimary = Color(0xFF1A2A42);
    const appTextSecondary = Color(0xFF6A7B92);

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: appPrimaryColor,
            brightness: Brightness.light,
          ).copyWith(
            primary: appPrimaryColor,
            onPrimary: Colors.white,
            primaryContainer: appMutedBlue,
            onPrimaryContainer: appTextPrimary,
            surface: appSurfaceColor,
            onSurface: appTextPrimary,
            secondary: const Color(0xFF5B8CFF),
            outline: appOutlineColor,
          ),
      scaffoldBackgroundColor: appBackgroundColor,
      canvasColor: appBackgroundColor,
      cardColor: appSurfaceColor,
      dividerColor: const Color(0xFFE7EEF7),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: appPrimaryColor,
        selectionColor: Color(0x331C4EFF),
        selectionHandleColor: appPrimaryColor,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: appPrimaryColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: appBackgroundColor,
        surfaceTintColor: Colors.transparent,
        foregroundColor: appTextPrimary,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: appSurfaceColor,
        labelStyle: const TextStyle(
          color: appTextSecondary,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: const TextStyle(
          color: appPrimaryColor,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF98A7BA),
          fontWeight: FontWeight.w500,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: appOutlineColor, width: 1.4),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: appOutlineColor, width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: appPrimaryColor, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE35D6A), width: 1.6),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE35D6A), width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: appPrimaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFD8E1F0),
          disabledForegroundColor: const Color(0xFF8A9AB0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: appPrimaryColor,
          side: const BorderSide(color: appOutlineColor, width: 1.4),
          backgroundColor: appSurfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: appSurfaceColor,
        surfaceTintColor: Colors.transparent,
        indicatorColor: appMutedBlue,
        height: 74,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? appPrimaryColor : appTextSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? appPrimaryColor : appTextSecondary,
            size: 22,
          );
        }),
      ),
    );

    return FutureBuilder<LocalAppConfig>(
      future: _configFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData && widget.authRepository == null) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final config =
            widget.appConfig ??
            snapshot.data ??
            const LocalAppConfig(
              appName: 'Flash IM',
              apiBaseUrl: 'http://127.0.0.1:9600',
              enableDebugTools: false,
            );
        final authRepository =
            widget.authRepository ??
            (_defaultAuthRepository ??= DefaultAuthRepository(
              api: DioAuthApi(
                dio: DioFactory.create(baseUrl: config.apiBaseUrl),
              ),
              cacheStore: const SharedPreferencesAuthCacheStore(),
            ));
        final appSessionCubit =
            widget.appSessionCubit ??
            (_defaultAppSessionCubit ??= AppSessionCubit(
              repository: authRepository,
            ));

        return RepositoryProvider<AuthRepository>.value(
          value: authRepository,
          child: BlocProvider<AppSessionCubit>.value(
            value: appSessionCubit,
            child: MaterialApp(
              title: config.appName,
              debugShowCheckedModeBanner: false,
              theme: theme,
              initialRoute: AppRoutes.startup,
              onGenerateRoute: onGenerateAppRoute,
            ),
          ),
        );
      },
    );
  }
}
