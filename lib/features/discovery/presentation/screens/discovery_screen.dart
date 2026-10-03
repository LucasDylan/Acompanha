import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../providers/discovery_provider.dart';
import '../widgets/host_card.dart';
import '../widgets/discovery_filters_sheet.dart';

class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostsAsync = ref.watch(filteredHostsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _DiscoveryHeader()),
            const SliverToBoxAdapter(child: _WorkoutFilterRow()),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.x8)),
            hostsAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: SizedBox(height: 520, child: HostListSkeleton()),
              ),
              error: (e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Não foi possível carregar',
                  message: 'Verifique sua conexão e tente novamente.',
                  actionLabel: 'Tentar de novo',
                  tone: EmptyStateTone.error,
                  onAction: () => ref.invalidate(discoveryHostsProvider),
                ),
              ),
              data: (partners) {
                if (partners.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.person_search_rounded,
                      title: 'Nenhum anfitrião por aqui ainda',
                      message:
                          'Ajuste os filtros ou explore outra região.',
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x16,
                    AppSpacing.x4,
                    AppSpacing.x16,
                    AppSpacing.x24,
                  ),
                  sliver: SliverList.separated(
                    itemCount: partners.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.x16),
                    itemBuilder: (context, index) {
                      final partner = partners[index];
                      return HostCard(
                        host: partner,
                        onTap: () => context.push('/host/${partner.id}'),
                      )
                          .animate()
                          .fadeIn(
                            duration: AppMotion.base,
                            delay: (50 * index).ms,
                          )
                          .slideY(
                            begin: 0.08,
                            end: 0,
                            curve: AppMotion.standard,
                          );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Header with greeting and filter button.
class _DiscoveryHeader extends StatelessWidget {
  const _DiscoveryHeader();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x20,
        AppSpacing.x12,
        AppSpacing.x16,
        AppSpacing.x16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x8,
                        vertical: AppSpacing.x4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.15),
                        borderRadius: AppRadius.brPill,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 12,
                            color: AppColors.brand400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Minha Região',
                            style: t.labelSmall?.copyWith(
                              color: AppColors.brand400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x8),
                Text(
                  'Encontre seu\npróximo encontro',
                  style: t.displaySmall?.copyWith(color: AppColors.ink900),
                ),
              ],
            ),
          ),
          _CircleIconButton(
            icon: Icons.search_rounded,
            tooltip: 'Buscar',
            onTap: () => context.push('/search'),
          ),
          const SizedBox(width: AppSpacing.x8),
          _FilterButton(),
        ],
      ),
    );
  }
}

/// Shared 48x48 outlined circular action used in the Discover header.
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip ?? '',
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink300, width: 1),
            ),
            child: Icon(icon, color: AppColors.ink700, size: 22),
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const DiscoveryFiltersSheet(),
        ),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.ink300, width: 1),
          ),
          child: const Icon(
            Icons.tune_rounded,
            color: AppColors.ink700,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// Workout type quick-filter chips.
class _WorkoutFilterRow extends ConsumerWidget {
  const _WorkoutFilterRow();

  static const _workouts = [
    'Musculação',
    'Cardio',
    'CrossFit',
    'Funcional',
    'Pilates',
    'Calistenia',
    'Natação',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCategoryProvider);

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x20),
        itemCount: _workouts.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.x8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _WorkoutChip(
              label: 'Todos',
              selected: selected == null,
              onTap: () =>
                  ref.read(selectedCategoryProvider.notifier).state = null,
            );
          }
          final w = _workouts[index - 1];
          return _WorkoutChip(
            label: w,
            selected: selected == w,
            onTap: () =>
                ref.read(selectedCategoryProvider.notifier).state =
                    selected == w ? null : w,
          );
        },
      ),
    );
  }
}

class _WorkoutChip extends StatelessWidget {
  const _WorkoutChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x16,
          vertical: AppSpacing.x8,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : AppColors.surface,
          borderRadius: AppRadius.brPill,
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.ink300,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: t.labelMedium?.copyWith(
            color: selected ? Colors.white : AppColors.ink700,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
