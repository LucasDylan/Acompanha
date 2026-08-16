import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';

/// Image-first building block.
///
/// Loads a remote image with a shimmering placeholder and — critically — a
/// *tasteful* fallback when there's no URL or it fails: a deterministic
/// brand-adjacent gradient with the subject's initial. This keeps the
/// photo-led layout looking intentional even before real images exist.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.seed = '',
    this.initial,
    this.fit = BoxFit.cover,
    this.fallbackIcon,
  });

  /// Remote image url (nullable — fallback is rendered when null/empty).
  final String? url;

  /// Stable string used to pick a consistent gradient for this subject.
  final String seed;

  /// Letter rendered on the fallback gradient (e.g. first letter of a name).
  final String? initial;

  final BoxFit fit;
  final IconData? fallbackIcon;

  List<Color> get _gradient {
    if (seed.isEmpty) return AppColors.avatarGradients.first;
    final idx = seed.codeUnits.fold<int>(0, (a, b) => a + b) %
        AppColors.avatarGradients.length;
    return AppColors.avatarGradients[idx];
  }

  Widget _fallback() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _gradient,
        ),
      ),
      child: Center(
        child: initial != null && initial!.isNotEmpty
            ? Text(
                initial!.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              )
            : Icon(
                fallbackIcon ?? Icons.person_rounded,
                color: Colors.white.withValues(alpha: 0.9),
                size: 48,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return _fallback();

    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: AppColors.ink200,
        highlightColor: AppColors.ink100,
        child: const ColoredBox(color: Colors.white),
      ),
      errorWidget: (_, __, ___) => _fallback(),
    );
  }
}

/// Circular avatar built on [AppNetworkImage] with the same graceful fallback.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.url,
    this.name,
    this.radius = 24,
    this.ring = false,
  });

  final String? url;
  final String? name;
  final double radius;

  /// Draws a subtle white ring + shadow (used over photos / colored bands).
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final initial = (name != null && name!.isNotEmpty) ? name![0] : null;
    final avatar = ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: AppNetworkImage(url: url, seed: name ?? '', initial: initial),
      ),
    );

    if (!ring) return avatar;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: avatar,
    );
  }
}
