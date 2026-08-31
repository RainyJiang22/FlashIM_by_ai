import 'package:equatable/equatable.dart';

import '../data/group_discovery.dart';

class GroupSearchState extends Equatable {
  const GroupSearchState({
    this.keyword = '',
    this.items = const [],
    this.isLoading = false,
    this.actionGroupId,
    this.errorMessage,
    this.lastJoinResult,
  });

  final String keyword;
  final List<GroupSearchItem> items;
  final bool isLoading;
  final String? actionGroupId;
  final String? errorMessage;
  final JoinGroupResult? lastJoinResult;

  GroupSearchState copyWith({
    String? keyword,
    List<GroupSearchItem>? items,
    bool? isLoading,
    Object? actionGroupId = _unset,
    Object? errorMessage = _unset,
    Object? lastJoinResult = _unset,
  }) => GroupSearchState(
    keyword: keyword ?? this.keyword,
    items: items ?? this.items,
    isLoading: isLoading ?? this.isLoading,
    actionGroupId: identical(actionGroupId, _unset)
        ? this.actionGroupId
        : actionGroupId as String?,
    errorMessage: identical(errorMessage, _unset)
        ? this.errorMessage
        : errorMessage as String?,
    lastJoinResult: identical(lastJoinResult, _unset)
        ? this.lastJoinResult
        : lastJoinResult as JoinGroupResult?,
  );

  @override
  List<Object?> get props => [
    keyword,
    items,
    isLoading,
    actionGroupId,
    errorMessage,
    lastJoinResult,
  ];
}

const _unset = Object();
