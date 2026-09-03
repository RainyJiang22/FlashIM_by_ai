import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';

import '../data/message.dart';
import '../data/message_repository.dart';
import '../data/read_receipt.dart';

Future<void> showMessageReadStatusSheet({
  required BuildContext context,
  required MessageRepository repository,
  required Message message,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        _MessageReadStatusSheet(repository: repository, message: message),
  );
}

class _MessageReadStatusSheet extends StatefulWidget {
  const _MessageReadStatusSheet({
    required this.repository,
    required this.message,
  });

  final MessageRepository repository;
  final Message message;

  @override
  State<_MessageReadStatusSheet> createState() =>
      _MessageReadStatusSheetState();
}

class _MessageReadStatusSheetState extends State<_MessageReadStatusSheet> {
  late Future<MessageReadStatus> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repository = widget.repository;
    if (repository is MessageReadStatusRepository) {
      final readStatusRepository = repository as MessageReadStatusRepository;
      _future = readStatusRepository.getReadStatus(
        conversationId: widget.message.conversationId,
        messageId: widget.message.id,
      );
      return;
    }
    _future = Future<MessageReadStatus>.error(
      StateError('Message read status is not supported.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.68,
        child: FutureBuilder<MessageReadStatus>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return _ReadStatusError(onRetry: () => setState(_load));
            }
            final status = snapshot.data!;
            return DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: FlashPalette.mutedInk.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '消息已读详情',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  TabBar(
                    tabs: [
                      Tab(text: '已读 ${status.readMembers.length}'),
                      Tab(text: '未读 ${status.unreadMembers.length}'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _MemberList(
                          members: status.readMembers,
                          emptyText: '暂无已读成员',
                        ),
                        _MemberList(
                          members: status.unreadMembers,
                          emptyText: '所有成员均已读',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MemberList extends StatelessWidget {
  const _MemberList({required this.members, required this.emptyText});

  final List<ReadStatusMember> members;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return Center(child: Text(emptyText));
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: members.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final member = members[index];
        return ListTile(
          leading: AvatarWidget(
            avatar: member.avatar,
            seed: member.userId,
            size: 42,
            borderRadius: BorderRadius.circular(13),
          ),
          title: Text(member.nickname),
        );
      },
    );
  }
}

class _ReadStatusError extends StatelessWidget {
  const _ReadStatusError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('已读详情加载失败'),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('read-status-retry'),
            onPressed: onRetry,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
