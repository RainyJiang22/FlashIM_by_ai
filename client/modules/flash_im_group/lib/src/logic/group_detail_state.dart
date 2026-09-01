import 'package:equatable/equatable.dart';

import '../data/group_detail.dart';

class GroupDetailState extends Equatable {
  const GroupDetailState({
    this.detail,
    this.isLoading = false,
    this.isSaving = false,
    this.isDeleteMode = false,
    this.isDissolved = false,
    this.isLeft = false,
    this.isRemoved = false,
    this.errorMessage,
  });

  final GroupDetail? detail;
  final bool isLoading;
  final bool isSaving;
  final bool isDeleteMode;
  final bool isDissolved;
  final bool isLeft;
  final bool isRemoved;
  final String? errorMessage;

  bool get isOwner => detail?.isOwner == true;

  GroupDetailState copyWith({
    GroupDetail? detail,
    bool? isLoading,
    bool? isSaving,
    bool? isDeleteMode,
    bool? isDissolved,
    bool? isLeft,
    bool? isRemoved,
    String? errorMessage,
    bool clearError = false,
  }) => GroupDetailState(
    detail: detail ?? this.detail,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    isDeleteMode: isDeleteMode ?? this.isDeleteMode,
    isDissolved: isDissolved ?? this.isDissolved,
    isLeft: isLeft ?? this.isLeft,
    isRemoved: isRemoved ?? this.isRemoved,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );

  @override
  List<Object?> get props => [
    detail,
    isLoading,
    isSaving,
    isDeleteMode,
    isDissolved,
    isLeft,
    isRemoved,
    errorMessage,
  ];
}
