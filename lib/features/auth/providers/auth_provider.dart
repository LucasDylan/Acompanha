import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/models/user_model.dart';
import '../../../core/network/api_exception.dart';
import '../data/auth_repository.dart';
import '../data/saved_account.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    storage: ref.watch(secureStorageProvider),
  );
});

/// Accounts that have logged in before on this device, offered on the login
/// screen as a one-tap "quick login" (no password re-entry). Invalidate this
/// provider after any action that adds/removes a saved account.
final savedAccountsProvider =
    FutureProvider.autoDispose<List<SavedAccount>>((ref) {
  return ref.read(authRepositoryProvider).getSavedAccounts();
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
    ref.invalidate(savedAccountsProvider);
  }

  /// One-tap login for an account saved on this device — no password needed.
  Future<void> loginWithSavedAccount(SavedAccount account) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      return await repo.loginWithSavedAccount(account);
    });
    ref.invalidate(savedAccountsProvider);
  }

  Future<void> loginWithFacebook() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
        // Classic tracking gives a Graph API access token our backend can
        // verify via /debug_token — "limited" tokens are an OIDC JWT instead.
        loginTracking: LoginTracking.enabled,
      );
      if (result.status != LoginStatus.success || result.accessToken == null) {
        throw ApiException(
          message: result.message ?? 'Falha no login com Facebook',
        );
      }
      final repo = ref.read(authRepositoryProvider);
      return await repo.loginWithFacebook(result.accessToken!.tokenString);
    });
    ref.invalidate(savedAccountsProvider);
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

  /// Re-reads the user from the API — call after changing something the rest of
  /// the app reads off [UserModel], such as the gym.
  Future<void> refresh() async {
    final repo = ref.read(authRepositoryProvider);
    state = await AsyncValue.guard(() => repo.getCurrentUser());
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
