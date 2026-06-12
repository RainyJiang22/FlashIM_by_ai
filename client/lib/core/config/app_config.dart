class LocalAppConfig {
  const LocalAppConfig({
    required this.appName,
    required this.apiBaseUrl,
    required this.enableDebugTools,
  });

  final String appName;
  final String apiBaseUrl;
  final bool enableDebugTools;
}
