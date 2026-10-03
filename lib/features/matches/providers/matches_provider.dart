import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/matches_repository.dart';
import '../models/gym_member_model.dart';
import '../models/match_request_model.dart';

final matchesRepositoryProvider = Provider<MatchesRepository>((ref) {
  return MatchesRepository(apiClient: ref.watch(apiClientProvider));
});

final gymMembersProvider =
    FutureProvider.autoDispose<List<GymMemberModel>>((ref) {
  return ref.read(matchesRepositoryProvider).getGymMembers();
});

final incomingRequestsProvider =
    FutureProvider.autoDispose<List<MatchRequestModel>>((ref) {
  return ref.read(matchesRepositoryProvider).getIncoming();
});

final myMatchesProvider =
    FutureProvider.autoDispose<List<MatchRequestModel>>((ref) {
  return ref.read(matchesRepositoryProvider).getMyMatches();
});

final sessionsProvider =
    FutureProvider.autoDispose<List<TrainingSessionModel>>((ref) {
  return ref.read(matchesRepositoryProvider).getSessions();
});

/// Actions that mutate match state and refresh whatever the change affects.
class MatchActions {
  MatchActions(this._ref);

  final Ref _ref;

  void _refreshAll() {
    _ref.invalidate(gymMembersProvider);
    _ref.invalidate(incomingRequestsProvider);
    _ref.invalidate(myMatchesProvider);
  }

  /// Returns true when the request was immediately mutual (the other person had
  /// already asked to train with us).
  Future<bool> sendRequest(String userId) async {
    final result =
        await _ref.read(matchesRepositoryProvider).sendRequest(userId);
    _refreshAll();
    return result.status == MatchRequestStatus.accepted;
  }

  Future<void> respond({required String requestId, required bool accept}) async {
    await _ref
        .read(matchesRepositoryProvider)
        .respond(requestId: requestId, accept: accept);
    _refreshAll();
  }
}

final matchActionsProvider = Provider<MatchActions>(MatchActions.new);
