class PasswordSetupResultDto {
  const PasswordSetupResultDto({
    required this.passwordSetupRequired,
    required this.updatedAt,
  });

  final bool passwordSetupRequired;
  final String updatedAt;

  factory PasswordSetupResultDto.fromJson(Map<String, dynamic> json) {
    return PasswordSetupResultDto(
      passwordSetupRequired: json['password_setup_required'] as bool? ?? false,
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}
