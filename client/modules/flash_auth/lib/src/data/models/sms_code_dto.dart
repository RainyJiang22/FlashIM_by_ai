class SmsCodeDto {
  const SmsCodeDto({required this.phone, required this.code});

  final String phone;
  final String code;

  factory SmsCodeDto.fromJson(Map<String, dynamic> json) {
    return SmsCodeDto(
      phone: json['phone'] as String? ?? '',
      code: json['code'] as String? ?? '',
    );
  }
}
