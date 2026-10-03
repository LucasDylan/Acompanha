import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../data/chat_repository.dart';
import '../models/conversation_model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(apiClient: ref.watch(apiClientProvider));
});

/// The inbox. Re-fetched every few seconds while someone is looking at it —
/// there is no push channel yet, so polling is what makes new chats show up.
final conversationsProvider =
    FutureProvider.autoDispose<List<ConversationModel>>((ref) async {
  final timer = Timer(const Duration(seconds: 10), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.read(chatRepositoryProvider).getConversations();
});

/// Total unread messages, for the badge on the Messages tab.
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final timer = Timer(const Duration(seconds: 30), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.read(chatRepositoryProvider).unreadCount();
});

/// Opens the chat with [userId] from anywhere (a booking, a partner...).
Future<void> openChatWith(
  BuildContext context,
  WidgetRef ref,
  String userId,
) async {
  try {
    final conversation =
        await ref.read(chatRepositoryProvider).openWith(userId);
    if (context.mounted) {
      // A leftover snackbar would sit on top of the message composer.
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      context.push('/chat/${conversation.id}', extra: conversation);
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
    );
  }
}
