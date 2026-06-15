class AuthProfileDto {
  const AuthProfileDto({
    required this.accountId,
    required this.nickname,
    required this.avatar,
    required this.phone,
    required this.hasPassword,
  });

  final int accountId;
  final String nickname;
  final String avatar;
  final String phone;
  final bool hasPassword;

  factory AuthProfileDto.fromJson(Map<String, dynamic> json) {
    return AuthProfileDto(
      accountId: (json['account_id'] as num?)?.toInt() ?? 0,
      nickname: json['nickname'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      hasPassword: json['has_password'] as bool? ?? false,
    );
  }
}
