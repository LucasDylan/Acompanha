import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/conversation_model.dart';

class ChatRepository {
  ChatRepository({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  Future<List<ConversationModel>> getConversations() => guardApi(() async {
        final res = await _client.dio.get(ApiConstants.conversations);
        return (res.data as List)
            .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  /// Opens (or reopens) the conversation with [userId]. The API only allows
  /// it between people with a booking together or an accepted partnership.
  Future<ConversationModel> openWith(String userId) => guardApi(() async {
        final res = await _client.dio.post(
          ApiConstants.conversations,
          data: {'user_id': int.tryParse(userId) ?? userId},
        );
        return ConversationModel.fromJson(res.data as Map<String, dynamic>);
      });

  Future<ConversationModel> getConversation(String id) => guardApi(() async {
        final res = await _client.dio.get(ApiConstants.conversation(id));
        return ConversationModel.fromJson(res.data as Map<String, dynamic>);
      });

  /// Messages oldest-first. With [afterId], only the ones newer than it.
  Future<List<ChatMessage>> getMessages(String conversationId, {String? afterId}) =>
      guardApi(() async {
        final res = await _client.dio.get(
          ApiConstants.conversationMessages(conversationId),
          queryParameters: {if (afterId != null) 'after': afterId},
        );
        return (res.data as List)
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<ChatMessage> send(String conversationId, String text) =>
      guardApi(() async {
        final res = await _client.dio.post(
          ApiConstants.conversationMessages(conversationId),
          data: {'text': text},
        );
        return ChatMessage.fromJson(res.data as Map<String, dynamic>);
      });

  Future<int> unreadCount() => guardApi(() async {
        final res = await _client.dio.get(ApiConstants.unreadCount);
        return (res.data as Map)['unread'] as int? ?? 0;
      });
}
