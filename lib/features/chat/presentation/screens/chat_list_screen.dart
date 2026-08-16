import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  static const name = 'chat_list';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // MVP: static list. Real implementation would fetch from the API.
    const conversations = <_ConvPreview>[
      _ConvPreview(
        id: '1',
        name: 'Alex',
        lastMessage: 'Mal posso esperar pelo nosso café! ☕',
        time: '10:30',
        unread: true,
      ),
      _ConvPreview(
        id: '2',
        name: 'Jordan',
        lastMessage: 'Nos vemos no lobby do escritório.',
        time: 'Ontem',
        unread: false,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Mensagens')),
      body: conversations.isEmpty
          ? const EmptyState(
              icon: Icons.forum_outlined,
              title: 'Nenhuma mensagem ainda',
              message: 'Depois de marcar um encontro, você conversa com o anfitrião aqui.',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
              itemCount: conversations.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                indent: AppSpacing.x20 + 52 + AppSpacing.x12,
              ),
              itemBuilder: (context, index) =>
                  _ConversationTile(conv: conversations[index]),
            ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conv});

  final _ConvPreview conv;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => context.push('/chat/${conv.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x20,
          vertical: AppSpacing.x12,
        ),
        child: Row(
          children: [
            AppAvatar(url: null, name: conv.name, radius: 26),
            const SizedBox(width: AppSpacing.x12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(conv.name, style: t.titleMedium),
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    conv.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium?.copyWith(
                      color: conv.unread ? AppColors.ink900 : AppColors.ink500,
                      fontWeight:
                          conv.unread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.x8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(conv.time, style: t.bodySmall),
                const SizedBox(height: AppSpacing.x6),
                if (conv.unread)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.brand,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(height: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConvPreview {
  const _ConvPreview({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unread,
  });

  final String id;
  final String name;
  final String lastMessage;
  final String time;
  final bool unread;
}
