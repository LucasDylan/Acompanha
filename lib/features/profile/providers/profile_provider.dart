import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/models/host_profile_model.dart';
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

  Future<HostProfileModel?> createHostProfile({
    required String displayName,
    String? bio,
    List<String>? categories,
    double? pricePerHour,
    String? location,
  }) async {
    state = const ProfileFormState(isLoading: true);
    try {
      final profile = await _repo.createHostProfile(
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
