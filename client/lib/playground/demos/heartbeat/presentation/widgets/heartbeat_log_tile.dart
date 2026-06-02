import 'package:flutter/material.dart';

import '../../domain/heartbeat_event.dart';
import '../../domain/heartbeat_log_item.dart';

class HeartbeatLogTile extends StatelessWidget {
  const HeartbeatLogTile({super.key, required this.item});

  final HeartbeatLogItem item;

  @override
  Widget build(BuildContext context) {
    final (backgroundColor, title, icon) = switch (item.direction) {
      HeartbeatMessageDirection.incoming => (
        const Color(0xFFE8F7EE),
        '接收',
        Icons.south_west_rounded,
      ),
      HeartbeatMessageDirection.outgoing => (
        const Color(0xFFE9F2FF),
        '发送',
        Icons.north_east_rounded,
      ),
      HeartbeatMessageDirection.system => (
        const Color(0xFFF4F4F5),
        '系统',
        Icons.info_outline_rounded,
      ),
    };

    final timeLabel =
        '${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}:${item.createdAt.second.toString().padLeft(2, '0')}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF0F172A), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.message,
                    style: const TextStyle(
                      color: Color(0xFF111827),
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
