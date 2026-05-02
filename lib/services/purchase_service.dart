import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart'
    hide PurchaseStatus; // avoid clash with SubscriptionStatus
import 'package:in_app_purchase/in_app_purchase.dart' as iap
    show PurchaseStatus;
import 'package:in_app_purchase_android/in_app_purchase_android.dart'
    show GooglePlayPurchaseDetails, GooglePlayPurchaseParam;
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

/// Subscription product ID — must match Google Play Console exactly.
const String kRemoveAdsProductId = 'remove_ads_monthly';

// SharedPreferences keys.
const String _kSubActiveKey = 'sub_remove_ads_active';
const String _kSubExpiryKey = 'sub_remove_ads_expiry_ms';
const String _kSubLastVerifiedKey = 'sub_remove_ads_last_verified_ms';
const String _kSubAutoRenewKey = 'sub_remove_ads_auto_renew';

/// Grace period: if the server is unreachable, trust the cached status for
/// this long after the last successful server verification.
const Duration _kGracePeriod = Duration(hours: 24);

/// How long to wait for the IAP stream to deliver a restore result before
/// declaring "no active subscription found".
const Duration _kRestoreStreamTimeout = Duration(seconds: 8);

// ─────────────────────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────────────────────

/// UI-facing subscription status.
enum SubscriptionStatus {
  initialising,
  notSubscribed,
  subscribed,
  purchasing,
  /// Restore is in progress — do NOT show "no subscription found" yet.
  restoring,
  error,
}

/// Result returned from buy / restore / verify operations.
class PurchaseResult {
  const PurchaseResult({required this.success, this.message = ''});
  final bool success;
  final String message;
}

/// Server verification response (matches Cloud Function return shape).
class _ServerVerification {
  const _ServerVerification({
    required this.isActive,
    required this.expiryTimeMillis,
    required this.autoRenewing,
    this.cached = false,
  });

  final bool isActive;
  final int expiryTimeMillis;
  final bool autoRenewing;
  final bool cached;
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

/// Production-grade subscription service with server-side verification.
///
/// **Security model:**
///   1. After every purchase / restore, the purchase token is sent to the
///      `verifySubscription` Cloud Function, which calls the Google Play
///      Developer API and only returns `isActive: true` if the payment is
///      confirmed.  The entitlement is NEVER granted from client-only data.
///   2. On every app launch, `checkSubscriptionStatus` is called to
///      re-verify the cached subscription status against Play.
///   3. If the server is unreachable, a time-limited grace period allows
///      the cached status to persist — but only if the last verification
///      was within [_kGracePeriod] AND the expiry date has not passed.
///   4. Clearing app data clears the cache; the next launch calls the
///      server which returns the Firestore-stored status — so the user
///      cannot unlock ads by clearing data unless they also bypass the
///      server check (which requires network).
///   5. Guest / unauthenticated users skip the server check entirely —
///      they never subscribed, so there is nothing to verify.
class PurchaseService extends ChangeNotifier {
  // ── Singleton ────────────────────────────────────────────────────────────
  static final PurchaseService instance = PurchaseService._();
  PurchaseService._();

  // ── State ────────────────────────────────────────────────────────────────
  SubscriptionStatus _status = SubscriptionStatus.initialising;
  String _errorMessage = '';
  ProductDetails? _productDetails;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _disposed = false;

  // Used to track an in-progress restore so the stream handler doesn't
  // show "no subscription found" before the stream has had time to respond.
  bool _restoreInProgress = false;
  Completer<void>? _restoreCompleter;

  // Used to prevent concurrent product-detail loads racing each other.
  bool _loadingProductDetails = false;

  // Cached expiry & verification timestamps.
  int _expiryTimeMillis = 0;
  int _lastVerifiedMillis = 0;
  bool _autoRenewing = false;

