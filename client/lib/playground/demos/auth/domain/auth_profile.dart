class AuthProfile {
  const AuthProfile({
    required this.userId,
    required this.nickname,
    required this.avatarUrl,
    required this.phone,
  });

  final int userId;
  final String nickname;
  final String avatarUrl;
  final String phone;
}
