import 'package:supabase_flutter/supabase_flutter.dart' show User;

/// The app's own authenticated-user type.
///
/// Replaces Firebase's `User` across the app. Firebase's type leaked into the
/// bloc layer and three screens; owning this type keeps the auth provider an
/// implementation detail of the repository, so the UI never has to change
/// again if the provider does.
///
/// Deliberately data-only: actions that used to hang off Firebase's `User`
/// (`reload()`, `sendEmailVerification()`, `updateDisplayName()`, `delete()`,
/// `getIdToken()`) live on the repository instead, which is where Supabase
/// exposes them.
class AppUser {
  const AppUser({
    required this.uid,
    this.email,
    this.emailVerified = false,
    this.displayName,
    this.photoUrl,
    this.providerIds = const [],
    this.createdAt,
  });

  /// Supabase `auth.users.id`. Named `uid` to match the 134 existing call
  /// sites that read `user.uid`, so the port does not churn unrelated code.
  final String uid;
  final String? email;
  final bool emailVerified;
  final String? displayName;
  final String? photoUrl;

  /// Sign-in providers linked to this account, e.g. `['email']`,
  /// `['google']`, `['apple']`. Replaces Firebase's `providerData`, which
  /// onboarding reads to decide whether to ask for a password.
  final List<String> providerIds;

  final DateTime? createdAt;

  /// Maps a Supabase user onto this type.
  ///
  /// `displayName` and `photoUrl` are read from `userMetadata`, which is where
  /// both Supabase's own OAuth flow and our native Google/Apple sign-in put
  /// them — under several possible keys depending on provider.
  factory AppUser.fromSupabase(User user) {
    final meta = user.userMetadata ?? const <String, dynamic>{};

    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = meta[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return null;
    }

    // Providers can arrive as appMetadata['providers'] (list),
    // appMetadata['provider'] (single), or via linked identities.
    final providers = <String>{};
    final appMeta = user.appMetadata;
    final rawList = appMeta['providers'];
    if (rawList is List) {
      providers.addAll(rawList.whereType<String>());
    }
    final rawSingle = appMeta['provider'];
    if (rawSingle is String && rawSingle.isNotEmpty) providers.add(rawSingle);
    for (final identity in user.identities ?? const []) {
      final p = identity.provider;
      if (p.isNotEmpty) providers.add(p);
    }

    return AppUser(
      uid: user.id,
      email: user.email,
      // Supabase marks an address confirmed via emailConfirmedAt.
      emailVerified: user.emailConfirmedAt != null,
      displayName: pick(['full_name', 'name', 'display_name']),
      photoUrl: pick(['avatar_url', 'picture', 'profile_image']),
      providerIds: providers.toList(),
      createdAt: DateTime.tryParse(user.createdAt),
    );
  }

  AppUser copyWith({
    String? uid,
    String? email,
    bool? emailVerified,
    String? displayName,
    String? photoUrl,
    List<String>? providerIds,
    DateTime? createdAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      providerIds: providerIds ?? this.providerIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// True when the account can sign in with a password. Onboarding uses this
  /// to decide whether to show password-change UI — an OAuth-only account has
  /// no password to change.
  bool get isPasswordUser => providerIds.contains('email');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          other.uid == uid &&
          other.email == email &&
          other.emailVerified == emailVerified &&
          other.displayName == displayName &&
          other.photoUrl == photoUrl;

  @override
  int get hashCode =>
      Object.hash(uid, email, emailVerified, displayName, photoUrl);

  @override
  String toString() =>
      'AppUser(uid: $uid, email: $email, verified: $emailVerified, '
      'providers: $providerIds)';
}
