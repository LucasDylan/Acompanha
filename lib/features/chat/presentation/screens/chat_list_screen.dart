import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/conversation_model.dart';
import '../../providers/chat_provider.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);

    Widget body;
    if (conversations.hasValue) {
      final list = conversations.value!;
      body = list.isEmpty
          ? const EmptyState(
              icon: Icons.forum_outlined,
              title: 'Nenhuma mensagem ainda',
              message: 'Converse com um anfitrião depois de reservar, ou com '
                  'um parceiro de treino depois que ele aceitar seu pedido.',
            )
          : RefreshIndicator(
              onRefresh: () => ref.refresh(conversationsProvider.future),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  indent: AppSpacing.x20 + 52 + AppSpacing.x12,
                ),
                itemBuilder: (context, index) =>
                    _ConversationTile(conversation: list[index]),
              ),
            );
    } else if (conversations.hasError) {
      body = EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Não foi possível carregar as mensagens',
        message: conversations.error.toString(),
        tone: EmptyStateTone.error,
        actionLabel: 'Tentar de novo',
        onAction: () => ref.invalidate(conversationsProvider),
      );
    } else {
      body = const AppLoading();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mensagens')),
      body: body,
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation});

  final ConversationModel conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    final last = conversation.lastMessage;
    final unread = conversation.unreadCount > 0;
    final preview = last == null
        ? ''
        : (last.senderId == myId ? 'Você: ${last.text}' : last.text);

    return InkWell(
      onTap: () async {
        await context.push('/chat/${conversation.id}', extra: conversation);
        ref.invalidate(conversationsProvider);
        ref.invalidate(unreadCountProvider);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x20,
          vertical: AppSpacing.x12,
        ),
        child: Row(
          children: [
            AppAvatar(
              url: conversation.otherUser.avatarUrl,
              name: conversation.otherUser.name,
              radius: 26,
            ),
            const SizedBox(width: AppSpacing.x12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(conversation.otherUser.name, style: t.titleMedium),
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium?.copyWith(
                      color: unread ? AppColors.ink900 : AppColors.ink500,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.x8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (last != null)
                  Text(formatRelativeDay(last.createdAt), style: t.bodySmall),
                const SizedBox(height: AppSpacing.x6),
                if (unread)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x6,
                      vertical: 1,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: AppRadius.brPill,
                    ),
                    child: Text(
                      '${conversation.unreadCount}',
                      style: t.labelSmall?.copyWith(color: Colors.white),
                    ),
                  )
                else
                  const SizedBox(height: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
