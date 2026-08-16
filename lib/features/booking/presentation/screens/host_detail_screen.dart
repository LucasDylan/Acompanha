import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/constants/category_meta.dart';
import '../../../../core/geo/city_coordinates.dart';
import '../../../../core/models/host_profile_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/price_tag.dart';
import '../../../discovery/providers/discovery_provider.dart';
import '../../../profile/providers/profile_provider.dart';
import '../widgets/slot_picker.dart';

class HostDetailScreen extends ConsumerWidget {
  const HostDetailScreen({super.key, required this.hostId});

  final String hostId;

  static const name = 'host_detail';

  /// Resolve a host from the discovery list first (covers mock + cached),
  /// falling back to a direct profile fetch.
  AsyncValue<HostProfileModel> _resolve(WidgetRef ref) {
    final listAsync = ref.watch(discoveryHostsProvider);
    final list = listAsync.valueOrNull;
    if (list != null) {
      for (final h in list) {
        if (h.id == hostId) return AsyncData(h);
      }
    }
    if (listAsync.isLoading) return const AsyncLoading();
    return ref.watch(hostProfileProvider(hostId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostAsync = _resolve(ref);

    return hostAsync.when(
      loading: () => const Scaffold(body: AppLoading()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.person_off_rounded,
          title: 'Perfil indisponível',
          message: 'Não foi possível carregar este perfil.',
          tone: EmptyStateTone.error,
          actionLabel: 'Voltar',
          onAction: () => context.pop(),
        ),
      ),
      data: (host) => _HostDetailView(host: host),
    );
  }
}

class _HostDetailView extends StatefulWidget {
  const _HostDetailView({required this.host});

  final HostProfileModel host;

  @override
  State<_HostDetailView> createState() => _HostDetailViewState();
}

class _HostDetailViewState extends State<_HostDetailView> {
  late String? _heroImage;

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

