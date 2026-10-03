class GymModel {
  const GymModel({
    required this.id,
    required this.name,
    this.address,
    this.city,
    this.memberCount = 0,
  });

  factory GymModel.fromJson(Map<String, dynamic> json) {
    return GymModel(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      address: json['address'] as String?,
      city: json['city'] as String?,
      memberCount: json['member_count'] as int? ?? 0,
    );
  }

  final String id;
  final String name;
  final String? address;
  final String? city;
  final int memberCount;

  String get subtitle {
    final parts = [
      if (city != null && city!.isNotEmpty) city!,
      if (memberCount > 0) '$memberCount ${memberCount == 1 ? 'membro' : 'membros'}',
    ];
    return parts.join('  ·  ');
  }
}
