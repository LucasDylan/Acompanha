
class HostProfileModel {
  const HostProfileModel({
    required this.id,
    required this.userId,
    this.displayName,
    this.bio,
    this.avatarUrl,
    this.photos = const [],
    this.categories = const [],
    this.pricePerHour,
    this.currency = 'USD',
    this.rating,
    this.reviewCount = 0,
    this.location,
    this.fitnessLevel,
  });

  factory HostProfileModel.fromJson(Map<String, dynamic> json) {
    return HostProfileModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      categories:
          (json['categories'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              [],
      pricePerHour: (json['price_per_hour'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: json['review_count'] as int? ?? 0,
      location: json['location'] as String?,
      fitnessLevel: json['fitness_level'] as String?,
    );
  }

  final String id;
  final String userId;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
  final List<String> photos;
  final List<String> categories;
  final double? pricePerHour;
  final String currency;
  final double? rating;
  final int reviewCount;
  final String? location;
  final String? fitnessLevel;

  String get priceLabel {
    if (pricePerHour == null) return '';
    return '$currency ${pricePerHour!.toStringAsFixed(0)}/hr';
  }
}
