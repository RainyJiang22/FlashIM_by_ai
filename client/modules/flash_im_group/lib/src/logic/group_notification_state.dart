import 'package:equatable/equatable.dart';

import '../data/group_discovery.dart';

class GroupNotificationState extends Equatable {
  const GroupNotificationState({
    this.requests = const [],
    this.pendingCount = 0,
    this.isLoading = false,
    this.handlingRequestId,
    this.errorMessage,
  });

  final List<GroupJoinRequest> requests;
  final int pendingCount;
  final bool isLoading;
  final String? handlingRequestId;
  final String? errorMessage;

  GroupNotificationState copyWith({
    List<GroupJoinRequest>? requests,
    int? pendingCount,
    bool? isLoading,
    Object? handlingRequestId = _unset,
    Object? errorMessage = _unset,
  }) => GroupNotificationState(
    requests: requests ?? this.requests,
    pendingCount: pendingCount ?? this.pendingCount,
    isLoading: isLoading ?? this.isLoading,
    handlingRequestId: identical(handlingRequestId, _unset)
        ? this.handlingRequestId
        : handlingRequestId as String?,
    errorMessage: identical(errorMessage, _unset)
        ? this.errorMessage
        : errorMessage as String?,
  );

  @override
  List<Object?> get props => [
    requests,
    pendingCount,
    isLoading,
    handlingRequestId,
    errorMessage,
  ];
}

const _unset = Object();
