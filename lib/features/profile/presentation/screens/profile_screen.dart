import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/host_profile_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/category_chip.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final myProfile = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: authState.when(
        loading: () => const AppLoading(),
        error: (_, __) => _loggedOut(context),
        data: (user) {
          if (user == null) return _loggedOut(context);
          return myProfile.when(
            loading: () => _ProfileBody(user: user, profile: null),
            error: (_, __) => _ProfileBody(user: user, profile: null),
            data: (profile) => _ProfileBody(user: user, profile: profile),
          );
        },
      ),
    );
  }

  Widget _loggedOut(BuildContext context) {
    return EmptyState(
      icon: Icons.person_outline_rounded,
      title: 'Entre para continuar',
      message: 'Gerencie suas reservas, mensagens e perfil de anfitrião.',
      actionLabel: 'Entrar',
      onAction: () => context.push('/login'),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.user, required this.profile});

  final UserModel user;
  final HostProfileModel? profile;

  String get _roleLabel => switch (user.role) {
        UserRole.host => 'Anfitrião',
        UserRole.both => 'Anfitrião e Cliente',
        UserRole.client => 'Membro',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasHostProfile = profile != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x20,
        AppSpacing.x8,
        AppSpacing.x20,
        AppSpacing.x32,
      ),
      children: [
        _ProfileHeader(user: user, roleLabel: _roleLabel),
        const SizedBox(height: AppSpacing.x24),

        if (hasHostProfile)
          _HostSummaryCard(profile: profile!)
        else
          const _BecomeHostCard(),
        const SizedBox(height: AppSpacing.x24),

        _MenuSection(
          title: 'Conta',
          tiles: [
            _MenuTile(
              icon: Icons.person_outline_rounded,
              label: 'Editar perfil',
              onTap: () => context.push('/edit-profile'),
            ),
            _MenuTile(
              icon: Icons.credit_card_rounded,
              label: 'Formas de pagamento',
              onTap: () {},
            ),
            _MenuTile(
              icon: Icons.notifications_none_rounded,
              label: 'Notificações',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x16),
        _MenuSection(
          title: 'Suporte',
          tiles: [
            _MenuTile(
              icon: Icons.help_outline_rounded,
              label: 'Central de ajuda',
              onTap: () {},
            ),
            _MenuTile(
              icon: Icons.shield_outlined,
              label: 'Segurança e privacidade',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x16),
        _MenuTile(
          icon: Icons.logout_rounded,
          label: 'Sair',
          destructive: true,
          onTap: () async {
            await ref.read(authStateProvider.notifier).logout();
            if (context.mounted) context.go('/login');
          },
        ),
        const SizedBox(height: AppSpacing.x24),
        Center(
          child: Text(
            'Social Meeting · v1.0.0',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user, required this.roleLabel});

  final UserModel user;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        AppAvatar(
          url: user.avatarUrl,
          name: user.displayName ?? user.email,
          radius: 36,
        ),
        const SizedBox(width: AppSpacing.x16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName ?? user.email,
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
              CategoryChip(label: roleLabel, compact: true),
            ],
          ),
        ),
      ],
    );
  }
}

/// Upsell shown to members who aren't hosts yet — gradient accent + clear value.
class _BecomeHostCard extends StatelessWidget {
  const _BecomeHostCard();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x20),
      decoration: BoxDecoration(
        borderRadius: AppRadius.brLg,
        gradient: const LinearGradient(
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
            'Ofereça seu tempo para café, mentoria e mais — e seja pago por isso.',
            style: t.bodyMedium
                ?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: AppSpacing.x16),
          Builder(
            builder: (context) => Material(
              color: Colors.white,
              borderRadius: AppRadius.brMd,
              child: InkWell(
                borderRadius: AppRadius.brMd,
                onTap: () => context.push('/edit-profile'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.x20,
                    vertical: AppSpacing.x12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded,
                          size: 18, color: AppColors.brand600),
                      SizedBox(width: AppSpacing.x8),
                      Text(
                        'Criar perfil de anfitrião',
                        style: TextStyle(
                          color: AppColors.brand600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
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
      onTap: () => context.push('/edit-profile'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Seu perfil de anfitrião', style: t.titleLarge),
              ),
              const Icon(Icons.edit_rounded, size: 18, color: AppColors.ink500),
            ],
          ),
          if (profile.bio != null) ...[
            const SizedBox(height: AppSpacing.x8),
            Text(profile.bio!, style: t.bodyMedium, maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          if (profile.categories.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x12),
            Wrap(
              spacing: AppSpacing.x8,
              runSpacing: AppSpacing.x8,
              children: profile.categories
                  .map((c) => CategoryChip(label: c, compact: true))
                  .toList(),
            ),
          ],
        ],
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
          padding: const EdgeInsets.only(
            left: AppSpacing.x4,
            bottom: AppSpacing.x8,
          ),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, indent: AppSpacing.x16 + 40 + AppSpacing.x12),
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
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

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
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: color),
            ),
          ),
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
          child: InkWell(
            borderRadius: AppRadius.brLg,
            onTap: onTap,
            child: tile,
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: tile),
    );
  }
}
