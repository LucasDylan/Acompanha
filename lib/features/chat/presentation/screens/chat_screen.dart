import 'dart:async';

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
import '../../../safety/presentation/safety_actions.dart';
import '../../models/conversation_model.dart';
import '../../providers/chat_provider.dart';

/// A one-to-one conversation. New messages arrive by polling every few
/// seconds while the screen is open.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId, this.initial});

  final String conversationId;

  /// Conversation as already known by the caller, so the header shows
  /// immediately instead of after a fetch.
  final ConversationModel? initial;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const _pollEvery = Duration(seconds: 3);

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <ChatMessage>[];
  ChatPeer? _peer;
  Object? _loadError;
  bool _loading = true;
  Timer? _poll;
  int _localIds = 0;

  @override
  void initState() {
    super.initState();
    _peer = widget.initial?.otherUser;
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String? get _lastServerId {
    for (final m in _messages.reversed) {
      if (!m.sending && !m.failed) return m.id;
    }
    return null;
  }

  Future<void> _load() async {
    final repo = ref.read(chatRepositoryProvider);
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final peer = _peer ??
          (await repo.getConversation(widget.conversationId)).otherUser;
      final messages = await repo.getMessages(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _peer = peer;
        _messages
          ..clear()
          ..addAll(messages);
        _loading = false;
      });
      _scrollToEnd(jump: true);
      ref.invalidate(unreadCountProvider);
      _poll = Timer.periodic(_pollEvery, (_) => _fetchNew());
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _fetchNew() async {
    try {
      final fresh = await ref
          .read(chatRepositoryProvider)
          .getMessages(widget.conversationId, afterId: _lastServerId);
      if (!mounted || fresh.isEmpty) return;
      final known = _messages.map((m) => m.id).toSet();
      final added = fresh.where((m) => !known.contains(m.id)).toList();
      if (added.isEmpty) return;
      setState(() {
        // Server copies replace optimistic ones the moment they're sent, so
        // anything here is from the other person (or another device).
        final pending = _messages.where((m) => m.sending || m.failed).toList();
        _messages
          ..removeWhere((m) => m.sending || m.failed)
          ..addAll(added)
          ..addAll(pending);
      });
      _scrollToEnd();
    } catch (_) {
      // Polling failures are transient; the next tick tries again.
    }
  }

  Future<void> _send([ChatMessage? retry]) async {
    final text = retry?.text ?? _controller.text.trim();
    if (text.isEmpty) return;
    final myId = ref.read(authStateProvider).valueOrNull?.id ?? '';
    final local = retry?.copyWith(sending: true, failed: false) ??
        ChatMessage(
          id: 'local-${_localIds++}',
          senderId: myId,
          text: text,
          createdAt: DateTime.now(),
          sending: true,
        );

    setState(() {
      if (retry != null) {
        _messages[_messages.indexOf(retry)] = local;
      } else {
        _messages.add(local);
        _controller.clear();
      }
    });
    _scrollToEnd();

    try {
      final sent =
          await ref.read(chatRepositoryProvider).send(widget.conversationId, text);
      if (!mounted) return;
      setState(() {
        final i = _messages.indexWhere((m) => m.id == local.id);
        if (_messages.any((m) => m.id == sent.id)) {
          // Polling already brought the server copy in.
          if (i >= 0) _messages.removeAt(i);
        } else if (i >= 0) {
          _messages[i] = sent;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final i = _messages.indexWhere((m) => m.id == local.id);
        if (i >= 0) _messages[i] = local.copyWith(sending: false, failed: true);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    }
  }

  void _scrollToEnd({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final end = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(end);
      } else {
        _scrollController.animateTo(
          end,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    final peer = _peer;

    Widget body;
    if (_loading) {
      body = const AppLoading();
    } else if (_loadError != null) {
      body = EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Não foi possível abrir a conversa',
        message: _loadError.toString(),
        tone: EmptyStateTone.error,
        actionLabel: 'Tentar de novo',
        onAction: _load,
      );
    } else {
      body = Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? EmptyState(
                    icon: Icons.waving_hand_outlined,
                    title: 'Diga oi para ${peer?.name ?? 'a outra pessoa'}',
                    message: 'Combinem o local e os detalhes por aqui.',
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.x20),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final msg = _messages[i];
                      final prev = i > 0 ? _messages[i - 1] : null;
                      final newDay = prev == null ||
                          !DateUtils.isSameDay(prev.createdAt, msg.createdAt);
                      return Column(
                        children: [
                          if (newDay) _DayDivider(date: msg.createdAt),
                          _Bubble(
                            msg: msg,
                            isMe: msg.senderId == myId,
                            onRetry: msg.failed ? () => _send(msg) : null,
                          ),
                        ],
                      );
                    },
                  ),
          ),
          _Composer(controller: _controller, onSend: _send),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            AppAvatar(url: peer?.avatarUrl, name: peer?.name, radius: 18),
            const SizedBox(width: AppSpacing.x12),
            Flexible(
              child: Text(
                peer?.name ?? '',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        actions: [
          if (peer != null)
            SafetyMenuButton(
              userId: peer.id,
              name: peer.name,
              conversationId: widget.conversationId,
              onBlocked: () => context.pop(),
            ),
        ],
      ),
      body: body,
    );
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x12),
      child: Text(
        DateUtils.isSameDay(date, DateTime.now()) ? 'Hoje' : formatDayMonth(date),
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: AppColors.ink500),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg, required this.isMe, this.onRetry});

  final ChatMessage msg;
  final bool isMe;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppRadius.lg),
      topRight: const Radius.circular(AppRadius.lg),
      bottomLeft: Radius.circular(isMe ? AppRadius.lg : AppRadius.sm),
      bottomRight: Radius.circular(isMe ? AppRadius.sm : AppRadius.lg),
    );

    final status = msg.failed
        ? 'Não enviada · toque para tentar de novo'
        : msg.sending
            ? 'Enviando…'
            : formatTime(msg.createdAt);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: onRetry,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.x8),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x16,
            AppSpacing.x10,
            AppSpacing.x16,
            AppSpacing.x8,
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: msg.failed
                ? AppColors.errorBg
                : isMe
                    ? AppColors.brand
                    : AppColors.ink100,
            borderRadius: radius,
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                msg.text,
                style: t.bodyLarge?.copyWith(
                  color: isMe && !msg.failed ? Colors.white : AppColors.ink900,
                ),
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(
                status,
                style: t.labelSmall?.copyWith(
                  color: msg.failed
                      ? AppColors.error
                      : isMe
                          ? Colors.white70
                          : AppColors.ink500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.ink200)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Mensagem…',
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.x16,
                      vertical: AppSpacing.x12,
                    ),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: AppSpacing.x8),
              Material(
                color: AppColors.brand,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onSend,
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.arrow_upward_rounded, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