  @override
  void initState() {
    super.initState();
    _heroImage = _images.isNotEmpty ? _images.first : null;
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
    final isTopRated = (host.rating ?? 0) >= 4.8;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Social Meeting',
          style: t.titleLarge?.copyWith(color: AppColors.brand600),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.ios_share_rounded), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert_rounded), onPressed: () {}),
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
          _HeroPhoto(image: _heroImage, host: host),
          if (_images.length > 1) ...[
            const SizedBox(height: AppSpacing.x12),
            _ThumbnailStrip(
              images: _images,
              selected: _heroImage,
              onSelect: (img) => setState(() => _heroImage = img),
            ),
          ],
          const SizedBox(height: AppSpacing.x20),
          _NameRow(host: host, isTopRated: isTopRated),
          const SizedBox(height: AppSpacing.x8),
          _RatingRow(host: host),

          if (host.bio != null) ...[
            const SizedBox(height: AppSpacing.x24),
            _SectionTitle('Sobre mim'),
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
            _SectionTitle('Categorias de encontro'),
            const SizedBox(height: AppSpacing.x12),
            _CategoryGrid(categories: host.categories),
          ],

          if (host.pricePerHour != null) ...[
            const SizedBox(height: AppSpacing.x24),
            _SectionTitle('Preço e disponibilidade'),
            const SizedBox(height: AppSpacing.x12),
            _PriceList(host: host),
          ],

          const SizedBox(height: AppSpacing.x24),
          _SectionTitle('Segurança e confiança'),
          const SizedBox(height: AppSpacing.x12),
          const _SafetyCard(),

          if (host.location != null) ...[
            const SizedBox(height: AppSpacing.x24),
            _SectionTitle('Área preferida de encontro'),
            const SizedBox(height: AppSpacing.x12),
            _MeetupMap(location: host.location!),
          ],
        ],
      ),
      bottomNavigationBar: _ProposalBar(host: host, onSend: _openSlotSheet),
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
                initial: (host.displayName?.isNotEmpty ?? false)
                    ? host.displayName![0]
                    : null,
              ),
              // "Online agora" badge.
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
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.x6),
                      Text(
                        'Online agora',
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

class _NameRow extends StatelessWidget {
  const _NameRow({required this.host, required this.isTopRated});

  final HostProfileModel host;
  final bool isTopRated;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            host.displayName ?? 'Anfitrião',
            style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (isTopRated) ...[
          const SizedBox(width: AppSpacing.x8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'MELHOR AVALIADO',
                style: t.labelSmall?.copyWith(
                  color: AppColors.ink500,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.successBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    size: 18, color: AppColors.success),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.host});

  final HostProfileModel host;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final parts = <Widget>[];

    if (host.rating != null) {
      parts.addAll([
        const Icon(Icons.star_rounded, size: 18, color: AppColors.rating),
        const SizedBox(width: AppSpacing.x4),
        Text(host.rating!.toStringAsFixed(1), style: t.titleSmall),
      ]);
    }
    if (host.reviewCount > 0) {
      if (parts.isNotEmpty) {
        parts.add(Text('  •  ',
            style: t.bodyMedium?.copyWith(color: AppColors.ink400)));
      }
      parts.add(Text('${host.reviewCount} encontros realizados',
          style: t.bodyMedium?.copyWith(color: AppColors.ink600)));
    } else if (parts.isEmpty) {
      parts.add(Text('Novo por aqui',
          style: t.bodyMedium?.copyWith(color: AppColors.ink600)));
    }

    return Row(children: parts);
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.categories});

  final List<String> categories;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Two-per-row category tiles.
        Wrap(
          spacing: AppSpacing.x12,
          runSpacing: AppSpacing.x12,
          children: [
            for (final c in categories)
              SizedBox(
                width: (MediaQuery.of(context).size.width -
                        AppSpacing.x20 * 2 -
                        AppSpacing.x12) /
                    2,
                child: _CategoryTile(label: c),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.x12),
        // Decorative "exclusive events" row.
        AppCard(
          border: true,
          shadow: false,
          onTap: () {},
          child: Row(
            children: [
              const Icon(Icons.event_available_rounded,
                  color: AppColors.brand600),
              const SizedBox(width: AppSpacing.x12),
              Expanded(
                child: Text('Eventos exclusivos',
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.ink400),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: AppColors.ink200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.brand50,
              shape: BoxShape.circle,
            ),
            child: Icon(categoryIcon(label), color: AppColors.brand600, size: 22),
          ),
          const SizedBox(height: AppSpacing.x12),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

class _PriceList extends StatelessWidget {
  const _PriceList({required this.host});

  final HostProfileModel host;

  @override
  Widget build(BuildContext context) {
    final base = host.pricePerHour!;
    final rows = host.categories.isEmpty
        ? <String>['Encontro · 1h']
        : host.categories.take(3).map((c) => '$c · 1h').toList();

    return Column(
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: AppSpacing.x16),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x16,
                    vertical: AppSpacing.x16,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 20, color: AppColors.ink500),
                      const SizedBox(width: AppSpacing.x12),
                      Expanded(
                        child: Text(rows[i],
                            style: Theme.of(context).textTheme.bodyLarge),
                      ),
                      PriceTag(amount: base, currency: host.currency),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x8),
        Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 14, color: AppColors.ink400),
            const SizedBox(width: AppSpacing.x6),
            Expanded(
              child: Text(
                'Os valores já incluem a taxa de proteção da Social Meeting.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.ink500),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded,
                  color: AppColors.success, size: 20),
              const SizedBox(width: AppSpacing.x8),
              Text('Segurança e confiança',
                  style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.x16),
          const Row(
            children: [
              Expanded(
                child: _TrustBadge(
                  icon: Icons.badge_rounded,
                  label: 'Documento\nverificado',
                ),
              ),
              Expanded(
                child: _TrustBadge(
                  icon: Icons.face_rounded,
                  label: 'Selfie\nverificada',
                ),
              ),
              Expanded(
                child: _TrustBadge(
                  icon: Icons.fact_check_rounded,
                  label: 'Antecedentes\nchecados',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: AppColors.successBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.success, size: 22),
        ),
        const SizedBox(height: AppSpacing.x8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: AppColors.ink600),
        ),
      ],
    );
  }
}

/// Real Google Map centered on the host's city (coordinates resolved locally
/// from the city name via [CityCoordinates] — no backend lat/lng needed).
class _MeetupMap extends StatelessWidget {
  const _MeetupMap({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final coord = CityCoordinates.lookup(location);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: AppRadius.brLg,
          child: SizedBox(
            height: 170,
            child: coord == null
                ? Container(
                    color: AppColors.ink100,
                    child: const Center(
                      child: Icon(Icons.map_rounded,
                          size: 36, color: AppColors.ink400),
                    ),
                  )
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(coord.lat, coord.lng),
                      zoom: 12,
                    ),
                    liteModeEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    markers: {
                      Marker(
                        markerId: const MarkerId('host'),
                        position: LatLng(coord.lat, coord.lng),
                      ),
                    },
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.x12),
        Row(
          children: [
            const Icon(Icons.location_on_rounded,
                size: 18, color: AppColors.brand600),
            const SizedBox(width: AppSpacing.x6),
            Text(location, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ],
    );
  }
}

/// Sticky bottom bar with the primary "send proposal" CTA.
class _ProposalBar extends StatelessWidget {
  const _ProposalBar({required this.host, required this.onSend});

  final HostProfileModel host;
  final VoidCallback onSend;

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
          child: AppButton(
            label: 'Enviar proposta',
            icon: Icons.send_rounded,
            glow: true,
            onPressed: onSend,
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet that presents availability when the user taps the CTA.
class _SlotSheet extends StatelessWidget {
  const _SlotSheet({required this.host});

  final HostProfileModel host;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x20,
        AppSpacing.x8,
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
            'com ${host.displayName ?? 'o anfitrião'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.x20),
          SlotPicker(
            hostId: host.id,
            host: host,
            onSlotSelected: (slot) {
              Navigator.of(context).pop();
              context.push('/host/${host.id}/booking', extra: slot);
            },
          ),
        ],
      ),
    );
  }
}
