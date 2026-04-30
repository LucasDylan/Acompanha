import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/models/user_model.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    storage: ref.watch(secureStorageProvider),
  );
});

final authStateProvider =
    AsyncNotifierProvider<AuthNotifier, UserModel?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<UserModel?> {
  @override
  Future<UserModel?> build() async {
    final repo = ref.read(authRepositoryProvider);
    try {
      return await repo.getCurrentUser();
    } catch (_) {
      return null;
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      return await repo.login(email, password);
    });
  }

  Future<void> register({
    required String email,
    required String password,
    String? displayName,
    String role = 'client',
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      return await repo.register(
        email: email,
        password: password,
        displayName: displayName,
        role: role,
      );
    });
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    state = const AsyncData(null);
  }

  void setUser(UserModel? user) {
    state = AsyncData(user);
  }

  /// Demo login without backend - for MVP testing.
  Future<void> demoLogin() async {
    state = const AsyncLoading();
    await Future.delayed(const Duration(milliseconds: 500));
    state = AsyncData(
      UserModel(
        id: 'demo-1',
        email: 'demo@socialmeeting.app',
        displayName: 'Demo User',
        role: UserRole.client,
      ),
    );
  }
}
