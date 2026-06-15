import 'package:shared_preferences/shared_preferences.dart';

class CachedAuthSession {
  const CachedAuthSession({required this.token, this.accountId});

  final String token;
  final int? accountId;
}

abstract interface class AuthCacheStore {
  Future<CachedAuthSession?> read();

  Future<void> save(CachedAuthSession session);

  Future<void> clear();
}

class SharedPreferencesAuthCacheStore implements AuthCacheStore {
  const SharedPreferencesAuthCacheStore();

  static const String _tokenKey = 'flash_im.auth.token';
  static const String _accountIdKey = 'flash_im.auth.account_id';

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    await preferences.remove(_accountIdKey);
  }

  @override
  Future<CachedAuthSession?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    if (token == null || token.isEmpty) {
      return null;
    }

    return CachedAuthSession(
      token: token,
      accountId: preferences.getInt(_accountIdKey),
    );
  }

  @override
  Future<void> save(CachedAuthSession session) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, session.token);
    if (session.accountId == null) {
      await preferences.remove(_accountIdKey);
    } else {
      await preferences.setInt(_accountIdKey, session.accountId!);
    }
  }
}
