import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/config/config_service.dart';
import '../core/services/supabase_service.dart';

/// Outcome of a subscription purchase attempt.
class IapResult {
  const IapResult({
    required this.success,
    this.cancelled = false,
    this.errorMessage,
  });

  /// Entitlement was purchased AND verified server-side.
  final bool success;

  /// User dismissed the native purchase sheet on purpose (silent path).
  final bool cancelled;

  /// User-facing failure reason when [success] is false and not [cancelled].
  final String? errorMessage;
}

/// Apple In-App Purchase (StoreKit) subscription flow. Replaces the old
/// Stripe payment sheet.
///
/// The store handles the payment UI; the resulting transaction is sent to
/// our Cloud Function (`/iap/apple/validate`) which verifies it with
/// Apple's App Store Server API and writes the entitlement to
/// `users/{uid}/subscription/member`. The app never grants access off the
/// raw client receipt — server validation is the gate.
///
/// Android (Play Billing) reuses the same plugin but a different backend
/// validator; that path is not wired yet (iOS-first migration) and returns
/// a clear error rather than silently bypassing the paywall.
class IapService {
  IapService._();
  static final IapService _instance = IapService._();
  factory IapService() => _instance;

  // Product IDs — must match the store catalog EXACTLY. iOS uses the
  // App Store Connect ids; Android uses shorter ids because Google Play
  // caps subscription product ids at 40 chars (the `com.techkushx.`
  // prefix would overflow). See docs/inapp-purchase-migration.md.
  static String get standardMonthly => Platform.isAndroid
      ? 'fixitfelixpro.standard.monthly'
      : 'com.techkushx.fixitfelixpro.standard.monthly';
  static String get standardYearly => Platform.isAndroid
      ? 'fixitfelixpro.standard.yearly'
      : 'com.techkushx.fixitfelixpro.standard.yearly';
  static Set<String> get _productIds => {standardMonthly, standardYearly};

  /// Resolve a product id from the paywall's monthly/yearly toggle.
  static String productIdFor({required bool yearly}) =>
      yearly ? standardYearly : standardMonthly;

  /// Platform-appropriate "manage subscriptions" deep link. Both stores
  /// own cancellation — apps may not cancel on the user's behalf.
  static String manageSubscriptionsUrl() => Platform.isAndroid
      ? 'https://play.google.com/store/account/subscriptions'
      : 'https://apps.apple.com/account/subscriptions';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Resolves when the in-flight [buy] finishes. Only one purchase runs at
  /// a time (the paywall is modal), so a single completer is enough.
  Completer<IapResult>? _pending;

  bool _available = false;
  bool get isAvailable => _available;

