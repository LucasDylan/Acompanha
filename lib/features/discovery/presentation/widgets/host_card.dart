import 'package:flutter/material.dart';

import '../../../../core/constants/category_meta.dart';
import '../../../../core/models/host_profile_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/category_chip.dart';
import '../../../../core/widgets/price_tag.dart';
import '../../../../core/widgets/rating_pill.dart';

/// Large, image-first discovery card (4:5 portrait, à la Hinge / Bumble).
///
/// The photo carries the card; name, location, rating and price are overlaid
/// on a bottom scrim so the layout stays legible over any image. The category
/// and rating float at the top as frosted chips.
class HostCard extends StatelessWidget {
  const HostCard({
    super.key,
    required this.host,
    required this.onTap,
    this.distanceLabel,
    this.filteredCategories = const [],
  });

  final HostProfileModel host;
  final VoidCallback onTap;

  /// Optional "12 km" badge appended to the location (used by search results).
  final String? distanceLabel;

  /// Categories the feed is filtered by. The tag shows one of these when the
  /// host offers it, so the card says why it's in the results.
  final List<String> filteredCategories;

  String? get _tag {
    for (final c in host.categories) {
      if (filteredCategories.contains(c)) return c;
    }
    return host.categories.isEmpty ? null : host.categories.first;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tag = _tag;

    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: AppRadius.brXl,
        boxShadow: AppShadows.md,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.brXl,
        child: Material(
          color: AppColors.surface,
          child: InkWell(
            onTap: onTap,
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Photo.
                  AppNetworkImage(
                    url: host.avatarUrl,
                    seed: host.displayName ?? host.id,
                    initial: (host.displayName?.isNotEmpty ?? false)
                        ? host.displayName![0]
                        : null,
                  ),
                  // Legibility scrim.
                  const DecoratedBox(
                    decoration: BoxDecoration(gradient: AppColors.photoScrim),
                  ),
                  // Top row: category + rating.
                  Positioned(
                    top: AppSpacing.x16,
                    left: AppSpacing.x16,
                    right: AppSpacing.x16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (host.isTrainer)
                          const GlassChip(
                            label: 'Personal trainer',
                            icon: Icons.verified_rounded,
                          )
                        else if (tag != null)
                          GlassChip(
                            label: categoryLabel(tag),
                            icon: categoryIcon(tag),
                          )
                        else
                          const SizedBox.shrink(),
                        if (host.rating != null)
                          RatingPill(
                            rating: host.rating!,
                            reviewCount: host.reviewCount,
                            onPhoto: true,
                          ),
                      ],
                    ),
                  ),
                  // Bottom content.
                  Positioned(
                    left: AppSpacing.x20,
                    right: AppSpacing.x20,
                    bottom: AppSpacing.x20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                host.name,
                                style: t.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (host.pricePerHour != null)
                              PriceTag(
                                amount: host.pricePerHour!,
                                currency: host.currency,
                                onPhoto: true,
                              ),
                          ],
                        ),
                        if (host.location != null || distanceLabel != null) ...[
                          const SizedBox(height: AppSpacing.x4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded,
                                  size: 14, color: Colors.white70),
                              const SizedBox(width: AppSpacing.x4),
                              Flexible(
                                child: Text(
                                  [
                                    if (host.location != null) host.location!,
                                    if (distanceLabel != null) distanceLabel!,
                                  ].join('  ·  '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.bodyMedium
                                      ?.copyWith(color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (host.bio != null) ...[
                          const SizedBox(height: AppSpacing.x8),
                          Text(
                            host.bio!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
