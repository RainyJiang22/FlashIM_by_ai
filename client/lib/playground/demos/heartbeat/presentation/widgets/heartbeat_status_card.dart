import 'package:flutter/material.dart';

import '../../domain/heartbeat_connection_status.dart';

class HeartbeatStatusCard extends StatelessWidget {
  const HeartbeatStatusCard({super.key, required this.status});

  final HeartbeatConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, subtitle) = switch (status) {
      HeartbeatConnectionStatus.connecting => (
        '连接中',
        const Color(0xFFF59E0B),
        '正在与 /ws 建立 WebSocket 连接',
      ),
      HeartbeatConnectionStatus.connected => (
        '已连接',
        const Color(0xFF10B981),
        '可以发送心跳或自定义文本消息',
      ),
      HeartbeatConnectionStatus.disconnected => (
        '已断开',
        const Color(0xFFEF4444),
        '连接关闭后可再次发起连接',
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
