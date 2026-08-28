import 'package:flash_shared/flash_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodes at most nine non-empty member avatars', () {
    final value = encodeGroupAvatar([
      '',
      for (var index = 1; index <= 10; index++) 'identicon:$index',
    ]);

    expect(
      value,
      'grid:identicon:1,identicon:2,identicon:3,identicon:4,'
      'identicon:5,identicon:6,identicon:7,identicon:8,identicon:9',
    );
  });

  testWidgets('parses grid prefix and caps rendering at nine avatars', (
    tester,
  ) async {
    await _pumpAvatar(
      tester,
      'grid:${[for (var index = 1; index <= 10; index++) 'identicon:$index'].join(',')}',
    );

    expect(find.byType(AvatarWidget), findsNWidgets(9));
    expect(find.byKey(const ValueKey('group-avatar-cell-8')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-avatar-cell-9')), findsNothing);
  });

  testWidgets('uses one full-size avatar for a single member', (tester) async {
    await _pumpAvatar(tester, 'grid:identicon:1');

    final avatar = tester.widget<AvatarWidget>(find.byType(AvatarWidget));
    expect(avatar.size, 52);
  });

  testWidgets('lays out two members in one horizontal row', (tester) async {
    await _pumpAvatar(tester, 'grid:identicon:1,identicon:2');

    final first = tester.getCenter(
      find.byKey(const ValueKey('group-avatar-cell-0')),
    );
    final second = tester.getCenter(
      find.byKey(const ValueKey('group-avatar-cell-1')),
    );
    expect(first.dx, lessThan(second.dx));
    expect(first.dy, second.dy);
  });

  testWidgets('lays out three members as one above two', (tester) async {
    await _pumpAvatar(tester, 'grid:identicon:1,identicon:2,identicon:3');

    final first = tester.getCenter(
      find.byKey(const ValueKey('group-avatar-cell-0')),
    );
    final second = tester.getCenter(
      find.byKey(const ValueKey('group-avatar-cell-1')),
    );
    final third = tester.getCenter(
      find.byKey(const ValueKey('group-avatar-cell-2')),
    );
    expect(first.dy, lessThan(second.dy));
    expect(second.dy, third.dy);
    expect(first.dx, moreOrLessEquals((second.dx + third.dx) / 2));
  });

  testWidgets('uses two columns for four and three columns for five to nine', (
    tester,
  ) async {
    await _pumpAvatar(
      tester,
      'grid:identicon:1,identicon:2,identicon:3,identicon:4',
    );
    final fourAvatar = tester.widget<AvatarWidget>(
      find.byKey(const ValueKey('group-avatar-cell-0')),
    );
    expect(fourAvatar.size, 23);

    for (var count = 5; count <= 9; count++) {
      await _pumpAvatar(
        tester,
        'grid:${[for (var index = 1; index <= count; index++) 'identicon:$index'].join(',')}',
      );
      expect(find.byType(AvatarWidget), findsNWidgets(count));
      final gridAvatar = tester.widget<AvatarWidget>(
        find.byKey(const ValueKey('group-avatar-cell-0')),
      );
      expect(gridAvatar.size, closeTo(44 / 3, 0.001));
    }
  });

  testWidgets('falls back to a normal avatar when grid prefix is absent', (
    tester,
  ) async {
    await _pumpAvatar(tester, 'identicon:fallback');

    final avatar = tester.widget<AvatarWidget>(find.byType(AvatarWidget));
    expect(avatar.avatar, 'identicon:fallback');
  });
}

Future<void> _pumpAvatar(WidgetTester tester, String avatar) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: GroupAvatarWidget(avatar: avatar, seed: 'group-test'),
        ),
      ),
    ),
  );
}
