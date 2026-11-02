import 'dart:io';

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

/// The logged-in user, or null when logged out.
///
/// Sign-in methods don't put this into a loading state: the forms track their
/// own progress and get errors thrown back at them. That keeps the router
/// (which listens to this provider) from bouncing between screens mid-login.
final authStateProvider =
    AsyncNotifierProvider<AuthNotifier, UserModel?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<UserModel?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<UserModel?> build() async {
    ref.read(apiClientProvider).onSessionExpired = _onSessionExpired;
    return _repo.restoreSession();
  }

  void _onSessionExpired() {
    if (state.valueOrNull == null) return;
    _repo.clearTokens();
    state = const AsyncData(null);
  }

  /// Tries again after [build] failed (e.g. no connection at startup).
  void retry() => ref.invalidateSelf();

  Future<void> login(String email, String password) async {
    state = AsyncData(await _repo.login(email, password));
    ref.invalidate(savedAccountsProvider);
  }

  /// One-tap login for an account saved on this device — no password needed.
  Future<void> loginWithSavedAccount(SavedAccount account) async {
    try {
      state = AsyncData(await _repo.loginWithSavedAccount(account));
    } finally {
      ref.invalidate(savedAccountsProvider);
    }
  }

  Future<void> loginWithFacebook() async {
    final result = await FacebookAuth.instance.login(
      permissions: ['email', 'public_profile'],
      // Classic tracking gives a Graph API access token our backend can
      // verify via /debug_token — "limited" tokens are an OIDC JWT instead.
      loginTracking: LoginTracking.enabled,
    );
    if (result.status == LoginStatus.cancelled) return;
    if (result.status != LoginStatus.success || result.accessToken == null) {
      throw ApiException(
        message: result.message ?? 'Falha no login com Facebook.',
      );
    }
    state = AsyncData(
      await _repo.loginWithFacebook(result.accessToken!.tokenString),
    );
    ref.invalidate(savedAccountsProvider);
  }

  Future<void> register({
    required String email,
    required String password,
    required bool acceptTerms,
    String? displayName,
  }) async {
    state = AsyncData(
      await _repo.register(
        email: email,
        password: password,
        acceptTerms: acceptTerms,
        displayName: displayName,
      ),
    );
    ref.invalidate(savedAccountsProvider);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }

  Future<void> deleteAccount() async {
    final user = state.valueOrNull;
    if (user == null) return;
    await _repo.deleteAccount(user.email);
    state = const AsyncData(null);
    ref.invalidate(savedAccountsProvider);
  }

  Future<void> updateProfile(Map<String, dynamic> fields) async {
    state = AsyncData(await _repo.updateProfile(fields));
  }

  Future<void> uploadAvatar(File file) async {
    state = AsyncData(await _repo.uploadAvatar(file));
  }

  /// Re-reads the user from the API — call after changing something the rest
  /// of the app reads off [UserModel], such as the gym. Keeps the current
  /// user if the request fails.
  Future<void> refresh() async {
    try {
      state = AsyncData(await _repo.fetchMe());
    } catch (_) {}
  }
}
