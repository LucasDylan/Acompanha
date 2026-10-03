import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/models/host_profile_model.dart';
import '../../../core/models/slot_model.dart';
import '../data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(apiClient: ref.watch(apiClientProvider));
});

final myProfileProvider =
    FutureProvider.autoDispose<HostProfileModel?>((ref) async {
  try {
    return await ref.read(profileRepositoryProvider).getMyProfile();
  } catch (_) {
    return null;
  }
});

final hostProfileProvider =
    FutureProvider.family.autoDispose<HostProfileModel, String>((ref, id) async {
  return ref.read(profileRepositoryProvider).getProfile(id);
});

final profileFormProvider =
    StateNotifierProvider<ProfileFormNotifier, ProfileFormState>((ref) {
  return ProfileFormNotifier(ref.read(profileRepositoryProvider));
});

class ProfileFormState {
  const ProfileFormState({
    this.isLoading = false,
    this.error,
  });
  final bool isLoading;
  final String? error;
}

class ProfileFormNotifier extends StateNotifier<ProfileFormState> {
  ProfileFormNotifier(this._repo) : super(const ProfileFormState());

  final ProfileRepository _repo;

  /// Creates or updates the user's host profile (backend upserts via /me/).
  Future<HostProfileModel?> saveMyProfile({
    required String displayName,
    String? bio,
    List<String>? categories,
    double? pricePerHour,
    String? location,
  }) async {
    state = const ProfileFormState(isLoading: true);
    try {
      final profile = await _repo.saveMyProfile(
        displayName: displayName,
        bio: bio,
        categories: categories,
        pricePerHour: pricePerHour,
        location: location,
      );
      state = const ProfileFormState();
      return profile;
    } catch (e) {
      state = ProfileFormState(error: e.toString());
      return null;
    }
  }

  Future<String?> uploadPhoto(String profileId, File file) async {
    state = const ProfileFormState(isLoading: true);
    try {
      final url = await _repo.uploadPhoto(profileId, file);
      state = const ProfileFormState();
      return url;
    } catch (e) {
      state = ProfileFormState(error: e.toString());
      return null;
    }
  }
}

/// The authenticated host's own upcoming slots, keyed by their host profile id.
final mySlotsProvider =
    AsyncNotifierProvider.family<MySlotsNotifier, List<SlotModel>, String>(
  MySlotsNotifier.new,
);

class MySlotsNotifier extends FamilyAsyncNotifier<List<SlotModel>, String> {
  @override
  Future<List<SlotModel>> build(String hostId) {
    return ref.read(profileRepositoryProvider).getMySlots(hostId);
  }

  Future<void> createSlot({required DateTime startAt, required DateTime endAt}) async {
    final repo = ref.read(profileRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await repo.createSlot(hostId: arg, startAt: startAt, endAt: endAt);
      return repo.getMySlots(arg);
    });
  }

  Future<void> deleteSlot(String slotId) async {
    final repo = ref.read(profileRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await repo.deleteSlot(hostId: arg, slotId: slotId);
      return repo.getMySlots(arg);
    });
  }
}
