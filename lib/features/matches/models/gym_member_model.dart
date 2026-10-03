/// Where the logged-in user stands with a gym mate.
enum MatchStatus { none, sent, received, matched }

/// Someone from the user's gym (`GET /gym-members/`).
class GymMemberModel {
  const GymMemberModel({
    required this.id,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.age,
    this.fitnessLevel,
    this.workoutTypes = const [],
    this.availableDays = const [],
    this.matchStatus = MatchStatus.none,
  });

  factory GymMemberModel.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? v) =>
        (v as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [];
    return GymMemberModel(
      id: json['id'].toString(),
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: (json['bio'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['bio'] as String,
      age: json['age'] as int?,
      fitnessLevel: json['fitness_level'] as String?,
      workoutTypes: strings(json['workout_types']),
      availableDays: strings(json['available_days']),
      matchStatus: switch (json['match_status'] as String?) {
        'sent' => MatchStatus.sent,
        'received' => MatchStatus.received,
        'matched' => MatchStatus.matched,
        _ => MatchStatus.none,
      },
    );
  }

  final String id;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final int? age;
  final String? fitnessLevel;
  final List<String> workoutTypes;
  final List<String> availableDays;
  final MatchStatus matchStatus;

  String get name =>
      (displayName?.trim().isNotEmpty ?? false) ? displayName! : 'Parceiro';

  GymMemberModel withStatus(MatchStatus status) => GymMemberModel(
        id: id,
        displayName: displayName,
        avatarUrl: avatarUrl,
        bio: bio,
        age: age,
        fitnessLevel: fitnessLevel,
        workoutTypes: workoutTypes,
        availableDays: availableDays,
        matchStatus: status,
      );
}
