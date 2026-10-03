import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/models/host_profile_model.dart';
import '../../../core/models/slot_model.dart';
import '../data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(apiClient: ref.watch(apiClientProvider));
});

/// The user's own host listing; null when they don't have one yet.
final myProfileProvider = FutureProvider.autoDispose<HostProfileModel?>((ref) {
  return ref.read(profileRepositoryProvider).getMyProfile();
});

final hostProfileProvider =
    FutureProvider.family.autoDispose<HostProfileModel, String>((ref, id) {
  return ref.read(profileRepositoryProvider).getProfile(id);
});

/// The authenticated host's own upcoming slots, keyed by their host profile id.
final mySlotsProvider = AsyncNotifierProvider.autoDispose
    .family<MySlotsNotifier, List<SlotModel>, String>(MySlotsNotifier.new);

class MySlotsNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<SlotModel>, String> {
  ProfileRepository get _repo => ref.read(profileRepositoryProvider);

  @override
  Future<List<SlotModel>> build(String hostId) => _repo.getMySlots(hostId);

  /// Throws the API's reason if the slot is rejected (overlap, in the past...)
  /// and leaves the list as it was.
  Future<void> createSlot({required DateTime startAt, required DateTime endAt}) async {
    await _repo.createSlot(hostId: arg, startAt: startAt, endAt: endAt);
    state = AsyncData(await _repo.getMySlots(arg));
  }

  Future<void> deleteSlot(String slotId) async {
    await _repo.deleteSlot(hostId: arg, slotId: slotId);
    state = AsyncData(await _repo.getMySlots(arg));
  }
}
