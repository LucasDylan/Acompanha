import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/gym_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

/// Lets the user pick (or create) the gym they train at. Setting a gym is what
/// unlocks the "train together" feed, which only shows people from the same one.
///
/// Returns true through the sheet's pop value when the gym changed.
Future<bool> showGymPicker(BuildContext context) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _GymPickerSheet(),
  );
  return changed ?? false;
}

class _GymPickerSheet extends ConsumerStatefulWidget {
  const _GymPickerSheet();

  @override
  ConsumerState<_GymPickerSheet> createState() => _GymPickerSheetState();
}

class _GymPickerSheetState extends ConsumerState<_GymPickerSheet> {
  final _controller = TextEditingController();
  late Future<List<GymModel>> _future;
  String _query = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(profileRepositoryProvider).searchGyms('');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String q) {
    setState(() {
      _query = q;
      _future = ref.read(profileRepositoryProvider).searchGyms(q);
    });
  }

  Future<void> _select(GymModel gym) async {
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).setMyGym(gym.id);
      await ref.read(authStateProvider.notifier).refresh();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível salvar: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _createAndSelect() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final gym = await ref
          .read(profileRepositoryProvider)
          .createGym(name: name);
      await ref.read(profileRepositoryProvider).setMyGym(gym.id);
      await ref.read(authStateProvider.notifier).refresh();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível criar a academia: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final currentGymId = ref.watch(authStateProvider).valueOrNull?.gymId;
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.x12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.ink300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x20,
                AppSpacing.x16,
                AppSpacing.x20,
                AppSpacing.x8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Minha academia', style: t.titleLarge),
                  const SizedBox(height: AppSpacing.x4),
                  Text(
                    'Você só encontra parceiros de treino da mesma academia.',
                    style: t.bodySmall?.copyWith(color: AppColors.ink500),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x20),
              child: TextField(
                controller: _controller,
                onChanged: _search,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Buscar academia por nome ou cidade',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x12),
            Expanded(
              child: FutureBuilder<List<GymModel>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.x20),
                        child: Text(
                          'Não foi possível carregar as academias.',
                          style: t.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  final gyms = snap.data ?? const <GymModel>[];
                  if (gyms.isEmpty) {
                    return _EmptyGyms(
                      query: _query,
                      saving: _saving,
                      onCreate: _createAndSelect,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.x20,
                      0,
                      AppSpacing.x20,
                      AppSpacing.x24,
                    ),
                    itemCount: gyms.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final gym = gyms[i];
                      final selected = gym.id == currentGymId;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.fitness_center_rounded,
                            color: AppColors.ink500),
                        title: Text(gym.name),
                        subtitle: gym.subtitle.isEmpty
                            ? null
                            : Text(gym.subtitle),
                        trailing: selected
                            ? const Icon(Icons.check_circle_rounded,
                                color: AppColors.brand)
                            : null,
                        onTap: _saving ? null : () => _select(gym),
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

class _EmptyGyms extends StatelessWidget {
  const _EmptyGyms({
    required this.query,
    required this.saving,
    required this.onCreate,
  });

  final String query;
  final bool saving;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fitness_center_rounded,
              size: 40, color: AppColors.ink400),
          const SizedBox(height: AppSpacing.x12),
          Text(
            query.isEmpty
                ? 'Nenhuma academia cadastrada ainda'
                : 'Nenhuma academia encontrada',
            style: t.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.x8),
          Text(
            query.isEmpty
                ? 'Digite o nome da sua academia para cadastrá-la.'
                : 'Cadastre "$query" e comece a encontrar parceiros por lá.',
            style: t.bodySmall?.copyWith(color: AppColors.ink500),
            textAlign: TextAlign.center,
          ),
          if (query.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x20),
            AppButton(
              label: 'Cadastrar "$query"',
              icon: Icons.add_rounded,
              isLoading: saving,
              onPressed: onCreate,
            ),
          ],
        ],
      ),
    );
  }
}
