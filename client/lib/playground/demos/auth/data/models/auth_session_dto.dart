class AuthSessionDto {
  const AuthSessionDto({required this.token, required this.userId});

  final String token;
  final int userId;

  factory AuthSessionDto.fromJson(Map<String, dynamic> json) {
    return AuthSessionDto(
      token: json['token'] as String? ?? '',
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
    );
  }
}
