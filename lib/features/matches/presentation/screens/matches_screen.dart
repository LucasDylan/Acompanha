import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/fitness.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../chat/providers/chat_provider.dart';
import '../../../discovery/presentation/widgets/partner_card.dart';
import '../../../profile/presentation/widgets/gym_picker_sheet.dart';
import '../../models/gym_member_model.dart';
import '../../models/match_request_model.dart';
import '../../providers/matches_provider.dart';
import '../widgets/schedule_session_sheet.dart';

/// The "Parceiros" tab — the free side of the product: find someone at your
/// gym to train with so you don't go alone.
class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incoming = ref.watch(incomingRequestsProvider).valueOrNull?.length ?? 0;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Parceiros de treino'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              const Tab(text: 'Encontrar'),
              Tab(
                child: Badge(
                  isLabelVisible: incoming > 0,
                  label: Text('$incoming'),
                  offset: const Offset(14, -4),
                  child: const Text('Solicitações'),
                ),
              ),
              const Tab(text: 'Meus parceiros'),
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

void _snack(BuildContext context, String message, {Color? color}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: color),
  );
}

class _FindPartnersTab extends ConsumerStatefulWidget {
  const _FindPartnersTab();

  @override
  ConsumerState<_FindPartnersTab> createState() => _FindPartnersTabState();
}

class _FindPartnersTabState extends ConsumerState<_FindPartnersTab> {
  final _busy = <String>{};

  Future<void> _act(GymMemberModel member) async {
    if (member.matchStatus == MatchStatus.matched) {
      await openChatWith(context, ref, member.id);
      return;
    }
    setState(() => _busy.add(member.id));
    try {
      final mutual = await ref.read(matchActionsProvider).sendRequest(member.id);
      if (!mounted) return;
      _snack(
        context,
        mutual
            ? 'Vocês agora são parceiros de treino! 🎉'
            : 'Pedido enviado para ${member.name}',
        color: mutual ? AppColors.success : null,
      );
    } catch (e) {
      if (mounted) _snack(context, e.toString(), color: AppColors.error);
    } finally {
      if (mounted) setState(() => _busy.remove(member.id));
    }
  }

  Future<void> _pickGym() async {
    final changed = await showGymPicker(context);
    if (changed) ref.invalidate(gymMembersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;

    if (user != null && !user.hasGym) {
      return EmptyState(
        icon: Icons.fitness_center_rounded,
        title: 'Escolha sua academia',
        message:
            'Parceiros de treino são da mesma academia que você. Diga onde treina '
            'para ver quem está por lá.',
        actionLabel: 'Escolher academia',
        onAction: _pickGym,
      );
    }

    final membersAsync = ref.watch(gymMembersProvider);

    return membersAsync.when(
      loading: () => const HostListSkeleton(),
      error: (e, _) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Não foi possível carregar',
        message: e.toString(),
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
            onAction: _pickGym,
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(gymMembersProvider.future),
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
              return PartnerCard(
                member: member,
                busy: _busy.contains(member.id),
                onTap: () => _showMemberSheet(context, member),
                onAction: () => _act(member),
              );
            },
          ),
        );
      },
    );
  }

  void _showMemberSheet(BuildContext context, GymMemberModel member) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final t = Theme.of(context).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppAvatar(url: member.avatarUrl, name: member.name, radius: 28),
                    const SizedBox(width: AppSpacing.x12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member.name, style: t.titleLarge),
                          Text(
                            Fitness.levelLabel(member.fitnessLevel),
                            style: t.bodyMedium?.copyWith(color: AppColors.ink500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (member.bio != null) ...[
                  const SizedBox(height: AppSpacing.x16),
                  Text(member.bio!, style: t.bodyMedium),
                ],
                if (member.workoutTypes.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x16),
                  Text('Treinos', style: t.titleSmall),
                  const SizedBox(height: AppSpacing.x8),
                  Wrap(
                    spacing: AppSpacing.x8,
                    runSpacing: AppSpacing.x8,
                    children: member.workoutTypes
                        .map((w) => Chip(label: Text(w)))
                        .toList(),
                  ),
                ],
                if (member.availableDays.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x16),
                  Text('Costuma treinar', style: t.titleSmall),
                  const SizedBox(height: AppSpacing.x4),
                  Text(member.availableDays.join(' · '), style: t.bodyMedium),
                ],
              ],
            ),
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
      _snack(
        context,
        accept ? 'Parceria confirmada 🎉' : 'Pedido recusado',
        color: accept ? AppColors.success : AppColors.ink500,
      );
    } catch (e) {
      if (context.mounted) _snack(context, e.toString(), color: AppColors.error);
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
        message: e.toString(),
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
          onRefresh: () => ref.refresh(incomingRequestsProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.x16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x12),
            itemBuilder: (context, i) {
              final req = requests[i];
              return _PersonRow(
                partner: req.sender,
                subtitle: 'Quer treinar com você',
                trailing: [
                  IconButton(
                    tooltip: 'Recusar',
                    onPressed: () => _respond(context, ref, req.id, false),
                    icon: const Icon(Icons.close_rounded, color: AppColors.ink500),
                  ),
                  IconButton.filled(
                    tooltip: 'Aceitar',
                    onPressed: () => _respond(context, ref, req.id, true),
                    icon: const Icon(Icons.check_rounded),
                  ),
                ],
              );
            },
          ),
        );
      },
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
        message: e.toString(),
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
          onRefresh: () => ref.refresh(myMatchesProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.x16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x12),
            itemBuilder: (context, i) {
              final partner = list[i].other(myId);
              return _PersonRow(
                partner: partner,
                trailing: [
                  IconButton(
                    tooltip: 'Mensagem',
                    onPressed: () => openChatWith(context, ref, partner.id),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Marcar treino',
                    onPressed: () async {
                      final created = await showScheduleSessionSheet(context, partner);
                      if (created && context.mounted) {
                        _snack(
                          context,
                          'Convite enviado para ${partner.label}. '
                          'Acompanhe em Reservas › Treinos.',
                          color: AppColors.success,
                        );
                      }
                    },
                    icon: const Icon(Icons.event_rounded),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.partner,
    required this.trailing,
    this.subtitle,
  });

  final MatchPartner partner;
  final String? subtitle;
  final List<Widget> trailing;

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
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.x2),
                  Text(subtitle!,
                      style: t.bodySmall?.copyWith(color: AppColors.ink500)),
                ],
              ],
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }
}
