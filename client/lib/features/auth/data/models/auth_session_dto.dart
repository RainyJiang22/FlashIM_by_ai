class AuthSessionDto {
  const AuthSessionDto({
    required this.token,
    required this.accountId,
    required this.passwordSetupRequired,
  });

  final String token;
  final int accountId;
  final bool passwordSetupRequired;

  factory AuthSessionDto.fromJson(Map<String, dynamic> json) {
    return AuthSessionDto(
      token: json['token'] as String? ?? '',
      accountId: (json['account_id'] as num?)?.toInt() ?? 0,
      passwordSetupRequired: json['password_setup_required'] as bool? ?? false,
    );
  }
}