  // ── Public getters ───────────────────────────────────────────────────────
  SubscriptionStatus get status => _status;
  String get errorMessage => _errorMessage;
  ProductDetails? get productDetails => _productDetails;
  bool get isSubscribed => _status == SubscriptionStatus.subscribed;
  bool get isPurchasing =>
      _status == SubscriptionStatus.purchasing ||
      _status == SubscriptionStatus.restoring;
  bool get isRestoring => _restoreInProgress;
  int get expiryTimeMillis => _expiryTimeMillis;
  bool get autoRenewing => _autoRenewing;

  /// Human-readable expiry date for UI display.
  DateTime? get expiryDate => _expiryTimeMillis > 0
      ? DateTime.fromMillisecondsSinceEpoch(_expiryTimeMillis)
      : null;

  // ── Initialisation ───────────────────────────────────────────────────────

  /// Call once at app start.
  ///
  /// 1. Loads cached status instantly (no flicker for paying users).
  /// 2. Starts the IAP purchase stream.
  /// 3. Calls the server to re-verify (handles expiry / refunds / data clears).
  Future<void> init() async {
    _setStatus(SubscriptionStatus.initialising);

    // ── Step 1: Apply cached status immediately ──────────────────────────
    final prefs = await SharedPreferences.getInstance();
    _loadCachedState(prefs);

    if (_isCacheValid()) {
      _setStatus(SubscriptionStatus.subscribed);
      debugPrint('[PurchaseService] Cache valid — subscribed (fast path).');
    } else {
      _setStatus(SubscriptionStatus.notSubscribed);
    }

    // ── Step 2: Start billing stream ─────────────────────────────────────
    bool billingAvailable = false;
    try {
      billingAvailable = await InAppPurchase.instance.isAvailable();
    } catch (e) {
      debugPrint('[PurchaseService] isAvailable() error: $e');
    }

    if (billingAvailable) {
      _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
        _onPurchaseUpdate,
        onError: _onStreamError,
      );
      // Load product details in background — don't block init.
      unawaited(_loadProductDetails());
    } else {
      debugPrint('[PurchaseService] Billing unavailable on this device.');
    }

    // ── Step 3: Server-side re-verification ──────────────────────────────
    // Skip for guests — they have no Firestore subscription record.
    if (_isUserAuthenticated()) {
      await _serverCheckOnLaunch(prefs);
    } else {
      debugPrint('[PurchaseService] Guest user — skipping server check.');
    }
  }

  // ── Purchase flow ─────────────────────────────────────────────────────────

