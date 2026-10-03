class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String? profileImageUrl;
  final String defaultCurrency;
  final bool isActive;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    this.profileImageUrl,
    this.defaultCurrency = 'INR',
    this.isActive = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      phoneNumber: json['phone_number'],
      profileImageUrl: json['profile_image_url'],
      defaultCurrency: json['default_currency'] ?? 'INR',
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'phone_number': phoneNumber,
    'profile_image_url': profileImageUrl,
    'default_currency': defaultCurrency,
    'is_active': isActive,
  };
}
