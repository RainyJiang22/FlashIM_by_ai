import 'app_config.dart';

abstract interface class LocalConfigStore {
  Future<LocalAppConfig> load();
}

class DefaultLocalConfigStore implements LocalConfigStore {
  const DefaultLocalConfigStore();

  @override
  Future<LocalAppConfig> load() async {
    return const LocalAppConfig(
      appName: 'Flash IM',
      apiBaseUrl: 'http://127.0.0.1:9600',
      enableDebugTools: false,
    );
  }
}
