/// The other person in a conversation.
class ChatPeer {
  const ChatPeer({required this.id, this.displayName, this.avatarUrl});

  factory ChatPeer.fromJson(Map<String, dynamic> json) => ChatPeer(
        id: json['id'].toString(),
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
      );

  final String id;
  final String? displayName;
  final String? avatarUrl;

  String get name =>
      (displayName?.trim().isNotEmpty ?? false) ? displayName! : 'Usuário';
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.sending = false,
    this.failed = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'].toString(),
        senderId: json['sender_id'].toString(),
        text: json['text'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );

  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;

  /// Optimistic message still on its way to the server.
  final bool sending;

  /// Optimistic message the server didn't accept; can be retried.
  final bool failed;

  ChatMessage copyWith({bool? sending, bool? failed}) => ChatMessage(
        id: id,
        senderId: senderId,
        text: text,
        createdAt: createdAt,
        sending: sending ?? this.sending,
        failed: failed ?? this.failed,
      );
}

class ConversationModel {
  const ConversationModel({
    required this.id,
    required this.otherUser,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final last = json['last_message'] as Map<String, dynamic>?;
    return ConversationModel(
      id: json['id'].toString(),
      otherUser: ChatPeer.fromJson(json['other_user'] as Map<String, dynamic>),
      lastMessage: last == null ? null : ChatMessage.fromJson(last),
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }

  final String id;
  final ChatPeer otherUser;
  final ChatMessage? lastMessage;
  final int unreadCount;
}
