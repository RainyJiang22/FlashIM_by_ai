import 'package:equatable/equatable.dart';
import 'package:flash_im_conversation/flash_im_conversation.dart';
import 'package:flash_im_friend/flash_im_friend.dart';

import '../data/search_models.dart';

enum SearchSection { friends, groups, messages }

class SearchState extends Equatable {
  const SearchState({
    this.keyword = '',
    this.friends = const [],
    this.groups = const [],
    this.messageGroups = const [],
    this.pendingSections = const {},
    this.failedSections = const {},
    this.history = const [],
    this.hasSearched = false,
  });

  final String keyword;
  final List<FriendUser> friends;
  final List<Conversation> groups;
  final List<MessageSearchGroup> messageGroups;
  final Set<SearchSection> pendingSections;
  final Set<SearchSection> failedSections;
  final List<String> history;
  final bool hasSearched;

  bool isPending(SearchSection section) => pendingSections.contains(section);

  bool hasFailed(SearchSection section) => failedSections.contains(section);

  SearchState copyWith({
    String? keyword,
    List<FriendUser>? friends,
    List<Conversation>? groups,
    List<MessageSearchGroup>? messageGroups,
    Set<SearchSection>? pendingSections,
    Set<SearchSection>? failedSections,
    List<String>? history,
    bool? hasSearched,
  }) {
    return SearchState(
      keyword: keyword ?? this.keyword,
      friends: friends ?? this.friends,
      groups: groups ?? this.groups,
      messageGroups: messageGroups ?? this.messageGroups,
      pendingSections: pendingSections ?? this.pendingSections,
      failedSections: failedSections ?? this.failedSections,
      history: history ?? this.history,
      hasSearched: hasSearched ?? this.hasSearched,
    );
  }

  @override
  List<Object?> get props => [
    keyword,
    friends,
    groups,
    messageGroups,
    pendingSections,
    failedSections,
    history,
    hasSearched,
  ];
}
