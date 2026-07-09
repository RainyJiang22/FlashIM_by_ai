import 'package:flash_session/flash_session.dart';
import 'package:flash_starter/flash_starter.dart';

class SessionAppStarterController implements AppStarterController {
  SessionAppStarterController(this._sessionCubit);

  final SessionCubit _sessionCubit;

  @override
  AppStarterState get state => _mapState(_sessionCubit.state);

  @override
  Stream<AppStarterState> get stream => _sessionCubit.stream.map(_mapState);

  @override
  Future<void> restore() => _sessionCubit.restoreSession();

  AppStarterState _mapState(SessionState state) {
    return AppStarterState(
      status: switch (state.status) {
        SessionStatus.initial => AppStarterStatus.initial,
        SessionStatus.restoring => AppStarterStatus.restoring,
        SessionStatus.authenticated => AppStarterStatus.authenticated,
        SessionStatus.unauthenticated => AppStarterStatus.unauthenticated,
        SessionStatus.failure => AppStarterStatus.failure,
      },
      errorMessage: state.errorMessage,
    );
  }
}
