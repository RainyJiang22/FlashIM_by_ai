import 'package:flash_im_group/flash_im_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('owner can select and save group admins', (tester) async {
    List<int>? savedIds;
    await tester.pumpWidget(
      MaterialApp(
        home: GroupAdminPage(
          members: [
            GroupMember(
              accountId: 1,
              nickname: '群主',
              avatar: 'identicon:1',
              isOwner: true,
              joinedAt: DateTime(2026, 9, 2),
            ),
            GroupMember(
              accountId: 2,
              nickname: '阿青',
              avatar: 'identicon:2',
              isOwner: false,
              joinedAt: DateTime(2026, 9, 2),
            ),
          ],
          onSave: (ids) async {
            savedIds = ids;
            return true;
          },
        ),
      ),
    );

    expect(find.byKey(const Key('group-admin-1')), findsNothing);
    await tester.tap(find.byKey(const Key('group-admin-2')));
    await tester.tap(find.byKey(const Key('group-admin-save')));
    await tester.pumpAndSettle();

    expect(savedIds, [2]);
  });

  testWidgets('group name page validates and saves the trimmed value', (
    tester,
  ) async {
    String? savedName;
    await tester.pumpWidget(
      MaterialApp(
        home: GroupNameEditPage(
          initialName: '旧群名',
          onSave: (value) async {
            savedName = value;
            return true;
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('group-name-input')),
      '  新群名  ',
    );
    await tester.tap(find.byKey(const Key('group-name-save')));
    await tester.pumpAndSettle();

    expect(savedName, '新群名');
  });

  testWidgets(
    'announcement is read-only for members and publishable by owner',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GroupAnnouncementPage(
            key: const ValueKey('member-announcement'),
            announcement: '周五发布',
            canEdit: false,
            updatedByName: '群主',
            updatedAt: DateTime(2026, 8, 31, 18),
            onPublish: (_) async => true,
          ),
        ),
      );

      expect(find.text('周五发布'), findsOneWidget);
      expect(find.textContaining('群主'), findsOneWidget);
      expect(find.byKey(const Key('group-announcement-action')), findsNothing);

      String? published;
      await tester.pumpWidget(
        MaterialApp(
          home: GroupAnnouncementPage(
            key: const ValueKey('owner-announcement'),
            announcement: '',
            canEdit: true,
            updatedByName: '',
            updatedAt: null,
            onPublish: (value) async {
              published = value;
              return true;
            },
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('group-announcement-input')),
        '  新公告  ',
      );
      await tester.tap(find.byKey(const Key('group-announcement-action')));
      await tester.pumpAndSettle();

      expect(published, '新公告');
    },
  );

  testWidgets('owner transfer excludes the owner and requires confirmation', (
    tester,
  ) async {
    int? transferredTo;
    await tester.pumpWidget(
      MaterialApp(
        home: TransferGroupOwnerPage(
          members: [
            GroupMember(
              accountId: 1,
              nickname: '群主',
              avatar: 'identicon:1',
              isOwner: true,
              joinedAt: DateTime(2026, 8, 31),
            ),
            GroupMember(
              accountId: 2,
              nickname: '阿青',
              avatar: 'identicon:2',
              isOwner: false,
              joinedAt: DateTime(2026, 8, 31),
            ),
          ],
          onTransfer: (memberId) async {
            transferredTo = memberId;
            return true;
          },
        ),
      ),
    );

    expect(find.byKey(const Key('transfer-owner-1')), findsNothing);
    await tester.tap(find.byKey(const Key('transfer-owner-2')));
    await tester.pumpAndSettle();
    expect(find.text('确定将群主转让给“阿青”吗？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('transfer-owner-confirm')));
    await tester.pumpAndSettle();

    expect(transferredTo, 2);
  });
}
