import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/category_meta.dart';
import '../../../../core/constants/fitness.dart';
import '../../../../core/models/host_profile_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/category_chip.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../matches/providers/matches_provider.dart';
import '../../providers/profile_provider.dart';
import '../widgets/gym_picker_sheet.dart';
import '../widgets/payouts_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: user == null ? const AppLoading() : _ProfileBody(user: user),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.user});

  final UserModel user;

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Sua conta continua em "Contas recentes" na tela de login para '
          'entrar de novo com um toque.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(authStateProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostProfile = ref.watch(myProfileProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myProfileProvider);
        await ref.read(authStateProvider.notifier).refresh();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x20,
          AppSpacing.x8,
          AppSpacing.x20,
          AppSpacing.x32,
        ),
        children: [
          _ProfileHeader(user: user),
          const SizedBox(height: AppSpacing.x24),
          hostProfile.when(
            loading: () => const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => AppCard(
              border: true,
              shadow: false,
              onTap: () => ref.invalidate(myProfileProvider),
              child: Text(
                'Não foi possível carregar seu perfil de anfitrião. Toque para tentar de novo.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            data: (profile) => profile == null
                ? const _BecomeHostCard()
                : Column(
                    children: [
                      _HostSummaryCard(profile: profile),
                      const PayoutsCard(),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.x24),
          _MenuSection(
            title: 'Conta',
            tiles: [
              _MenuTile(
                icon: Icons.person_outline_rounded,
                label: 'Editar meu perfil',
                onTap: () => context.push('/edit-profile'),
              ),
              _MenuTile(
                icon: Icons.fitness_center_rounded,
                label: 'Minha academia',
                value: user.gymName ?? 'Escolher',
                onTap: () async {
                  final changed = await showGymPicker(context);
                  if (changed) ref.invalidate(gymMembersProvider);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x16),
          _MenuSection(
            title: 'Suporte',
            tiles: [
              _MenuTile(
                icon: Icons.help_outline_rounded,
                label: 'Ajuda',
                onTap: () => context.push('/help'),
              ),
              _MenuTile(
                icon: Icons.shield_outlined,
                label: 'Privacidade e segurança',
                onTap: () => context.push('/privacy'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x16),
          _MenuTile(
            icon: Icons.logout_rounded,
            label: 'Sair',
            destructive: true,
            onTap: () => _logout(context, ref),
          ),
          const SizedBox(height: AppSpacing.x24),
          Center(
            child: Text(
              '${AppConstants.appName} · v1.0.0',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: AppRadius.brLg,
      onTap: () => context.push('/edit-profile'),
      child: Row(
        children: [
          AppAvatar(url: user.avatarUrl, name: user.name, radius: 36),
          const SizedBox(width: AppSpacing.x16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: t.headlineSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  user.email,
                  style: t.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.x8),
                Wrap(
                  spacing: AppSpacing.x6,
                  runSpacing: AppSpacing.x6,
                  children: [
                    CategoryChip(
                      label: Fitness.levelLabel(user.fitnessLevel),
                      compact: true,
                    ),
                    if (user.isHost)
                      const CategoryChip(label: 'Anfitrião', compact: true),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.ink400),
        ],
      ),
    );
  }
}

/// Invitation to offer paid meetings, shown to users without a listing.
class _BecomeHostCard extends StatelessWidget {
  const _BecomeHostCard();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x20),
      decoration: const BoxDecoration(
        borderRadius: AppRadius.brLg,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brand500, AppColors.brand700],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.workspace_premium_rounded,
              color: Colors.white, size: 28),
          const SizedBox(height: AppSpacing.x12),
          Text(
            'Seja um anfitrião',
            style: t.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.x4),
          Text(
            'Ofereça seu tempo para café, mentoria, treino e mais — e receba por isso.',
            style:
                t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: AppSpacing.x16),
          Material(
            color: Colors.white,
            borderRadius: AppRadius.brMd,
            child: InkWell(
              borderRadius: AppRadius.brMd,
              onTap: () => context.push('/host-profile/edit'),
              child: const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.x20,
                  vertical: AppSpacing.x12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 18, color: AppColors.brand600),
                    SizedBox(width: AppSpacing.x8),
                    Flexible(
                      child: Text(
                        'Criar perfil de anfitrião',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.brand600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HostSummaryCard extends StatelessWidget {
  const _HostSummaryCard({required this.profile});

  final HostProfileModel profile;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Seu perfil de anfitrião', style: t.titleLarge),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x8,
                  vertical: AppSpacing.x2,
                ),
                decoration: BoxDecoration(
                  color: profile.isActive ? AppColors.successBg : AppColors.ink100,
                  borderRadius: AppRadius.brPill,
                ),
                child: Text(
                  profile.isActive ? 'Visível' : 'Pausado',
                  style: t.labelSmall?.copyWith(
                    color: profile.isActive ? AppColors.success : AppColors.ink600,
                  ),
                ),
              ),
            ],
          ),
          if (profile.pricePerHour != null) ...[
            const SizedBox(height: AppSpacing.x4),
            Text(profile.priceLabel, style: t.bodyMedium),
          ],
          if (profile.categories.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x12),
            Wrap(
              spacing: AppSpacing.x8,
              runSpacing: AppSpacing.x8,
              children: profile.categories
                  .map((c) => CategoryChip(
                        label: categoryLabel(c),
                        icon: categoryIcon(c),
                        compact: true,
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: AppSpacing.x12),
          const Divider(height: 1),
          _CardLink(
            icon: Icons.edit_outlined,
            label: 'Editar anúncio',
            onTap: () => context.push('/host-profile/edit'),
          ),
          _CardLink(
            icon: Icons.calendar_month_outlined,
            label: 'Gerenciar horários',
            onTap: () => context.push('/manage-availability'),
          ),
          _CardLink(
            icon: Icons.visibility_outlined,
            label: 'Ver como os clientes veem',
            onTap: () => context.push('/host/${profile.id}', extra: profile),
          ),
        ],
      ),
    );
  }
}

class _CardLink extends StatelessWidget {
  const _CardLink({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.brSm,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.ink500),
            const SizedBox(width: AppSpacing.x8),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.ink400),
          ],
        ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.title, required this.tiles});

  final String title;
  final List<_MenuTile> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.x4, bottom: AppSpacing.x8),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0)
                  const Divider(
                      height: 1, indent: AppSpacing.x16 + 40 + AppSpacing.x12),
                tiles[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.value,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  /// Optional current setting shown right-aligned before the chevron.
  final String? value;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.ink900;
    final tile = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x16,
        vertical: AppSpacing.x12,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: destructive ? AppColors.errorBg : AppColors.ink100,
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: AppSpacing.x12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
            ),
          ),
          if (value != null) ...[
            Flexible(
              child: Text(
                value!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.ink500),
              ),
            ),
            const SizedBox(width: AppSpacing.x4),
          ],
          if (!destructive)
            const Icon(Icons.chevron_right_rounded, color: AppColors.ink400),
        ],
      ),
    );

    // Standalone (log out) tiles get their own card surface.
    if (destructive) {
      return AppCard(
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(borderRadius: AppRadius.brLg, onTap: onTap, child: tile),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: tile),
    );
  }
}
