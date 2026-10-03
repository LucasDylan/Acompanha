import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/category_meta.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/discovery_repository.dart';
import '../../providers/discovery_provider.dart';
import '../widgets/host_card.dart';
import '../widgets/discovery_filters_sheet.dart';

class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(discoveryFeedProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(discoveryFeedProvider.future),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              // Fetch the next page a little before the end of the list.
              if (n.metrics.extentAfter < 600) {
                ref.read(discoveryFeedProvider.notifier).loadMore();
              }
              return false;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: _DiscoveryHeader()),
                const SliverToBoxAdapter(child: _CategoryFilterRow()),
                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.x8)),
                ...feed.when(
                  skipLoadingOnRefresh: true,
                  loading: () => const [
                    SliverToBoxAdapter(
                      child: SizedBox(height: 520, child: HostListSkeleton()),
                    ),
                  ],
                  error: (e, _) => [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'Não foi possível carregar',
                        message: e.toString(),
                        actionLabel: 'Tentar de novo',
                        tone: EmptyStateTone.error,
                        onAction: () => ref.invalidate(discoveryFeedProvider),
                      ),
                    ),
                  ],
                  data: (data) => _results(context, ref, data),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _results(BuildContext context, WidgetRef ref, HostFeed feed) {
    if (feed.items.isEmpty) {
      final filtered = ref.read(discoveryFiltersProvider).activeCount > 0;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.person_search_rounded,
            title: 'Nenhum anfitrião encontrado',
            message: filtered
                ? 'Tente tirar alguns filtros.'
                : 'Ainda não há anfitriões por aqui.',
            actionLabel: filtered ? 'Limpar filtros' : null,
            onAction: filtered
                ? () => ref.read(discoveryFiltersProvider.notifier).state =
                    const DiscoveryFilters()
                : null,
          ),
        ),
      ];
    }
    final filteredCategories = ref.watch(discoveryFiltersProvider).categories;
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x16,
          AppSpacing.x4,
          AppSpacing.x16,
          AppSpacing.x16,
        ),
        sliver: SliverList.separated(
          itemCount: feed.items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x16),
          itemBuilder: (context, index) {
            final host = feed.items[index];
            final card = HostCard(
              host: host,
              filteredCategories: filteredCategories,
              onTap: () => context.push('/host/${host.id}', extra: host),
            );
            // Only the first screenful animates in; later pages just appear.
            if (index > 5) return card;
            return card
                .animate()
                .fadeIn(duration: AppMotion.base, delay: (50 * index).ms)
                .slideY(begin: 0.08, end: 0, curve: AppMotion.standard);
          },
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.x32),
          child: Center(
            child: feed.loadingMore
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : feed.loadMoreFailed
                    ? TextButton(
                        onPressed: () =>
                            ref.read(discoveryFeedProvider.notifier).loadMore(),
                        child: const Text('Falha ao carregar mais · tentar de novo'),
                      )
                    : const SizedBox.shrink(),
          ),
        ),
      ),
    ];
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
                Text(
                  'Olá! 👋',
                  style: t.labelLarge?.copyWith(color: AppColors.brand600),
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
    final active = ref.watch(discoveryFiltersProvider).activeCount;
    return Badge(
      isLabelVisible: active > 0,
      label: Text('$active'),
      child: Material(
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
      ),
    );
  }
}

/// Category quick-filter chips (server-side filter on the feed).
class _CategoryFilterRow extends ConsumerWidget {
  const _CategoryFilterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(discoveryFiltersProvider);
    final selected =
        filters.categories.length == 1 ? filters.categories.first : null;

    void select(String? slug) {
      ref.read(discoveryFiltersProvider.notifier).state =
          filters.withCategories(slug == null ? const [] : [slug]);
    }

    final description = selected == null ? null : categoryDescription(selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x20),
            itemCount: meetingCategories.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.x8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _FilterChip(
                  label: 'Todos',
                  selected: filters.categories.isEmpty,
                  onTap: () => select(null),
                );
              }
              final category = meetingCategories[index - 1];
              return _FilterChip(
                label: category.label,
                icon: category.icon,
                selected: selected == category.slug,
                onTap: () =>
                    select(selected == category.slug ? null : category.slug),
              );
            },
          ),
        ),
        // Says what the picked kind of meeting is.
        if (description != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x20,
              AppSpacing.x8,
              AppSpacing.x20,
              0,
            ),
            child: Text(
              description,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.ink600),
            ),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final fg = selected ? Colors.white : AppColors.ink700;
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: AppSpacing.x6),
            ],
            Text(
              label,
              style: t.labelMedium?.copyWith(
                color: fg,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
