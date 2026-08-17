import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_group/flash_im_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fakes.dart';

void main() {
  testWidgets('lists, searches and returns selected group', (tester) async {
    Conversation? result;
    await tester.pumpWidget(
      RepositoryProvider<ConversationRepository>.value(
        value: FakeConversationRepository(
          pages: {
            0: [groupConversation('g1', '项目群'), groupConversation('g2', '家人群')],
          },
        ),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<Conversation>(
                    MaterialPageRoute(builder: (_) => const MyGroupsPage()),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('项目群'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('my-groups-search')), '家人');
    await tester.pump();
    expect(find.text('项目群'), findsNothing);
    await tester.tap(find.text('家人群'));
    await tester.pumpAndSettle();

    expect(result?.id, 'g2');
  });

  testWidgets('shows list error with retry action', (tester) async {
    await tester.pumpWidget(
      RepositoryProvider<ConversationRepository>.value(
        value: FakeConversationRepository(listError: StateError('bad')),
        child: const MaterialApp(home: MyGroupsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('群聊列表加载失败'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('群聊列表加载失败'), findsOneWidget);
  });
}
