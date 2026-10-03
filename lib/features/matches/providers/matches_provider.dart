import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/models/host_profile_model.dart';
import '../data/matches_repository.dart';
import '../models/match_request_model.dart';

final matchesRepositoryProvider = Provider<MatchesRepository>((ref) {
  return MatchesRepository(apiClient: ref.watch(apiClientProvider));
});

/// Workout-type quick filter for the "find a partner" list (null = all).
final partnerWorkoutFilterProvider =
    StateProvider.autoDispose<String?>((ref) => null);

/// User ids we already sent a request to in this session, so the card can flip
/// to "Enviado" immediately instead of waiting for a refetch.
final sentRequestIdsProvider =
    StateProvider.autoDispose<Set<String>>((ref) => <String>{});

final gymMembersProvider =
    FutureProvider.autoDispose<List<HostProfileModel>>((ref) async {
  final workout = ref.watch(partnerWorkoutFilterProvider);
  return ref
      .read(matchesRepositoryProvider)
      .getGymMembers(workoutType: workout);
});

final incomingRequestsProvider =
    FutureProvider.autoDispose<List<MatchRequestModel>>((ref) async {
  return ref.read(matchesRepositoryProvider).getIncoming();
});

final myMatchesProvider =
    FutureProvider.autoDispose<List<MatchRequestModel>>((ref) async {
  return ref.read(matchesRepositoryProvider).getMyMatches();
});

/// Actions that mutate match state and refresh whatever the change affects.
class MatchActions {
  MatchActions(this._ref);

  final Ref _ref;

  /// Returns true when the request was immediately mutual (the other person had
  /// already asked to train with us).
  Future<bool> sendRequest(String userId) async {
    final result =
        await _ref.read(matchesRepositoryProvider).sendRequest(userId);
    _ref.read(sentRequestIdsProvider.notifier).update((s) => {...s, userId});
    _ref.invalidate(incomingRequestsProvider);
    _ref.invalidate(myMatchesProvider);
    return result.status == MatchStatus.accepted;
  }

  Future<void> respond({required String requestId, required bool accept}) async {
    await _ref
        .read(matchesRepositoryProvider)
        .respond(requestId: requestId, accept: accept);
    _ref.invalidate(incomingRequestsProvider);
    _ref.invalidate(myMatchesProvider);
  }
}

final matchActionsProvider = Provider<MatchActions>(MatchActions.new);
