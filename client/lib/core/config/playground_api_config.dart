class PlaygroundApiConfig {
  const PlaygroundApiConfig._();

  static const String defaultBaseUrl = String.fromEnvironment(
    'PLAYGROUND_SERVER_BASE_URL',
    defaultValue: 'http://127.0.0.1:9600',
  );
}
