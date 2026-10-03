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

enum MatchStatus { pending, accepted, declined }

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
        'accepted' => MatchStatus.accepted,
        'declined' => MatchStatus.declined,
        _ => MatchStatus.pending,
      },
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }

  final String id;
  final MatchPartner sender;
  final MatchPartner receiver;
  final MatchStatus status;
  final DateTime? createdAt;

  /// The person on the other side of this request, given the logged-in user.
  MatchPartner other(String myUserId) =>
      sender.id == myUserId ? receiver : sender;
}
