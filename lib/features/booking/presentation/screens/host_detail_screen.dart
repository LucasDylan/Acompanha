import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../app/routes/app_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/geo/city_coordinates.dart';
import '../../../../core/models/host_profile_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/category_chip.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/price_tag.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../../safety/presentation/safety_actions.dart';
import '../../data/booking_repository.dart';
import '../../providers/booking_provider.dart';
import '../widgets/slot_picker.dart';

/// The region map needs a Google Maps API key in the native projects; without
/// one it would render blank, so it's only shown in builds made with
/// --dart-define=GOOGLE_MAPS=true.
const _mapsEnabled = bool.fromEnvironment('GOOGLE_MAPS');

class HostDetailScreen extends ConsumerWidget {
  const HostDetailScreen({super.key, required this.hostId, this.initial});

  final String hostId;

  /// The listing as shown on the card that was tapped, so the page renders
  /// immediately while the fresh copy loads.
  final HostProfileModel? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostAsync = ref.watch(hostProfileProvider(hostId));
    final host = hostAsync.valueOrNull ?? initial;

    if (host != null) return _HostDetailView(host: host);
    if (hostAsync.hasError) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.person_off_rounded,
          title: 'Perfil indisponível',
          message: hostAsync.error.toString(),
          tone: EmptyStateTone.error,
          actionLabel: 'Voltar',
          onAction: () => context.pop(),
        ),
      );
    }
    return const Scaffold(body: AppLoading());
  }
}

class _HostDetailView extends ConsumerStatefulWidget {
  const _HostDetailView({required this.host});

  final HostProfileModel host;

  @override
  ConsumerState<_HostDetailView> createState() => _HostDetailViewState();
}

class _HostDetailViewState extends ConsumerState<_HostDetailView> {
  String? _heroImage;

  HostProfileModel get host => widget.host;

  /// All available images (avatar first, then gallery), de-duplicated.
  List<String> get _images {
    final out = <String>[];
    if (host.avatarUrl != null) out.add(host.avatarUrl!);
    for (final p in host.photos) {
      if (!out.contains(p)) out.add(p);
    }
    return out;
  }

  void _openSlotSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SlotSheet(host: host),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final images = _images;
    final hero = _heroImage ?? (images.isNotEmpty ? images.first : null);
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    final isMine = myId != null && myId == host.userId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (!isMine)
            SafetyMenuButton(
              userId: host.userId,
              name: host.name,
              onBlocked: () => context.pop(),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x20,
          AppSpacing.x16,
          AppSpacing.x20,
          AppSpacing.x32,
        ),
        children: [
          _HeroPhoto(image: hero, host: host),
          if (images.length > 1) ...[
            const SizedBox(height: AppSpacing.x12),
            _ThumbnailStrip(
              images: images,
              selected: hero,
              onSelect: (img) => setState(() => _heroImage = img),
            ),
          ],
          const SizedBox(height: AppSpacing.x20),
          Text(
            host.name,
            style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.x8),
          _RatingRow(host: host),
          if (host.location != null) ...[
            const SizedBox(height: AppSpacing.x4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 16, color: AppColors.ink500),
                const SizedBox(width: AppSpacing.x4),
                Text(host.location!,
                    style: t.bodyMedium?.copyWith(color: AppColors.ink600)),
              ],
            ),
          ],

          if (host.bio != null) ...[
            const SizedBox(height: AppSpacing.x24),
            const _SectionTitle('Sobre'),
            const SizedBox(height: AppSpacing.x12),
            AppCard(
              color: AppColors.ink50,
              shadow: false,
              border: true,
              child: Text(host.bio!, style: t.bodyLarge),
            ),
          ],

          if (host.categories.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x24),
            const _SectionTitle('O que oferece'),
            const SizedBox(height: AppSpacing.x12),
            _CategoryList(categories: host.categories),
          ],

          if (host.pricePerHour != null) ...[
            const SizedBox(height: AppSpacing.x24),
            const _SectionTitle('Valor'),
            const SizedBox(height: AppSpacing.x12),
            AppCard(
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 20, color: AppColors.ink500),
                  const SizedBox(width: AppSpacing.x12),
                  Expanded(child: Text('Por hora', style: t.bodyLarge)),
                  PriceTag(amount: host.pricePerHour!, currency: host.currency),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.x24),
          const _SectionTitle('Como funciona'),
          const SizedBox(height: AppSpacing.x12),
          const _HowItWorksCard(),

          const SizedBox(height: AppSpacing.x24),
          _ReviewsSection(host: host),

          if (_mapsEnabled &&
              host.location != null &&
              CityCoordinates.lookup(host.location) != null) ...[
            const SizedBox(height: AppSpacing.x24),
            const _SectionTitle('Região'),
            const SizedBox(height: AppSpacing.x12),
            _MeetupMap(location: host.location!),
          ],
        ],
      ),
      bottomNavigationBar: isMine
          ? _BottomBar(
              child: AppButton.secondary(
                label: 'Este é o seu perfil · editar',
                icon: Icons.edit_rounded,
                onPressed: () => context.push('/host-profile/edit'),
              ),
            )
          : _BottomBar(
              child: AppButton(
                label: host.pricePerHour == null
                    ? 'Ver horários'
                    : 'Ver horários · ${host.priceLabel}',
                icon: Icons.event_available_rounded,
                glow: true,
                onPressed: _openSlotSheet,
              ),
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _HeroPhoto extends StatelessWidget {
  const _HeroPhoto({required this.image, required this.host});

  final String? image;
  final HostProfileModel host;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: AppRadius.brXl,
        boxShadow: AppShadows.md,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.brXl,
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppNetworkImage(
                url: image,
                seed: host.displayName ?? host.id,
                initial: host.name[0],
              ),
              if (host.isTrainer)
                Positioned(
                  left: AppSpacing.x12,
                  bottom: AppSpacing.x12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x12,
                      vertical: AppSpacing.x6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: AppRadius.brPill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded,
                            size: 14, color: Colors.white),
                        const SizedBox(width: AppSpacing.x6),
                        Text(
                          'Personal trainer',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbnailStrip extends StatelessWidget {
  const _ThumbnailStrip({
    required this.images,
    required this.selected,
    required this.onSelect,
  });

  final List<String> images;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.x8),
        itemBuilder: (context, i) {
          final img = images[i];
          final isSelected = img == selected;
          return GestureDetector(
            onTap: () => onSelect(img),
            child: Container(
              width: 64,
              decoration: BoxDecoration(
                borderRadius: AppRadius.brMd,
                border: Border.all(
                  color: isSelected ? AppColors.brand : AppColors.ink200,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md - 2),
                child: AppNetworkImage(url: img, seed: '$i'),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.host});

  final HostProfileModel host;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (host.rating == null || host.reviewCount == 0) {
      return Text('Novo por aqui · ainda sem avaliações',
          style: t.bodyMedium?.copyWith(color: AppColors.ink600));
    }
    return Row(
      children: [
        const Icon(Icons.star_rounded, size: 18, color: AppColors.rating),
        const SizedBox(width: AppSpacing.x4),
        Text(host.rating!.toStringAsFixed(1), style: t.titleSmall),
        Text('  •  ', style: t.bodyMedium?.copyWith(color: AppColors.ink400)),
        Text(
          host.reviewCount == 1 ? '1 avaliação' : '${host.reviewCount} avaliações',
          style: t.bodyMedium?.copyWith(color: AppColors.ink600),
        ),
      ],
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.categories});

  final List<String> categories;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, slug) in categories.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.x8),
          Container(
            padding: const EdgeInsets.all(AppSpacing.x16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.brLg,
              border: Border.all(color: AppColors.ink200),
            ),
            child: CategoryInfo(slug: slug),
          ),
        ],
      ],
    );
  }
}

