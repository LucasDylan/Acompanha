import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/geo/city_coordinates.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/category_chip.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../discovery/presentation/widgets/host_card.dart';
import '../../providers/search_provider.dart';

/// The "Buscar" tab — search profiles by name/city and (with permission) by
/// real distance from the user's GPS location.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchResultsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.x20,
                AppSpacing.x12,
                AppSpacing.x20,
                AppSpacing.x8,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _Title(),
              ),
            ),
            _SearchField(controller: _controller),
            const SizedBox(height: AppSpacing.x12),
            const _CityChips(),
            const SizedBox(height: AppSpacing.x12),
            const _NearMeBar(),
            const Divider(height: AppSpacing.x24),
            Expanded(
              child: resultsAsync.when(
                loading: () => const HostListSkeleton(),
                error: (e, _) => EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Não foi possível buscar',
                  message: 'Verifique sua conexão e tente novamente.',
                  tone: EmptyStateTone.error,
                  actionLabel: 'Tentar de novo',
                  onAction: () => ref.invalidate(searchAllHostsProvider),
                ),
                data: (results) {
                  if (results.isEmpty) {
                    return const EmptyState(
                      icon: Icons.travel_explore_rounded,
                      title: 'Nenhum perfil encontrado',
                      message:
                          'Tente outra cidade, aumente o raio ou limpe a busca.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.x20,
                      AppSpacing.x4,
                      AppSpacing.x20,
                      AppSpacing.x24,
                    ),
                    itemCount: results.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.x20),
                    itemBuilder: (context, i) {
                      final r = results[i];
                      return HostCard(
                        host: r.host,
                        distanceLabel: r.distanceLabel,
                        onTap: () => context.push('/host/${r.host.id}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Buscar',
            style: t.labelMedium?.copyWith(color: AppColors.brand600)),
        const SizedBox(height: AppSpacing.x4),
        Text('Encontre perfis', style: t.displaySmall),
      ],
    );
  }
}

class _SearchField extends ConsumerWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x20),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onChanged: (v) =>
            ref.read(searchQueryProvider.notifier).state = v,
        decoration: InputDecoration(
          hintText: 'Buscar por nome ou cidade',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    controller.clear();
                    ref.read(searchQueryProvider.notifier).state = '';
                  },
                ),
        ),
      ),
    );
  }
}

class _CityChips extends ConsumerWidget {
  const _CityChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(searchCityProvider);
    final cities = CityCoordinates.popular;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x20),
        itemCount: cities.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.x8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return CategoryChip(
              label: 'Todas as cidades',
              icon: Icons.public_rounded,
              selected: selected == null,
              onTap: () =>
                  ref.read(searchCityProvider.notifier).state = null,
            );
          }
          final city = cities[index - 1];
          return CategoryChip(
            label: city,
            icon: Icons.location_city_rounded,
            selected: selected == city,
            onTap: () => ref.read(searchCityProvider.notifier).state =
                selected == city ? null : city,
          );
        },
      ),
    );
  }
}

/// "Perto de mim" toggle + radius chips + permission messaging.
class _NearMeBar extends ConsumerWidget {
  const _NearMeBar();

  static const _radii = <double?>[5, 10, 25, 50, null];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useLocation = ref.watch(useMyLocationProvider);
    final locationAsync = ref.watch(useMyLocationProvider)
        ? ref.watch(userLocationProvider)
        : const AsyncValue<dynamic>.data(null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x20),
          child: Row(
            children: [
              const Icon(Icons.near_me_rounded,
                  size: 18, color: AppColors.ink700),
              const SizedBox(width: AppSpacing.x8),
              Expanded(
                child: Text(
                  'Perto de mim',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Switch(
                value: useLocation,
                onChanged: (v) {
                  ref.read(useMyLocationProvider.notifier).state = v;
                  if (v) {
                    ref.invalidate(userLocationProvider);
                  } else {
                    ref.read(searchRadiusKmProvider.notifier).state = null;
                  }
                },
              ),
            ],
          ),
        ),
        if (useLocation)
          locationAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.x20,
                vertical: AppSpacing.x8,
              ),
              child: Row(
                children: [
                  SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: AppSpacing.x12),
                  Text('Localizando você…'),
                ],
              ),
            ),
            error: (_, __) => const _LocationError(),
            data: (result) {
              // result is LocationResult? — null when toggle just turned off.
              if (result == null) return const SizedBox.shrink();
              if (!result.isSuccess) return _LocationError(result: result);
              return _RadiusChips(radii: _radii);
            },
          ),
      ],
    );
  }
}

class _RadiusChips extends ConsumerWidget {
  const _RadiusChips({required this.radii});

  final List<double?> radii;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(searchRadiusKmProvider);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x20),
        itemCount: radii.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.x8),
        itemBuilder: (context, i) {
          final r = radii[i];
          final label = r == null ? 'Qualquer distância' : 'Até ${r.round()} km';
          return CategoryChip(
            label: label,
            selected: selected == r,
            onTap: () => ref.read(searchRadiusKmProvider.notifier).state = r,
          );
        },
      ),
    );
  }
}

class _LocationError extends ConsumerWidget {
  const _LocationError({this.result});

  final dynamic result; // LocationResult | null

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = result?.message as String? ??
        'Não foi possível obter sua localização.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x20,
        AppSpacing.x4,
        AppSpacing.x20,
        AppSpacing.x4,
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: AppColors.warning),
          const SizedBox(width: AppSpacing.x8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(userLocationProvider),
            child: const Text('Tentar'),
          ),
        ],
      ),
    );
  }
}
