enum AppStarterStatus {
  initial,
  restoring,
  authenticated,
  unauthenticated,
  failure,
}

class AppStarterState {
  const AppStarterState({required this.status, this.errorMessage});

  const AppStarterState.initial() : this(status: AppStarterStatus.initial);

  final AppStarterStatus status;
  final String? errorMessage;
}
