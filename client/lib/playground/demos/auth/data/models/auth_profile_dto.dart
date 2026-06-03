class AuthProfileDto {
  const AuthProfileDto({
    required this.userId,
    required this.nickname,
    required this.avatar,
    required this.phone,
  });

  final int userId;
  final String nickname;
  final String avatar;
  final String phone;

  factory AuthProfileDto.fromJson(Map<String, dynamic> json) {
    return AuthProfileDto(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      nickname: json['nickname'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
    );
  }
}
