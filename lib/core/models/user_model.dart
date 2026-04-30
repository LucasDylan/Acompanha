enum UserRole { host, client, both }

class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.role = UserRole.client,
    this.isHostProfileComplete = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: _roleFromString(json['role'] as String?),
      isHostProfileComplete: json['is_host_profile_complete'] as bool? ?? false,
    );
  }

  static UserRole _roleFromString(String? s) {
    switch (s?.toLowerCase()) {
      case 'host':
        return UserRole.host;
      case 'both':
        return UserRole.both;
      default:
        return UserRole.client;
    }
  }

  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final UserRole role;
  final bool isHostProfileComplete;

  bool get isHost => role == UserRole.host || role == UserRole.both;

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'role': role.name,
        'is_host_profile_complete': isHostProfileComplete,
      };
}
