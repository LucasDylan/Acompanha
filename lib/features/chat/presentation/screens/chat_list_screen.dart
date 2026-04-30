import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  static const name = 'chat_list';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // MVP: Static list. Real implementation would fetch from API.
    final conversations = <_ConvPreview>[
      _ConvPreview(
        id: '1',
        name: 'Alex',
        lastMessage: 'Looking forward to our coffee!',
        time: '10:30',
      ),
      _ConvPreview(
        id: '2',
        name: 'Jordan',
        lastMessage: 'See you at the office',
        time: 'Yesterday',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          final c = conversations[index];
          return ListTile(
            leading: CircleAvatar(
              child: Text(c.name[0]),
            ),
            title: Text(c.name),
            subtitle: Text(c.lastMessage),
            trailing: Text(
              c.time,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onTap: () => context.push('/chat/${c.id}'),
          );
        },
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
  });
  final String id;
  final String name;
  final String lastMessage;
  final String time;
}