  /// Wire up the global purchase stream. Call once at startup. Past /
  /// interrupted transactions are delivered here on launch — we verify and
  /// finish them so StoreKit stops re-delivering, which also restores
  /// entitlement after a reinstall.
  Future<void> initialize() async {
    try {
      _available = await _iap.isAvailable();
    } catch (e) {
      _available = false;
      debugPrint('IAP availability check failed: $e');
    }
    _sub ??= _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object e) => debugPrint('IAP purchaseStream error: $e'),
    );
  }

  /// Fetch store products (for showing localized prices). Empty when the
  /// store is unavailable or the products aren't configured / approved yet.
  Future<List<ProductDetails>> products() async {
    if (!_available) return const [];
    try {
      final resp = await _iap.queryProductDetails(_productIds);
      return resp.productDetails;
    } catch (e) {
      debugPrint('IAP queryProductDetails failed: $e');
      return const [];
    }
  }

  /// Start a subscription purchase and wait for the verified outcome.
  /// Works on iOS (StoreKit) and Android (Play Billing) — validation is
  /// routed to the matching backend endpoint.
  Future<IapResult> buy(String productId) async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return const IapResult(
        success: false,
        errorMessage: 'In-app subscriptions aren\'t supported on this platform.',
      );
    }
    if (!_available) {
      return const IapResult(
        success: false,
        errorMessage: 'In-app purchases are not available on this device.',
      );
    }
    if (_pending != null && !_pending!.isCompleted) {
      return const IapResult(
        success: false,
        errorMessage: 'A purchase is already in progress.',
      );
    }

    final ProductDetails product;
    try {
      final resp = await _iap.queryProductDetails({productId});
      if (resp.productDetails.isEmpty) {
        return const IapResult(
          success: false,
          errorMessage:
              'This subscription isn\'t available right now. Please try '
              'again shortly.',
        );
      }
      product = resp.productDetails.first;
    } catch (e) {
      debugPrint('IAP product lookup failed: $e');
      return const IapResult(
        success: false,
        errorMessage: 'Could not load the subscription. Please try again.',
      );
    }

    final completer = Completer<IapResult>();
    _pending = completer;
    try {
      // Tag the purchase with our Firebase uid so the store echoes it
      // back (Apple appAccountToken / Play obfuscatedAccountId) — a
      // secondary way for store notifications to find the user.
      final uid = SupabaseService().auth.currentUser?.id;
      // Auto-renewable subscriptions go through buyNonConsumable on both
      // platforms.
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(
          productDetails: product,
          applicationUserName: uid,
        ),
      );
    } catch (e) {
      _pending = null;
      debugPrint('IAP buyNonConsumable failed: $e');
      return const IapResult(
        success: false,
        errorMessage: 'Could not start the purchase. Please try again.',
      );
    }

    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () => const IapResult(
        success: false,
        errorMessage:
            'The purchase timed out. If you were charged it will be '
            'restored automatically.',
      ),
    );
  }

  /// Re-deliver past purchases (the "Restore purchases" button). Restored
  /// transactions flow through [_onPurchaseUpdates] and re-validate.
  Future<void> restore() async {
    if (!_available) return;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('IAP restore failed: $e');
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          // Waiting on the user / Ask to Buy approval. Nothing to do.
          break;

        case PurchaseStatus.canceled:
          await _finish(p);
          _complete(const IapResult(success: false, cancelled: true));
          break;

        case PurchaseStatus.error:
          await _finish(p);
          _complete(
            IapResult(
              success: false,
              errorMessage: p.error?.message ?? 'The purchase failed.',
            ),
          );
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final verified = await _validate(p);
          // Always finish the transaction, even if verification failed —
          // otherwise StoreKit re-delivers it on every launch. A failed
          // verification simply leaves the entitlement ungranted; the user
          // can retry / restore.
          await _finish(p);
          _complete(
            verified
                ? const IapResult(success: true)
                : const IapResult(
                    success: false,
                    errorMessage:
                        'We couldn\'t verify your purchase. If you were '
                        'charged, it will appear shortly — try Restore.',
                  ),
          );
          break;
      }
    }
  }

  Future<void> _finish(PurchaseDetails p) async {
    if (p.pendingCompletePurchase) {
      try {
        await _iap.completePurchase(p);
      } catch (e) {
        debugPrint('IAP completePurchase failed: $e');
      }
    }
  }

  /// Resolve the in-flight [buy], if any. Restored purchases delivered
  /// outside a buy() (e.g. on launch) have no pending completer — that's
  /// fine, they still got validated above.
  void _complete(IapResult result) {
    final c = _pending;
    if (c != null && !c.isCompleted) c.complete(result);
    _pending = null;
  }

  /// Send the transaction to the backend for store-side verification.
  /// iOS → App Store Server API; Android → Google Play Developer API.
  /// Returns true only on a 200 (entitlement written).
  Future<bool> _validate(PurchaseDetails p) async {
    try {
      // Was a Firebase ID token; the validation endpoint now verifies a
      // Supabase JWT (Phase 5 ports the endpoint itself).
      final token = SupabaseService().auth.currentSession?.accessToken;
      final base = ConfigService().stripeBackendUrl; // general backend base
      if (token == null || base.isEmpty) {
        debugPrint('IAP validate skipped: no token / backend url');
        return false;
      }

      final Uri url;
      final Map<String, dynamic> body;
      if (Platform.isAndroid) {
        url = Uri.parse('$base/iap/google/validate');
        body = {
          // On Android the server verification data IS the purchase
          // token; the server re-queries Google Play with it.
          'purchaseToken': p.verificationData.serverVerificationData,
          'productId': p.productID,
        };
      } else {
        // purchaseID can come back null from the plugin; the JWS payload
        // always carries the transaction id, so fall back to that.
        final transactionId = p.purchaseID ?? _transactionIdFromJws(p);
        if (transactionId == null) {
          debugPrint(
            'IAP validate skipped: no transaction id (status ${p.status})',
          );
          return false;
        }
        url = Uri.parse('$base/iap/apple/validate');
        body = {
          // The server re-fetches the authoritative transaction from
          // Apple with this id — the JWS itself is never trusted.
          'transactionId': transactionId,
          'productId': p.productID,
          'serverVerificationData': p.verificationData.serverVerificationData,
        };
      }

      final res = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (res.statusCode != 200) {
        debugPrint('IAP validate failed: ${res.statusCode} ${res.body}');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('IAP validate error: $e');
      return false;
    }
  }

  /// Extract the StoreKit 2 transaction id from the JWS the store attached
  /// to the purchase (header.payload.signature). Used only when the plugin
  /// didn't surface a purchaseID — the id still gets verified server-side
  /// against Apple, so decoding without signature checks is safe here.
  String? _transactionIdFromJws(PurchaseDetails p) {
    try {
      final parts = p.verificationData.serverVerificationData.split('.');
      if (parts.length != 3) return null;
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
              as Map<String, dynamic>;
      final id = payload['transactionId'];
      return (id is String && id.isNotEmpty) ? id : null;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
