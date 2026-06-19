class User {
  const User({
    required this.userId,
    required this.phone,
    required this.nickname,
    required this.avatar,
    required this.signature,
    required this.hasPassword,
  });

  final int userId;
  final String phone;
  final String nickname;
  final String avatar;
  final String signature;
  final bool hasPassword;

  bool get hasCustomAvatar =>
      avatar.isNotEmpty && !avatar.startsWith('identicon:');

  String get identiconSeed {
    if (avatar.startsWith('identicon:')) {
      return avatar.substring('identicon:'.length);
    }
    return '$userId';
  }

  User copyWith({
    int? userId,
    String? phone,
    String? nickname,
    String? avatar,
    String? signature,
    bool? hasPassword,
  }) {
    return User(
      userId: userId ?? this.userId,
      phone: phone ?? this.phone,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      signature: signature ?? this.signature,
      hasPassword: hasPassword ?? this.hasPassword,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: (json['account_id'] as num?)?.toInt() ?? 0,
      phone: json['phone'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
      signature: json['signature'] as String? ?? '',
      hasPassword: json['has_password'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'account_id': userId,
      'phone': phone,
      'nickname': nickname,
      'avatar': avatar,
      'signature': signature,
      'has_password': hasPassword,
    };
  }
}
