/// The logged-in user's own account (`GET /auth/me/`).
class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.gymId,
    this.gymName,
    this.fitnessLevel,
    this.workoutTypes = const [],
    this.availableDays = const [],
    this.bio,
    this.age,
    this.isHost = false,
    this.hostProfileId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final gym = json['gym'] as Map<String, dynamic>?;
    List<String> strings(Object? v) =>
        (v as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [];
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      gymId: gym?['id']?.toString(),
      gymName: gym?['name'] as String?,
      fitnessLevel: json['fitness_level'] as String?,
      workoutTypes: strings(json['workout_types']),
      availableDays: strings(json['available_days']),
      bio: json['bio'] as String?,
      age: json['age'] as int?,
      isHost: json['is_host'] as bool? ?? false,
      hostProfileId: json['host_profile_id']?.toString(),
    );
  }

  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;

  /// The gym this user trains at. Required for the "train together" feed —
  /// `GET /gym-members/` returns nothing while it is null.
  final String? gymId;
  final String? gymName;
  final String? fitnessLevel;
  final List<String> workoutTypes;
  final List<String> availableDays;
  final String? bio;
  final int? age;
  final bool isHost;
  final String? hostProfileId;

  bool get hasGym => gymId != null;

  String get name =>
      (displayName?.trim().isNotEmpty ?? false) ? displayName!.trim() : email;
}
