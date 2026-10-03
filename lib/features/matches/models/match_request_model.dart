/// The other person shown on a match card (`PartnerBriefSerializer`).
class MatchPartner {
  const MatchPartner({required this.id, this.displayName, this.avatarUrl});

  factory MatchPartner.fromJson(Map<String, dynamic> json) {
    return MatchPartner(
      id: json['id'].toString(),
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  final String id;
  final String? displayName;
  final String? avatarUrl;

  String get label => (displayName?.isNotEmpty ?? false) ? displayName! : 'Parceiro';
}

enum MatchRequestStatus { pending, accepted, declined }

class MatchRequestModel {
  const MatchRequestModel({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.status,
    this.createdAt,
  });

  factory MatchRequestModel.fromJson(Map<String, dynamic> json) {
    return MatchRequestModel(
      id: json['id'].toString(),
      sender: MatchPartner.fromJson(json['sender'] as Map<String, dynamic>),
      receiver: MatchPartner.fromJson(json['receiver'] as Map<String, dynamic>),
      status: switch (json['status'] as String?) {
        'accepted' => MatchRequestStatus.accepted,
        'declined' => MatchRequestStatus.declined,
        _ => MatchRequestStatus.pending,
      },
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }

  final String id;
  final MatchPartner sender;
  final MatchPartner receiver;
  final MatchRequestStatus status;
  final DateTime? createdAt;

  /// The person on the other side of this request, given the logged-in user.
  MatchPartner other(String myUserId) =>
      sender.id == myUserId ? receiver : sender;
}

enum SessionStatus { pending, confirmed, completed, cancelled }

/// A workout two partners scheduled together.
class TrainingSessionModel {
  const TrainingSessionModel({
    required this.id,
    required this.initiator,
    required this.partner,
    required this.scheduledAt,
    required this.status,
    this.durationMinutes = 60,
    this.workoutType,
    this.notes,
  });

  factory TrainingSessionModel.fromJson(Map<String, dynamic> json) {
    return TrainingSessionModel(
      id: json['id'].toString(),
      initiator: MatchPartner.fromJson(json['initiator'] as Map<String, dynamic>),
      partner: MatchPartner.fromJson(json['partner'] as Map<String, dynamic>),
      scheduledAt: DateTime.parse(json['scheduled_at'] as String).toLocal(),
      durationMinutes: json['duration_minutes'] as int? ?? 60,
      workoutType: (json['workout_type'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['workout_type'] as String,
      notes: (json['notes'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['notes'] as String,
      status: switch (json['status'] as String?) {
        'confirmed' => SessionStatus.confirmed,
        'completed' => SessionStatus.completed,
        'cancelled' => SessionStatus.cancelled,
        _ => SessionStatus.pending,
      },
    );
  }

  final String id;
  final MatchPartner initiator;
  final MatchPartner partner;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String? workoutType;
  final String? notes;
  final SessionStatus status;

  MatchPartner other(String myUserId) =>
      initiator.id == myUserId ? partner : initiator;

  bool get isUpcoming => scheduledAt.isAfter(DateTime.now());
}
