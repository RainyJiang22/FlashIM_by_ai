import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/auth/auth_cache_store.dart';
import '../data/auth_repository.dart';
import '../domain/app_session.dart';
import '../domain/auth_profile.dart';
import '../domain/auth_status.dart';

class AppSessionState {
  const AppSessionState({
    required this.status,
    this.session,
    this.profile,
    this.errorMessage,
    this.shouldPromptPasswordSetup = false,
  });

  const AppSessionState.initial() : this(status: AuthStatus.initial);

  final AuthStatus status;
  final AppSession? session;
  final AuthProfile? profile;
  final String? errorMessage;
  final bool shouldPromptPasswordSetup;

  AppSessionState copyWith({
    AuthStatus? status,
    AppSession? session,
    bool clearSession = false,
    AuthProfile? profile,
    bool clearProfile = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? shouldPromptPasswordSetup,
  }) {
    return AppSessionState(
      status: status ?? this.status,
      session: clearSession ? null : (session ?? this.session),
      profile: clearProfile ? null : (profile ?? this.profile),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      shouldPromptPasswordSetup:
          shouldPromptPasswordSetup ?? this.shouldPromptPasswordSetup,
    );
  }
}

class AppSessionCubit extends Cubit<AppSessionState> {
  AppSessionCubit({required AuthRepository repository})
    : _repository = repository,
      super(const AppSessionState.initial());

  final AuthRepository _repository;
  bool _passwordPromptDismissed = false;

  Future<void> completeLogin(AppSession session) async {
    await _repository.persistSession(session);
    _passwordPromptDismissed = false;
    emit(
      AppSessionState(
        status: AuthStatus.authenticated,
        session: session,
        shouldPromptPasswordSetup: session.passwordSetupRequired,
      ),
    );
  }

  Future<void> logout() async {
    _passwordPromptDismissed = false;
    await _repository.logout();
    emit(
      const AppSessionState(
        status: AuthStatus.unauthenticated,
        shouldPromptPasswordSetup: false,
      ),
    );
  }

  void markPasswordPromptHandled() {
    _passwordPromptDismissed = true;
    emit(
      state.copyWith(shouldPromptPasswordSetup: false, clearErrorMessage: true),
    );
  }

  void syncProfile(AuthProfile profile) {
    emit(
      state.copyWith(
        status: AuthStatus.authenticated,
        profile: profile,
        clearErrorMessage: true,
        shouldPromptPasswordSetup:
            !_passwordPromptDismissed && !profile.hasPassword,
      ),
    );
  }

  Future<void> refreshProfile() async {
    if (state.session == null) {
      return;
    }

    try {
      final profile = await _repository.fetchProfile();
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          profile: profile,
          clearErrorMessage: true,
          shouldPromptPasswordSetup:
              !_passwordPromptDismissed && !profile.hasPassword,
        ),
      );
    } on AuthMissingTokenException {
      await logout();
    } on DioException catch (error) {
      if (_isUnauthorized(error)) {
        await logout();
        return;
      }

      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          errorMessage: error.message ?? '个人信息加载失败',
          shouldPromptPasswordSetup: state.shouldPromptPasswordSetup,
        ),
      );
    }
  }

  Future<void> restoreSession() async {
    emit(
      state.copyWith(
        status: AuthStatus.restoring,
        clearErrorMessage: true,
        shouldPromptPasswordSetup: false,
      ),
    );

    try {
      final cachedSession = await _repository.readCachedSession();
      if (cachedSession == null || cachedSession.token.isEmpty) {
        emit(
          const AppSessionState(
            status: AuthStatus.unauthenticated,
            shouldPromptPasswordSetup: false,
          ),
        );
        return;
      }

      _passwordPromptDismissed = false;
      emit(
        AppSessionState(
          status: AuthStatus.authenticated,
          session: AppSession(
            token: cachedSession.token,
            accountId: cachedSession.accountId ?? 0,
            passwordSetupRequired: false,
          ),
        ),
      );
    } catch (_) {
      await _repository.logout();
      emit(
        const AppSessionState(
          status: AuthStatus.failure,
          errorMessage: '启动失败，请重试',
        ),
      );
    }
  }

  bool _isUnauthorized(DioException error) {
    return error.response?.statusCode == 401;
  }
}