  /// Starts the Google Play purchase sheet.
  Future<PurchaseResult> buyRemoveAds() async {
    if (_disposed) {
      return const PurchaseResult(success: false, message: 'Service disposed.');
    }

    if (isSubscribed) {
      return const PurchaseResult(
        success: true,
        message: 'Already subscribed.',
      );
    }

    bool available = false;
    try {
      available = await InAppPurchase.instance.isAvailable();
    } catch (e) {
      return PurchaseResult(success: false, message: e.toString());
    }

    if (!available) {
      return const PurchaseResult(
        success: false,
        message:
            'Google Play Billing is not available on this device. '
            'Please check your Play Store account.',
      );
    }

    // Ensure product details are loaded before buying.
    if (_productDetails == null) {
      await _loadProductDetails();
      if (_productDetails == null) {
        return const PurchaseResult(
          success: false,
          message:
              'Subscription product not found. '
              'Check your internet connection and try again.',
        );
      }
    }

    if (_status == SubscriptionStatus.purchasing ||
        _status == SubscriptionStatus.restoring) {
      return const PurchaseResult(
        success: false,
        message: 'A purchase is already in progress. Please wait.',
      );
    }

    _setStatus(SubscriptionStatus.purchasing);

    try {
      final PurchaseParam param;
      if (defaultTargetPlatform == TargetPlatform.android) {
        param = GooglePlayPurchaseParam(
          productDetails: _productDetails!,
          changeSubscriptionParam: null,
        );
      } else {
        param = PurchaseParam(productDetails: _productDetails!);
      }

      final launched = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: param,
      );

      if (!launched) {
        _setStatus(SubscriptionStatus.notSubscribed);
        return const PurchaseResult(
          success: false,
          message: 'Could not launch the purchase sheet. Please try again.',
        );
      }

      // Status will move to subscribed/error via the stream — return pending.
      return const PurchaseResult(
        success: true,
        message: 'Purchase sheet opened.',
      );
    } catch (e, st) {
      debugPrint('[PurchaseService] buyRemoveAds exception: $e');
      if (kDebugMode) debugPrint(st.toString());
      _errorMessage = _friendlyError(e);
      _setStatus(SubscriptionStatus.error);
      return PurchaseResult(success: false, message: _errorMessage);
    }
  }

  /// Restores purchases from the current Google account.
  ///
  /// Returns after the IAP stream has had [_kRestoreStreamTimeout] to deliver
  /// results — so the UI never shows "nothing found" prematurely on slow networks.
  Future<PurchaseResult> restorePurchases() async {
    if (_disposed) {
      return const PurchaseResult(success: false, message: 'Service disposed.');
    }

    bool available = false;
    try {
      available = await InAppPurchase.instance.isAvailable();
    } catch (e) {
      return PurchaseResult(success: false, message: e.toString());
    }

    if (!available) {
      return const PurchaseResult(
        success: false,
        message: 'Google Play Billing is not available.',
      );
    }

    _restoreInProgress = true;
    _restoreCompleter = Completer<void>();
    _setStatus(SubscriptionStatus.restoring);

    try {
      await InAppPurchase.instance.restorePurchases();

      // Wait for the stream to resolve (up to timeout).
      await _restoreCompleter!.future
          .timeout(_kRestoreStreamTimeout)
          .catchError((_) {
            // Timeout is fine — stream just didn't fire within the window.
            debugPrint('[PurchaseService] Restore stream timeout — no items.');
          });

      return const PurchaseResult(success: true, message: 'Restore complete.');
    } catch (e, st) {
      debugPrint('[PurchaseService] restorePurchases exception: $e');
      if (kDebugMode) debugPrint(st.toString());
      _setStatus(
        isSubscribed
            ? SubscriptionStatus.subscribed
            : SubscriptionStatus.notSubscribed,
      );
      return PurchaseResult(
        success: false,
        message: _friendlyError(e),
      );
    } finally {
      _restoreInProgress = false;
      _restoreCompleter = null;
    }
  }

  // ── IAP stream handler ────────────────────────────────────────────────────

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      unawaited(_handlePurchaseDetails(p));
    }
  }

  Future<void> _handlePurchaseDetails(PurchaseDetails purchase) async {
    if (purchase.productID != kRemoveAdsProductId) return;

    debugPrint(
      '[PurchaseService] Stream update: status=${purchase.status} '
      'productId=${purchase.productID}',
    );

    switch (purchase.status) {
      case iap.PurchaseStatus.pending:
        _setStatus(SubscriptionStatus.purchasing);

      case iap.PurchaseStatus.purchased:
      case iap.PurchaseStatus.restored:
        await _completePurchase(purchase);
        // Signal restore completer if waiting.
        if (!(_restoreCompleter?.isCompleted ?? true)) {
          _restoreCompleter!.complete();
        }

      case iap.PurchaseStatus.error:
        _errorMessage =
            purchase.error?.message ?? 'An unknown billing error occurred.';
        debugPrint('[PurchaseService] IAP error: $_errorMessage');
        if (purchase.pendingCompletePurchase) {
          try {
            await InAppPurchase.instance.completePurchase(purchase);
          } catch (_) {}
        }
        // Signal restore completer on error too.
        if (!(_restoreCompleter?.isCompleted ?? true)) {
          _restoreCompleter!.complete();
        }
        _setStatus(
          isSubscribed
              ? SubscriptionStatus.subscribed
              : SubscriptionStatus.error,
        );

      case iap.PurchaseStatus.canceled:
        // Signal restore completer — user cancelled.
        if (!(_restoreCompleter?.isCompleted ?? true)) {
          _restoreCompleter!.complete();
        }
        _setStatus(
          isSubscribed
              ? SubscriptionStatus.subscribed
              : SubscriptionStatus.notSubscribed,
        );
    }
  }

  /// Core purchase completion path — validates server-side before granting.
  Future<void> _completePurchase(PurchaseDetails purchase) async {
    // ── Step 1: Basic local sanity check ──────────────────────────────────
    if (!_localSanityCheck(purchase)) {
      debugPrint('[PurchaseService] Local sanity check failed — bad token.');
      _setStatus(SubscriptionStatus.notSubscribed);
      return;
    }

    // ── Step 2: Acknowledge purchase (Google Play requirement) ────────────
    if (purchase.pendingCompletePurchase) {
      try {
        await InAppPurchase.instance.completePurchase(purchase);
        debugPrint('[PurchaseService] Purchase acknowledged with Play.');
      } catch (e) {
        debugPrint('[PurchaseService] completePurchase error: $e');
        // Continue to verify — acknowledgement can be retried later.
      }
    }

    // ── Step 3: Server-side verification (THE AUTHORITY) ─────────────────
    final token = _extractToken(purchase);
    if (token == null || token.isEmpty) {
      debugPrint('[PurchaseService] No token — cannot verify with server.');
      _setStatus(SubscriptionStatus.notSubscribed);
      return;
    }

    final verification = await _callVerifySubscription(token);

    if (verification != null && verification.isActive) {
      await _applyVerification(verification);
      debugPrint('[PurchaseService] Server verified — subscription GRANTED.');
    } else if (verification != null && !verification.isActive) {
      await _revokeSubscription();
      debugPrint('[PurchaseService] Server says NOT active — REVOKED.');
    } else {
      // Server unreachable — do NOT grant on a fresh purchase.
      _errorMessage =
          'Could not verify your purchase with our server. '
          'Check your internet connection and try again.';
      _setStatus(SubscriptionStatus.error);
      debugPrint('[PurchaseService] Server unreachable — NOT granting.');
    }
  }

  // ── Server-side verification ──────────────────────────────────────────────

  /// Calls the `verifySubscription` Cloud Function.
  Future<_ServerVerification?> _callVerifySubscription(String token) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'verifySubscription',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );

      final result = await callable.call<Map<String, dynamic>>({
        'purchaseToken': token,
        'productId': kRemoveAdsProductId,
      });

      final data = result.data;
      return _ServerVerification(
        isActive: data['isActive'] as bool? ?? false,
        expiryTimeMillis: (data['expiryTimeMillis'] as num?)?.toInt() ?? 0,
        autoRenewing: data['autoRenewing'] as bool? ?? false,
        cached: data['cached'] as bool? ?? false,
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        '[PurchaseService] verifySubscription Cloud Function error: '
        'code=${e.code} message=${e.message}',
      );
      return null;
    } catch (e, st) {
      debugPrint('[PurchaseService] verifySubscription exception: $e');
      if (kDebugMode) debugPrint(st.toString());
      return null;
    }
  }

  /// Calls the `checkSubscriptionStatus` Cloud Function (no token needed).
  Future<_ServerVerification?> _callCheckSubscriptionStatus() async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'checkSubscriptionStatus',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );

      final result = await callable.call<Map<String, dynamic>>();

      final data = result.data;
      return _ServerVerification(
        isActive: data['isActive'] as bool? ?? false,
        expiryTimeMillis: (data['expiryTimeMillis'] as num?)?.toInt() ?? 0,
        autoRenewing: data['autoRenewing'] as bool? ?? false,
        cached: data['cached'] as bool? ?? false,
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        '[PurchaseService] checkSubscriptionStatus Cloud Function error: '
        'code=${e.code} message=${e.message}',
      );
      return null;
    } catch (e, st) {
      debugPrint('[PurchaseService] checkSubscriptionStatus exception: $e');
      if (kDebugMode) debugPrint(st.toString());
      return null;
    }
  }

  // ── Launch-time server check ──────────────────────────────────────────────

  /// Called once at init — re-verifies subscription with the server.
  ///
  /// This catches:
  ///   - Expired subscriptions (expiry date passed)
  ///   - Refunds / cancellations processed server-side
  ///   - Users who cleared app data (server still has Firestore record)
  ///   - Renewals that extended the expiry
  Future<void> _serverCheckOnLaunch(SharedPreferences prefs) async {
    try {
      final verification = await _callCheckSubscriptionStatus();

      if (verification == null) {
        // Server unreachable — use grace period logic.
        _applyGracePeriod();
        return;
      }

      if (verification.isActive) {
        await _applyVerification(verification);
        debugPrint('[PurchaseService] Launch check: SUBSCRIBED.');
      } else {
        await _revokeSubscription();
        debugPrint('[PurchaseService] Launch check: NOT subscribed.');
      }
    } catch (e, st) {
      debugPrint('[PurchaseService] _serverCheckOnLaunch error: $e');
      if (kDebugMode) debugPrint(st.toString());
      _applyGracePeriod();
    }
  }

  // ── State management ──────────────────────────────────────────────────────

  Future<void> _applyVerification(_ServerVerification v) async {
    _expiryTimeMillis = v.expiryTimeMillis;
    _autoRenewing = v.autoRenewing;
    _lastVerifiedMillis = DateTime.now().millisecondsSinceEpoch;

    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setBool(_kSubActiveKey, true),
        prefs.setInt(_kSubExpiryKey, _expiryTimeMillis),
        prefs.setInt(_kSubLastVerifiedKey, _lastVerifiedMillis),
        prefs.setBool(_kSubAutoRenewKey, _autoRenewing),
      ]);
    } catch (e) {
      debugPrint('[PurchaseService] SharedPreferences write error: $e');
    }

    _setStatus(SubscriptionStatus.subscribed);
  }

  Future<void> _revokeSubscription() async {
    _expiryTimeMillis = 0;
    _autoRenewing = false;
    _lastVerifiedMillis = 0;

    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setBool(_kSubActiveKey, false),
        prefs.setInt(_kSubExpiryKey, 0),
        prefs.setInt(_kSubLastVerifiedKey, 0),
        prefs.setBool(_kSubAutoRenewKey, false),
      ]);
    } catch (e) {
      debugPrint('[PurchaseService] SharedPreferences revoke error: $e');
    }

    _setStatus(SubscriptionStatus.notSubscribed);
  }

  // ── Cache / Grace period ──────────────────────────────────────────────────

  void _loadCachedState(SharedPreferences prefs) {
    final active = prefs.getBool(_kSubActiveKey) ?? false;
    _expiryTimeMillis = prefs.getInt(_kSubExpiryKey) ?? 0;
    _lastVerifiedMillis = prefs.getInt(_kSubLastVerifiedKey) ?? 0;
    _autoRenewing = prefs.getBool(_kSubAutoRenewKey) ?? false;

    if (!active) {
      _expiryTimeMillis = 0;
      _lastVerifiedMillis = 0;
    }
  }

  /// Returns `true` if the cached subscription data is still trustworthy.
  ///
  /// Trust requires ALL of:
  ///   1. A last-verified timestamp exists (non-zero).
  ///   2. The last verification was within the grace period.
  ///   3. The subscription expiry date has not passed.
  bool _isCacheValid() {
    if (_lastVerifiedMillis == 0) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    final withinGrace =
        (now - _lastVerifiedMillis) < _kGracePeriod.inMilliseconds;
    final notExpired = _expiryTimeMillis > now;

    return withinGrace && notExpired;
  }

  /// When the server is unreachable, decide whether to trust the cache.
  void _applyGracePeriod() {
    if (_isCacheValid()) {
      debugPrint(
        '[PurchaseService] Server unreachable — grace period active. '
        'Trusting cached subscription.',
      );
      _setStatus(SubscriptionStatus.subscribed);
    } else {
      debugPrint(
        '[PurchaseService] Server unreachable — grace period expired. '
        'Treating as not subscribed.',
      );
      _setStatus(SubscriptionStatus.notSubscribed);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _loadProductDetails() async {
    if (_loadingProductDetails) return; // prevent concurrent loads
    _loadingProductDetails = true;
    try {
      final response = await InAppPurchase.instance.queryProductDetails(
        {kRemoveAdsProductId},
      );
      if (response.error != null) {
        debugPrint(
          '[PurchaseService] queryProductDetails error: ${response.error}',
        );
        return;
      }
      if (response.productDetails.isEmpty) {
        debugPrint(
          '[PurchaseService] No product found for "$kRemoveAdsProductId". '
          'Ensure the product is published in Google Play Console.',
        );
        return;
      }
      _productDetails = response.productDetails.first;
      debugPrint(
        '[PurchaseService] Product loaded: ${_productDetails!.title} '
        '@ ${_productDetails!.price}',
      );
      // Notify UI so price chip updates.
      notifyListeners();
    } catch (e, st) {
      debugPrint('[PurchaseService] _loadProductDetails error: $e');
      if (kDebugMode) debugPrint(st.toString());
    } finally {
      _loadingProductDetails = false;
    }
  }

  /// Safely extracts the purchase token from a [PurchaseDetails].
  String? _extractToken(PurchaseDetails purchase) {
    try {
      if (defaultTargetPlatform == TargetPlatform.android &&
          purchase is GooglePlayPurchaseDetails) {
        return purchase.billingClientPurchase.purchaseToken;
      }
      // iOS / other platforms use serverVerificationData.
      final token = purchase.verificationData.serverVerificationData;
      return token.isNotEmpty ? token : null;
    } catch (e) {
      debugPrint('[PurchaseService] _extractToken error: $e');
      return null;
    }
  }

  /// Quick client-side sanity check (NOT the authority — server is).
  bool _localSanityCheck(PurchaseDetails purchase) {
    if (purchase.productID != kRemoveAdsProductId) return false;
    final token = _extractToken(purchase);
    return token != null && token.isNotEmpty;
  }

  /// Returns true when a real Firebase Auth user (not guest/anonymous) is
  /// signed in. Used to decide whether the server check makes sense.
  bool _isUserAuthenticated() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      return user != null;
    } catch (_) {
      return false;
    }
  }

  /// Maps raw exceptions to short, user-friendly strings.
  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('network') || msg.contains('timeout')) {
      return 'Network error. Please check your connection and try again.';
    }
    if (msg.contains('cancelled') || msg.contains('canceled')) {
      return 'Purchase was cancelled.';
    }
    if (msg.contains('already owned')) {
      return 'You already own this subscription. Try "Restore Purchases".';
    }
    if (msg.contains('item unavailable')) {
      return 'This subscription is currently unavailable in your region.';
    }
    return 'Something went wrong. Please try again.';
  }

  void _onStreamError(Object error) {
    debugPrint('[PurchaseService] Purchase stream error: $error');
    _errorMessage = _friendlyError(error);
    // Signal restore completer on stream error.
    if (!(_restoreCompleter?.isCompleted ?? true)) {
      _restoreCompleter!.complete();
    }
    _setStatus(SubscriptionStatus.error);
  }

  void _setStatus(SubscriptionStatus status) {
    if (_disposed) return;
    _status = status;
    notifyListeners();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _disposed = true;
    _restoreCompleter?.complete(); // unblock any waiting caller
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}
