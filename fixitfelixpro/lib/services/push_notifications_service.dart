import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState;

import '../core/services/supabase_service.dart';
import '../globals.dart';
import 'invoice_notification_nav.dart';
import 'leads_notification_nav.dart';
import 'quote_notification_nav.dart';

/// Handles FCM permission, token storage and foreground / tap-to-open routing.
///
/// Firebase Cloud Messaging stays — it is the one Firebase product the app
/// keeps. Only the two things around it moved: tokens now live in the
/// `fcm_tokens` table instead of `/users/{uid}/fcmTokens/{tokenKey}`, and the
/// sign-in trigger comes from Supabase auth rather than Firebase auth.
///
/// Does NOT try to render foreground banners — the in-app bell badge does
/// that job through the `notifications` stream.
class PushNotificationsService {
  PushNotificationsService._();
  static final PushNotificationsService instance =
      PushNotificationsService._();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  bool _initialised = false;
  String? _currentToken;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<AuthState>? _authSub;

  Future<void> initialise() async {
    if (_initialised) return;
    _initialised = true;

    // iOS / Android 13+: request permission
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('FCM requestPermission failed: $e');
    }

    // Show banners + sound when app is foregrounded (iOS only behaviour)
    try {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}

    // Tap-to-open: app launched from a terminated-state push
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleTap(initial);

    // Tap-to-open: app already in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // Keep listening for token changes
    _refreshSub?.cancel();
    _refreshSub = _messaging.onTokenRefresh.listen(_persistToken);

    // React to sign-in / sign-out automatically. On every transition to
    // authenticated, persist the current token. We rely on explicit
    // `clearToken()` from AuthRepository.onBeforeSignOut for teardown,
    // because the user record is gone once auth fires null.
    _authSub?.cancel();
    _authSub = SupabaseService().auth.onAuthStateChange.listen((data) {
      // Supabase also emits a token refresh roughly hourly; re-persisting the
      // FCM token on each of those would be pointless write traffic.
      if (data.event == AuthChangeEvent.tokenRefreshed) return;
      if (data.session?.user != null) syncToken();
    });
  }

  /// Fetch the current token and persist it under the signed-in user.
  /// Call after sign-in + whenever auth state transitions to authenticated.
  Future<void> syncToken() async {
    final user = SupabaseService().auth.currentUser;
    if (user == null) return;
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await _persistToken(token);
    } catch (e) {
      debugPrint('FCM getToken failed: $e');
    }
  }

  /// Delete the current token's record from the signed-in user.
  /// Call on sign-out BEFORE the auth session is actually torn down.
  Future<void> clearToken() async {
    final user = SupabaseService().auth.currentUser;
    final token = _currentToken;
    if (user == null || token == null) return;
    try {
      // `(owner_id, token)` is the primary key, so the full token identifies
      // the row — no key mangling needed any more.
      await SupabaseService()
          .client
          .from('fcm_tokens')
          .delete()
          .eq('owner_id', user.id)
          .eq('token', token);
    } catch (e) {
      debugPrint('FCM clearToken failed: $e');
    }
    _currentToken = null;
  }

  Future<void> _persistToken(String token) async {
    final user = SupabaseService().auth.currentUser;
    if (user == null) return;
    _currentToken = token;
    try {
      // upsert on the composite key: re-registering the same token on the
      // same account just refreshes last_seen_at.
      await SupabaseService().client.from('fcm_tokens').upsert({
        'owner_id': user.id,
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'owner_id,token');
    } catch (e) {
      debugPrint('FCM persistToken failed: $e');
    }
  }

  void _handleTap(RemoteMessage message) {
    final type = message.data['type']?.toString();
    if (isQuoteNotificationType(type)) {
      // FCM data is all strings — pass the raw map through; the helper
      // only needs `quoteId`.
      openQuoteFromNotificationPayload(
        Map<String, dynamic>.from(message.data),
      );
      return;
    }
    if (isInvoiceNotificationType(type)) {
      openInvoiceFromNotificationPayload(
        Map<String, dynamic>.from(message.data),
      );
      return;
    }
    if (isLeadsNotificationType(type)) {
      openLeadsFromNotification();
      return;
    }
    // Default route — the data payload can override this later.
    final route =
        (message.data['route'] as String?) ?? '/notifications';
    globalNavigatorKey.currentState?.pushNamed(route);
  }

}

/// Must be a top-level function. Registered in `main.dart` BEFORE
/// `runApp`. Runs in its own isolate for background/terminated pushes.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Intentionally minimal — the OS will display the notification itself
  // when the payload includes a `notification` block. If we need to do
  // server-sync, call it here.
  debugPrint('Background push: ${message.messageId}');
}
