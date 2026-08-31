import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/group_discovery.dart';
import '../logic/group_notification_cubit.dart';
import '../logic/group_notification_state.dart';
import 'widgets/group_join_request_tile.dart';

class GroupNotificationsPage extends StatelessWidget {
  const GroupNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GroupNotificationCubit, GroupNotificationState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage &&
          current.errorMessage != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        context.read<GroupNotificationCubit>().clearError();
      },
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('群通知')),
        backgroundColor: FlashPalette.background,
        body: _body(context, state),
      ),
    );
  }

  Widget _body(BuildContext context, GroupNotificationState state) {
    if (state.isLoading && state.requests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: context.read<GroupNotificationCubit>().load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Center(
              child: Text(
                '暂无群通知',
                style: TextStyle(color: FlashPalette.secondaryInk),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: context.read<GroupNotificationCubit>().load,
      child: ListView.separated(
        itemCount: state.requests.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 83),
        itemBuilder: (context, index) {
          final request = state.requests[index];
          return GroupJoinRequestTile(
            request: request,
            isHandling: state.handlingRequestId == request.id,
            onApprove: () => _handle(context, request, approved: true),
            onReject: () => _handle(context, request, approved: false),
          );
        },
      ),
    );
  }

  Future<void> _handle(
    BuildContext context,
    GroupJoinRequest request, {
    required bool approved,
  }) async {
    if (!approved) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('拒绝入群申请'),
          content: Text('确定拒绝“${request.applicantName}”加入群聊吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const Key('group-request-reject-confirm'),
              style: FilledButton.styleFrom(
                backgroundColor: FlashPalette.danger,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('拒绝'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    await context.read<GroupNotificationCubit>().handle(
      request,
      approved: approved,
    );
  }
}
