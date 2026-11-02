import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

/// Why someone is being reported. [slug] is what the API stores.
enum ReportReason {
  spam('spam', 'Spam ou golpe'),
  harassment('harassment', 'Assédio ou ofensa'),
  sexual('sexual', 'Conteúdo ou proposta sexual'),
  fake('fake', 'Perfil falso'),
  safety('safety', 'Me senti inseguro(a)'),
  other('other', 'Outro motivo');

  const ReportReason(this.slug, this.label);

  final String slug;
  final String label;
}

/// Someone the user blocked.
class BlockedUser {
  const BlockedUser({required this.userId, required this.name, this.avatarUrl});

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    final name = (json['display_name'] as String?)?.trim() ?? '';
    return BlockedUser(
      userId: json['user_id'].toString(),
      name: name.isEmpty ? 'Usuário' : name,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  final String userId;
  final String name;
  final String? avatarUrl;
}

class SafetyRepository {
  SafetyRepository({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  Object _id(String id) => int.tryParse(id) ?? id;

  Future<List<BlockedUser>> getBlocked() => guardApi(() async {
        final res = await _client.dio.get(ApiConstants.blocks);
        return (res.data as List)
            .map((e) => BlockedUser.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<void> block(String userId) => guardApi(() async {
        await _client.dio.post(ApiConstants.blocks, data: {'user_id': _id(userId)});
      });

  Future<void> unblock(String userId) => guardApi(() async {
        await _client.dio.delete(ApiConstants.block(userId));
      });

  Future<void> report({
    required String userId,
    required ReportReason reason,
    String? details,
    String? conversationId,
    bool block = false,
  }) =>
      guardApi(() async {
        await _client.dio.post(ApiConstants.reports, data: {
          'user_id': _id(userId),
          'reason': reason.slug,
          if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
          if (conversationId != null) 'conversation_id': _id(conversationId),
          'block': block,
        });
      });
}
