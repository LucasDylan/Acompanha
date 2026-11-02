import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../chat/providers/chat_provider.dart';
import '../../discovery/providers/discovery_provider.dart';
import '../../matches/providers/matches_provider.dart';
import '../data/safety_repository.dart';

final safetyRepositoryProvider = Provider<SafetyRepository>((ref) {
  return SafetyRepository(apiClient: ref.watch(apiClientProvider));
});

final blockedUsersProvider =
    FutureProvider.autoDispose<List<BlockedUser>>((ref) {
  return ref.read(safetyRepositoryProvider).getBlocked();
});

/// Reloads every list that could still show someone just blocked or
/// unblocked.
void refreshPeopleLists(WidgetRef ref) {
  ref.invalidate(discoveryFeedProvider);
  ref.invalidate(gymMembersProvider);
  ref.invalidate(incomingRequestsProvider);
  ref.invalidate(myMatchesProvider);
  ref.invalidate(sessionsProvider);
  ref.invalidate(conversationsProvider);
  ref.invalidate(unreadCountProvider);
  ref.invalidate(blockedUsersProvider);
}
