import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/config/playground_api_config.dart';
import '../data/heartbeat_api.dart';
import '../data/heartbeat_repository.dart';
import '../domain/heartbeat_connection_status.dart';
import '../domain/heartbeat_event.dart';
import '../domain/heartbeat_log_item.dart';
import 'widgets/heartbeat_log_tile.dart';
import 'widgets/heartbeat_status_card.dart';

class HeartbeatPlaygroundPage extends StatefulWidget {
  const HeartbeatPlaygroundPage({super.key, HeartbeatRepository? repository})
    : _repository = repository;

  final HeartbeatRepository? _repository;

  @override
  State<HeartbeatPlaygroundPage> createState() =>
      _HeartbeatPlaygroundPageState();
}

class _HeartbeatPlaygroundPageState extends State<HeartbeatPlaygroundPage> {
  late final HeartbeatRepository _repository;
  late final TextEditingController _urlController;
  late final TextEditingController _messageController;

  StreamSubscription<HeartbeatEvent>? _subscription;
  HeartbeatConnectionStatus _status = HeartbeatConnectionStatus.disconnected;
  final List<HeartbeatLogItem> _logs = <HeartbeatLogItem>[];

  @override
  void initState() {
    super.initState();
    _repository =
        widget._repository ??
        LiveHeartbeatRepository(request: WebSocketHeartbeatApi());
    _urlController = TextEditingController(
      text: _buildDefaultWebSocketUrl(PlaygroundApiConfig.defaultBaseUrl),
    );
    _messageController = TextEditingController(text: 'hello websocket');
  }

  @override
  void dispose() {
    unawaited(_repository.disconnect());
    unawaited(_subscription?.cancel());
    _urlController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    await _subscription?.cancel();
    await _repository.disconnect();

    setState(() {
      _logs.clear();
      _status = HeartbeatConnectionStatus.connecting;
    });

    final stream = _repository.connect(_urlController.text.trim());
    _subscription = stream.listen(_handleEvent);
  }

  Future<void> _disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _repository.disconnect();

    if (!mounted) {
      return;
    }

    setState(() {
      _status = HeartbeatConnectionStatus.disconnected;
      _appendSystemLog('手动断开连接');
    });
  }

  Future<void> _sendHeartbeat() async {
    await _repository.sendHeartbeat();
  }

  Future<void> _sendCustomMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    await _repository.sendText(text);
  }

  void _handleEvent(HeartbeatEvent event) {
    if (!mounted) {
      return;
    }

    setState(() {
      if (event.type == HeartbeatEventType.status && event.status != null) {
        _status = event.status!;
      }

      if (event.type == HeartbeatEventType.message &&
          event.direction != null &&
          event.message != null) {
        _logs.insert(
          0,
          HeartbeatLogItem(
            direction: event.direction!,
            message: event.message!,
            createdAt: DateTime.now(),
          ),
        );
      }
    });
  }

  void _appendSystemLog(String message) {
    _logs.insert(
      0,
      HeartbeatLogItem(
        direction: HeartbeatMessageDirection.system,
        message: message,
        createdAt: DateTime.now(),
      ),
    );
  }

  static String _buildDefaultWebSocketUrl(String baseUrl) {
    final uri = Uri.parse(baseUrl);
    final wsScheme = switch (uri.scheme) {
      'https' => 'wss',
      _ => 'ws',
    };

    return uri.replace(scheme: wsScheme, path: '/ws').toString();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _status == HeartbeatConnectionStatus.connected;
    final isConnecting = _status == HeartbeatConnectionStatus.connecting;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        surfaceTintColor: const Color(0xFFF8FAFC),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF111111)),
        title: const Text(
          '心跳通信',
          style: TextStyle(
            color: Color(0xFF111111),
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '基于 /ws 的 WebSocket 测试台，用于 playground 阶段快速验证连接、欢迎消息、心跳和回声回复。',
                style: TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              HeartbeatStatusCard(status: _status),
              const SizedBox(height: 18),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'WebSocket URL',
                  hintText: 'ws://127.0.0.1:9600/ws',
                  hintStyle: TextStyle(
                    color: Colors.grey,
                  ),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isConnecting ? null : _connect,
                      icon: const Icon(Icons.power_settings_new_rounded),
                      label: const Text('连接'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _status == HeartbeatConnectionStatus.disconnected
                          ? null
                          : _disconnect,
                      icon: const Icon(Icons.link_off_rounded),
                      label: const Text('断开'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: isConnected ? _sendHeartbeat : null,
                      icon: const Icon(Icons.favorite_rounded),
                      label: const Text('发送心跳 ping'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: '自定义消息',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: isConnected ? _sendCustomMessage : null,
                    child: const Text('发送'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                '通信日志',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _logs.isEmpty
                    ? const _HeartbeatEmptyView()
                    : ListView.separated(
                        itemCount: _logs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return HeartbeatLogTile(item: _logs[index]);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeartbeatEmptyView extends StatelessWidget {
  const _HeartbeatEmptyView();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '连接后会在这里看到欢迎消息、心跳发送和 echo 返回。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
