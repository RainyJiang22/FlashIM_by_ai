import 'package:flash_auth/flash_auth.dart';
import 'package:flash_session/flash_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cubit updates profile and change password through repository', () async {
    final repository = _FakeSessionRepository(
      user: const User(
        userId: 10001,
        nickname: 'Rainy',
        avatar: 'identicon:cubit-test',
        phone: '13800138000',
        signature: '',
        hasPassword: false,
      ),
    );
    final cubit = SessionCubit(repository: repository);

    await cubit.completeLogin(
      const AppSession(
        token: 'jwt-token',
        accountId: 10001,
        passwordSetupRequired: false,
      ),
    );
    await cubit.updateProfile(signature: 'hello');
    await cubit.changePassword(
      oldPassword: 'old12345',
      newPassword: 'new12345',
    );

    expect(cubit.state.user?.signature, 'hello');
    expect(repository.lastChangePasswordOld, 'old12345');
    await cubit.close();
  });
}

class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository({required this.user});

  User user;
  String? lastChangePasswordOld;

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    lastChangePasswordOld = oldPassword;
    user = user.copyWith(hasPassword: true);
  }

  @override
  Future<void> clearSession() async {}

  @override
  Future<User> fetchProfile() async => user;

  @override
  Future<void> persistSession(AppSession session) async {}

  @override
  Future<CachedAuthSession?> readCachedSession() async => null;

  @override
  Future<void> setPassword({required String newPassword}) async {
    user = user.copyWith(hasPassword: true);
  }

  @override
  Future<User> updateProfile({
    String? nickname,
    String? signature,
    String? avatar,
  }) async {
    user = user.copyWith(
      nickname: nickname,
      signature: signature,
      avatar: avatar,
    );
    return user;
  }
}