/// What the platform actually guarantees — no claims it doesn't back up.
class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.event_available_rounded,
        'Escolha um horário livre e confirme a reserva.',
      ),
      (
        Icons.lock_rounded,
        'O pagamento é feito no app, com cartão, de forma segura.',
      ),
      (
        Icons.chat_bubble_outline_rounded,
        'Depois de reservar, combine os detalhes pelo chat.',
      ),
      (
        Icons.undo_rounded,
        'Cancelamento com reembolso até ${AppConstants.freeCancellationHours}h antes.',
      ),
    ];
    final t = Theme.of(context).textTheme;
    return AppCard(
      border: true,
      shadow: false,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.x12),
            Row(
              children: [
                Icon(items[i].$1, size: 20, color: AppColors.brand600),
                const SizedBox(width: AppSpacing.x12),
                Expanded(child: Text(items[i].$2, style: t.bodyMedium)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewsSection extends ConsumerWidget {
  const _ReviewsSection({required this.host});

  final HostProfileModel host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(hostReviewsProvider(host.id)).valueOrNull;
    if (reviews == null || reviews.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Avaliações'),
        const SizedBox(height: AppSpacing.x12),
        for (final r in reviews.take(5)) ...[
          _ReviewTile(review: r),
          const SizedBox(height: AppSpacing.x8),
        ],
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final HostReview review;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      border: true,
      shadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(
                  i <= review.rating ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 16,
                  color: AppColors.rating,
                ),
              const SizedBox(width: AppSpacing.x8),
              Expanded(
                child: Text(review.author,
                    style: t.labelLarge, overflow: TextOverflow.ellipsis),
              ),
              Text(formatDayMonth(review.createdAt), style: t.bodySmall),
            ],
          ),
          if (review.comment != null) ...[
            const SizedBox(height: AppSpacing.x8),
            Text(review.comment!, style: t.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// Google Map centered on the host's city (coordinates resolved locally from
/// the city name via [CityCoordinates] — no backend lat/lng needed).
class _MeetupMap extends StatelessWidget {
  const _MeetupMap({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final coord = CityCoordinates.lookup(location)!;
    return ClipRRect(
      borderRadius: AppRadius.brLg,
      child: SizedBox(
        height: 170,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(coord.lat, coord.lng),
            zoom: 11,
          ),
          liteModeEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.md,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x20,
            AppSpacing.x12,
            AppSpacing.x20,
            AppSpacing.x12,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Bottom sheet listing the host's open times.
class _SlotSheet extends StatelessWidget {
  const _SlotSheet({required this.host});

  final HostProfileModel host;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x20,
          AppSpacing.x20,
          AppSpacing.x20,
          AppSpacing.x24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Escolha um horário',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.x4),
            Text(
              'com ${host.name}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.x20),
            SlotPicker(
              host: host,
              onSlotSelected: (slot) {
                Navigator.of(context).pop();
                context.push(
                  '/host/${host.id}/booking',
                  extra: BookingDraft(host: host, slot: slot),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
