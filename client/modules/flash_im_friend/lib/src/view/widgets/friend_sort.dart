import 'package:pinyin/pinyin.dart';

import '../../data/friend_user.dart';

const friendAlphabetLabels = <String>[
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
  '#',
];

class FriendSection {
  const FriendSection({required this.letter, required this.friends});

  final String letter;
  final List<FriendUser> friends;
}

List<FriendSection> buildFriendSections(Iterable<FriendUser> friends) {
  final grouped = <String, List<FriendUser>>{};
  for (final friend in friends) {
    final letter = friendAlphabetInitial(friend.displayName);
    grouped.putIfAbsent(letter, () => <FriendUser>[]).add(friend);
  }

  for (final group in grouped.values) {
    group.sort((left, right) {
      final sortResult = friendSortKey(
        left.displayName,
      ).compareTo(friendSortKey(right.displayName));
      if (sortResult != 0) {
        return sortResult;
      }
      return left.displayName.compareTo(right.displayName);
    });
  }

  final letters = grouped.keys.toList()
    ..sort((left, right) {
      if (left == '#') {
        return right == '#' ? 0 : 1;
      }
      if (right == '#') {
        return -1;
      }
      return left.compareTo(right);
    });

  return [
    for (final letter in letters)
      FriendSection(
        letter: letter,
        friends: List.unmodifiable(grouped[letter]!),
      ),
  ];
}

String friendAlphabetInitial(String nickname) {
  final value = nickname.trim();
  if (value.isEmpty) {
    return '#';
  }

  final firstRune = value.runes.first;
  if (_isAsciiLetter(firstRune)) {
    return String.fromCharCode(firstRune).toUpperCase();
  }
  if (!_isChineseRune(firstRune)) {
    return '#';
  }

  try {
    final shortPinyin = PinyinHelper.getShortPinyin(value).toUpperCase();
    for (final rune in shortPinyin.runes) {
      if (_isAsciiLetter(rune)) {
        return String.fromCharCode(rune);
      }
    }
  } on Object {
    // A nickname may contain characters outside the pinyin dictionary.
  }
  return '#';
}

String friendSortKey(String nickname) {
  final value = nickname.trim();
  if (value.isEmpty) {
    return '#';
  }

  final firstRune = value.runes.first;
  if (_isAsciiLetter(firstRune)) {
    return value.toUpperCase();
  }
  if (!_isChineseRune(firstRune)) {
    return '#$value';
  }

  try {
    return PinyinHelper.getPinyinE(
      value,
      separator: '',
      defPinyin: '#',
    ).toUpperCase();
  } on Object {
    return '#$value';
  }
}

bool _isAsciiLetter(int rune) {
  return (rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A);
}

bool _isChineseRune(int rune) {
  return (rune >= 0x3400 && rune <= 0x4DBF) ||
      (rune >= 0x4E00 && rune <= 0x9FFF) ||
      (rune >= 0xF900 && rune <= 0xFAFF);
}
