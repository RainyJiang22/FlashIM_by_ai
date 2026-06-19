import 'package:flash_auth/flash_auth.dart';

import '../data/user.dart';

enum SessionStatus { initial, restoring, unauthenticated, authenticated, failure }

class SessionState {
  const SessionState({
    required this.status,
    this.session,
    this.user,
    this.errorMessage,
    this.shouldPromptPasswordSetup = false,
  });

  const SessionState.initial() : this(status: SessionStatus.initial);

  final SessionStatus status;
  final AppSession? session;
  final User? user;
  final String? errorMessage;
  final bool shouldPromptPasswordSetup;

  SessionState copyWith({
    SessionStatus? status,
    AppSession? session,
    bool clearSession = false,
    User? user,
    bool clearUser = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? shouldPromptPasswordSetup,
  }) {
    return SessionState(
      status: status ?? this.status,
      session: clearSession ? null : (session ?? this.session),
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      shouldPromptPasswordSetup:
          shouldPromptPasswordSetup ?? this.shouldPromptPasswordSetup,
    );
  }
}
