import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../discovery/presentation/widgets/partner_card.dart';
import '../../../profile/presentation/widgets/gym_picker_sheet.dart';
import '../../models/match_request_model.dart';
import '../../providers/matches_provider.dart';

/// The "Matches" tab — the free side of the product: find someone at your gym
/// to train with so you don't go alone.
class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Parceiros de treino'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Encontrar'),
              Tab(text: 'Solicitações'),
              Tab(text: 'Meus parceiros'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FindPartnersTab(),
            _IncomingTab(),
            _MyMatchesTab(),
          ],
        ),
      ),
    );
  }
}

class _FindPartnersTab extends ConsumerWidget {
  const _FindPartnersTab();

  Future<void> _send(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String name,
  ) async {
    try {
      final mutual = await ref.read(matchActionsProvider).sendRequest(userId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mutual
                ? 'Vocês deram match! $name também queria treinar com você 🎉'
                : 'Pedido enviado para $name',
          ),
          backgroundColor: mutual ? AppColors.success : AppColors.brand,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível enviar: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;

    if (user != null && !user.hasGym) {
      return EmptyState(
        icon: Icons.fitness_center_rounded,
        title: 'Escolha sua academia',
        message:
            'Parceiros de treino são da mesma academia que você. Diga onde treina '
            'para ver quem está por lá.',
        actionLabel: 'Escolher academia',
        onAction: () async {
          final changed = await showGymPicker(context);
          if (changed) ref.invalidate(gymMembersProvider);
        },
      );
    }

    final membersAsync = ref.watch(gymMembersProvider);
    final sent = ref.watch(sentRequestIdsProvider);

    return membersAsync.when(
      loading: () => const HostListSkeleton(),
      error: (e, _) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Não foi possível carregar',
        message: 'Verifique sua conexão e tente novamente.',
        tone: EmptyStateTone.error,
        actionLabel: 'Tentar de novo',
        onAction: () => ref.invalidate(gymMembersProvider),
      ),
      data: (members) {
        if (members.isEmpty) {
          return EmptyState(
            icon: Icons.person_search_rounded,
            title: 'Ninguém por aqui ainda',
            message: user?.gymName == null
                ? 'Ainda não há outras pessoas cadastradas na sua academia.'
                : 'Você é a primeira pessoa da ${user!.gymName} por aqui. '
                    'Chame alguém do seu treino!',
            actionLabel: 'Trocar de academia',
            onAction: () async {
              final changed = await showGymPicker(context);
              if (changed) ref.invalidate(gymMembersProvider);
            },
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(gymMembersProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x16,
              AppSpacing.x16,
              AppSpacing.x16,
              AppSpacing.x24,
            ),
            itemCount: members.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x16),
            itemBuilder: (context, i) {
              final member = members[i];
              final name = member.displayName ?? 'Parceiro';
              return PartnerCard(
                host: member,
                requestSent: sent.contains(member.userId),
                onTap: () => _showMemberSheet(context, member.displayName,
                    member.bio, member.categories),
                onSendRequest: () => _send(context, ref, member.userId, name),
              );
            },
          ),
        );
      },
    );
  }

  void _showMemberSheet(
    BuildContext context,
    String? name,
    String? bio,
    List<String> workouts,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final t = Theme.of(context).textTheme;
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.x24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name ?? 'Parceiro', style: t.titleLarge),
              if (bio != null && bio.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.x8),
                Text(bio, style: t.bodyMedium),
              ],
              if (workouts.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.x16),
                Text('Treinos', style: t.titleSmall),
                const SizedBox(height: AppSpacing.x8),
                Wrap(
                  spacing: AppSpacing.x8,
                  runSpacing: AppSpacing.x8,
                  children: workouts
                      .map((w) => Chip(label: Text(w)))
                      .toList(),
                ),
              ],
              const SizedBox(height: AppSpacing.x8),
            ],
          ),
        );
      },
    );
  }
}

class _IncomingTab extends ConsumerWidget {
  const _IncomingTab();

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    String requestId,
    bool accept,
  ) async {
    try {
      await ref
          .read(matchActionsProvider)
          .respond(requestId: requestId, accept: accept);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Parceria confirmada 🎉' : 'Pedido recusado'),
          backgroundColor: accept ? AppColors.success : AppColors.ink500,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível responder: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incoming = ref.watch(incomingRequestsProvider);

    return incoming.when(
      loading: () => const AppLoading(),
      error: (e, _) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Não foi possível carregar',
        message: 'Verifique sua conexão e tente novamente.',
        tone: EmptyStateTone.error,
        actionLabel: 'Tentar de novo',
        onAction: () => ref.invalidate(incomingRequestsProvider),
      ),
      data: (requests) {
        if (requests.isEmpty) {
          return const EmptyState(
            icon: Icons.mark_email_unread_outlined,
            title: 'Nenhuma solicitação',
            message: 'Quando alguém quiser treinar com você, aparece aqui.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(incomingRequestsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.x16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x12),
            itemBuilder: (context, i) {
              final req = requests[i];
              return _RequestTile(
                partner: req.sender,
                onAccept: () => _respond(context, ref, req.id, true),
                onDecline: () => _respond(context, ref, req.id, false),
              );
            },
          ),
        );
      },
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.partner,
    required this.onAccept,
    required this.onDecline,
  });

  final MatchPartner partner;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: AppColors.ink200),
      ),
      child: Row(
        children: [
          AppAvatar(url: partner.avatarUrl, name: partner.label, radius: 24),
          const SizedBox(width: AppSpacing.x12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(partner.label, style: t.titleSmall),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  'Quer treinar com você',
                  style: t.bodySmall?.copyWith(color: AppColors.ink500),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Recusar',
            onPressed: onDecline,
            icon: const Icon(Icons.close_rounded, color: AppColors.ink500),
          ),
          IconButton.filled(
            tooltip: 'Aceitar',
            onPressed: onAccept,
            icon: const Icon(Icons.check_rounded),
          ),
        ],
      ),
    );
  }
}

class _MyMatchesTab extends ConsumerWidget {
  const _MyMatchesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(authStateProvider).valueOrNull?.id ?? '';
    final matches = ref.watch(myMatchesProvider);

    return matches.when(
      loading: () => const AppLoading(),
      error: (e, _) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Não foi possível carregar',
        message: 'Verifique sua conexão e tente novamente.',
        tone: EmptyStateTone.error,
        actionLabel: 'Tentar de novo',
        onAction: () => ref.invalidate(myMatchesProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.handshake_outlined,
            title: 'Nenhum parceiro ainda',
            message:
                'Mande um pedido na aba "Encontrar" — quando a outra pessoa '
                'aceitar, ela aparece aqui.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myMatchesProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.x16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x12),
            itemBuilder: (context, i) {
              final partner = list[i].other(myId);
              return Container(
                padding: const EdgeInsets.all(AppSpacing.x12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.brLg,
                  border: Border.all(color: AppColors.ink200),
                ),
                child: Row(
                  children: [
                    AppAvatar(
                      url: partner.avatarUrl,
                      name: partner.label,
                      radius: 24,
                    ),
                    const SizedBox(width: AppSpacing.x12),
                    Expanded(
                      child: Text(
                        partner.label,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => context.push('/chat/${partner.id}'),
                      icon: const Icon(Icons.chat_bubble_outline_rounded,
                          size: 18),
                      label: const Text('Mensagem'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
