/// A device-local record of an account that has logged in before, so the
/// login screen can offer a one-tap "quick login" instead of retyping the
/// password. Deliberately holds a refresh token, never a password — see
/// [AuthRepository.loginWithSavedAccount] for why.
class SavedAccount {
  const SavedAccount({
    required this.email,
    required this.refreshToken,
    this.displayName,
    this.avatarUrl,
  });

  factory SavedAccount.fromJson(Map<String, dynamic> json) => SavedAccount(
        email: json['email'] as String,
        refreshToken: json['refresh_token'] as String,
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
      );

  final String email;
  final String refreshToken;
  final String? displayName;
  final String? avatarUrl;

  Map<String, dynamic> toJson() => {
        'email': email,
        'refresh_token': refreshToken,
        'display_name': displayName,
        'avatar_url': avatarUrl,
      };
}
