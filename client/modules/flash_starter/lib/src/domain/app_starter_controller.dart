import 'app_starter_state.dart';

abstract interface class AppStarterController {
  AppStarterState get state;
  Stream<AppStarterState> get stream;
  Future<void> restore();
}
