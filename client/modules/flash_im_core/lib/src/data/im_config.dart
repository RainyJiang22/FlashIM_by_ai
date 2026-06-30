class ImConfig {
  ImConfig({
    required this.wsUrl,
    this.heartbeatInterval = const Duration(seconds: 30),
    this.heartbeatTimeout = 3,
    this.reconnectBaseDelay = const Duration(seconds: 1),
    this.reconnectMaxDelay = const Duration(seconds: 30),
  }) {
    assert(heartbeatTimeout > 0);
    assert(!heartbeatInterval.isNegative);
    assert(!reconnectBaseDelay.isNegative);
    assert(!reconnectMaxDelay.isNegative);
  }

  factory ImConfig.fromApiBaseUrl(String apiBaseUrl) {
    final uri = Uri.parse(apiBaseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return ImConfig(
      wsUrl: uri.replace(scheme: scheme, path: '/ws/im').toString(),
    );
  }

  final String wsUrl;
  final Duration heartbeatInterval;
  final int heartbeatTimeout;
  final Duration reconnectBaseDelay;
  final Duration reconnectMaxDelay;
}
