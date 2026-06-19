import 'package:dio/dio.dart';
import 'package:flash_auth/flash_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/session_repository.dart';
import '../data/user.dart';
import 'session_state.dart';

class SessionCubit extends Cubit<SessionState> {
  SessionCubit({required SessionRepository repository})
    : _repository = repository,
      super(const SessionState.initial());

  final SessionRepository _repository;
  bool _passwordPromptDismissed = false;

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _repository.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );

    final user = state.user;
    if (user != null && !user.hasPassword) {
      emit(
        state.copyWith(
          user: user.copyWith(hasPassword: true),
          clearErrorMessage: true,
        ),
      );
    }
  }

  Future<void> completeLogin(AppSession session) async {
    await _repository.persistSession(session);
    _passwordPromptDismissed = false;
    emit(
      SessionState(
        status: SessionStatus.authenticated,
        session: session,
        shouldPromptPasswordSetup: session.passwordSetupRequired,
      ),
    );
  }

  Future<void> logout() async {
    _passwordPromptDismissed = false;
    await _repository.clearSession();
    emit(
      const SessionState(
        status: SessionStatus.unauthenticated,
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

  Future<void> refreshProfile() async {
    if (state.session == null) {
      return;
    }

    try {
      final user = await _repository.fetchProfile();
      _syncUser(user);
    } on SessionMissingTokenException {
      await logout();
    } on DioException catch (error) {
      if (_isUnauthorized(error)) {
        await logout();
        return;
      }

      emit(
        state.copyWith(
          status: SessionStatus.authenticated,
          errorMessage: error.message ?? '个人信息加载失败',
        ),
      );
    }
  }

  Future<void> restoreSession() async {
    emit(
      state.copyWith(
        status: SessionStatus.restoring,
        clearErrorMessage: true,
        shouldPromptPasswordSetup: false,
      ),
    );

    try {
      final cachedSession = await _repository.readCachedSession();
      if (cachedSession == null || cachedSession.token.isEmpty) {
        emit(
          const SessionState(
            status: SessionStatus.unauthenticated,
            shouldPromptPasswordSetup: false,
          ),
        );
        return;
      }

      _passwordPromptDismissed = false;
      emit(
        SessionState(
          status: SessionStatus.authenticated,
          session: AppSession(
            token: cachedSession.token,
            accountId: cachedSession.accountId ?? 0,
            passwordSetupRequired: false,
          ),
        ),
      );
    } catch (_) {
      await _repository.clearSession();
      emit(
        const SessionState(
          status: SessionStatus.failure,
          errorMessage: '启动失败，请重试',
        ),
      );
    }
  }

  Future<void> setPassword({required String newPassword}) async {
    await _repository.setPassword(newPassword: newPassword);
    _passwordPromptDismissed = true;
    final user = state.user;
    if (user != null) {
      emit(
        state.copyWith(
          user: user.copyWith(hasPassword: true),
          clearErrorMessage: true,
          shouldPromptPasswordSetup: false,
        ),
      );
    } else {
      emit(
        state.copyWith(
          clearErrorMessage: true,
          shouldPromptPasswordSetup: false,
        ),
      );
    }
    await refreshProfile();
  }

  Future<void> updateProfile({
    String? nickname,
    String? signature,
    String? avatar,
  }) async {
    final user = await _repository.updateProfile(
      nickname: nickname,
      signature: signature,
      avatar: avatar,
    );
    _syncUser(user);
  }

  bool _isUnauthorized(DioException error) {
    return error.response?.statusCode == 401;
  }

  void _syncUser(User user) {
    emit(
      state.copyWith(
        status: SessionStatus.authenticated,
        user: user,
        clearErrorMessage: true,
        shouldPromptPasswordSetup:
            !_passwordPromptDismissed && !user.hasPassword,
      ),
    );
  }
}
