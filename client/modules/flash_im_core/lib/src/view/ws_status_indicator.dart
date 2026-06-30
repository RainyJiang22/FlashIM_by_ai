import 'package:flutter/material.dart';

import '../logic/ws_client.dart';

class WsStatusIndicator extends StatelessWidget {
  const WsStatusIndicator({super.key, required this.client});

  final WsClient client;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WsConnectionState>(
      stream: client.stateStream,
      initialData: client.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? WsConnectionState.disconnected;
        if (state == WsConnectionState.authenticated) {
          return const SizedBox.shrink();
        }

        final color = state == WsConnectionState.disconnected
            ? const Color(0xFFE35D6A)
            : const Color(0xFFF0A33A);
        final text = switch (state) {
          WsConnectionState.disconnected => '连接已断开，正在重连...',
          WsConnectionState.connecting => '正在连接...',
          WsConnectionState.authenticating => '正在认证...',
          WsConnectionState.authenticated => '',
        };

        return Material(
          color: color.withValues(alpha: 0.12),
          child: InkWell(
            onTap: state == WsConnectionState.disconnected
                ? client.connect
                : null,
            child: SizedBox(
              width: double.infinity,
              height: 34,
              child: Center(
                child: Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
