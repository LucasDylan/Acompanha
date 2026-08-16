import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart' show AppSpacing, AppRadius;

/// Minimal centered spinner — kept for small inline cases.
class AppLoading extends StatelessWidget {
  const AppLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        height: 28,
        width: 28,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      ),
    );
  }
}

/// Wraps any layout in the app's shimmer so skeletons share one shimmer
/// timing/color. Premium apps show skeletons, not spinners.
class ShimmerPlaceholder extends StatelessWidget {
  const ShimmerPlaceholder({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.ink200,
      highlightColor: AppColors.ink100,
      child: child,
    );
  }
}

/// A neutral skeleton block (rounded rectangle) for composing skeletons.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Full-screen skeleton matching the Discovery card list layout, so the load
/// state previews the real content shape.
class HostListSkeleton extends StatelessWidget {
  const HostListSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ShimmerPlaceholder(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x20,
          AppSpacing.x8,
          AppSpacing.x20,
          AppSpacing.x20,
        ),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x20),
        itemBuilder: (_, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 5,
              child: SkeletonBox(
                height: double.infinity,
                width: double.infinity,
                radius: AppRadius.lg,
              ),
            ),
            const SizedBox(height: AppSpacing.x12),
            const SkeletonBox(width: 160, height: 18),
            const SizedBox(height: AppSpacing.x8),
            const SkeletonBox(width: 220, height: 14),
          ],
        ),
      ),
    );
  }
}
