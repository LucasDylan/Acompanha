import '../utils/formatters.dart';

/// A host's public listing in Discovery.
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
    this.currency = 'BRL',
    this.rating,
    this.reviewCount = 0,
    this.location,
    this.isTrainer = false,
    this.isActive = true,
  });

  factory HostProfileModel.fromJson(Map<String, dynamic> json) {
    return HostProfileModel(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      displayName: json['display_name'] as String?,
      bio: (json['bio'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['bio'] as String,
      avatarUrl: json['avatar_url'] as String?,
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      pricePerHour: (json['price_per_hour'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'BRL',
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: json['review_count'] as int? ?? 0,
      location: (json['location'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['location'] as String,
      isTrainer: json['is_trainer'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  final String id;
  final String userId;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
  final List<String> photos;

  /// Category slugs — see `category_meta.dart` for labels.
  final List<String> categories;
  final double? pricePerHour;
  final String currency;
  final double? rating;
  final int reviewCount;
  final String? location;

  /// Professional personal trainer with an active Pro plan.
  final bool isTrainer;
  final bool isActive;

  String get name =>
      (displayName?.trim().isNotEmpty ?? false) ? displayName! : 'Anfitrião';

  String get priceLabel => pricePerHour == null
      ? ''
      : '${formatMoney(pricePerHour!, currency, compact: true)}/h';
}
