import 'package:flash_im_friend/src/data/friend_user.dart';
import 'package:flash_im_friend/src/view/widgets/friend_sort.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses nickname pinyin initials for friend sections', () {
    expect(friendAlphabetInitial('阿青'), 'A');
    expect(friendAlphabetInitial('小雨'), 'X');
    expect(friendAlphabetInitial('Alice'), 'A');
    expect(friendAlphabetInitial('123号'), '#');
  });

  test('sorts sections alphabetically and keeps # at the end', () {
    final sections = buildFriendSections(const [
      FriendUser(accountId: 1, nickname: '小雨', avatar: '', signature: ''),
      FriendUser(accountId: 2, nickname: '阿青', avatar: '', signature: ''),
      FriendUser(accountId: 3, nickname: '123号', avatar: '', signature: ''),
    ]);

    expect(sections.map((section) => section.letter).toList(), ['A', 'X', '#']);
    expect(sections.first.friends.single.displayName, '阿青');
    expect(sections.last.friends.single.displayName, '123号');
  });
}
