import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_network_image.dart';

/// MVP: static chat UI. WebSocket integration ready for production.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  static const name = 'chat';

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_Msg>[
    _Msg(text: 'Oi! Mal posso esperar pelo nosso encontro.', isMe: false),
    _Msg(text: 'Eu também! Nos vemos no café.', isMe: true),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_Msg(text: text, isMe: true));
      _controller.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            const AppAvatar(url: null, name: 'Anfitrião', radius: 18),
            const SizedBox(width: AppSpacing.x12),
            Text('Anfitrião', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppSpacing.x20),
              itemCount: _messages.length,
              itemBuilder: (context, i) => _Bubble(msg: _messages[i]),
            ),
          ),
          _Composer(controller: _controller, onSend: _send),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg});

  final _Msg msg;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppRadius.lg),
      topRight: const Radius.circular(AppRadius.lg),
      bottomLeft: Radius.circular(msg.isMe ? AppRadius.lg : AppRadius.sm),
      bottomRight: Radius.circular(msg.isMe ? AppRadius.sm : AppRadius.lg),
    );

    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.x8),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x16,
          vertical: AppSpacing.x12,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: msg.isMe ? AppColors.brand : AppColors.ink100,
          borderRadius: radius,
        ),
        child: Text(
          msg.text,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: msg.isMe ? Colors.white : AppColors.ink900,
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
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Mensagem…',
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

class _Msg {
  const _Msg({required this.text, required this.isMe});
  final String text;
  final bool isMe;
}
