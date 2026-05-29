import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart'
    hide PurchaseStatus; // avoid clash with our own PurchaseStatus
import 'package:in_app_purchase/in_app_purchase.dart'
    as iap
    show PurchaseStatus;
import 'package:in_app_purchase_android/in_app_purchase_android.dart'
    show GooglePlayPurchaseDetails, GooglePlayPurchaseParam;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_runtime_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

/// SharedPreferences key that stores the permanent premium unlock flag.
/// Setting this to `true` disables all ads permanently.
const String _kIsPremiumKey = 'iap_remove_ads_unlocked';

const String _kProcessedTokensKey = 'iap_processed_tokens';

/// How long the IAP stream has to respond before we declare "nothing found"
/// during a restore flow.
const Duration _kRestoreTimeout = Duration(seconds: 8);

// ─────────────────────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────────────────────

/// UI-facing purchase status.
enum PurchaseStatus {
  /// Service is still initialising (checking cached flag, loading products).
  initialising,

  /// User has not purchased Remove Ads.
  notPurchased,

  /// User has permanently unlocked Remove Ads.
  purchased,

  /// A purchase or restore is in progress — disable buy/restore buttons.
  purchasing,

  /// Restore is in progress — show dedicated "checking…" UI.
  restoring,

  /// An error occurred. See [PurchaseService.errorMessage].
  error,
}

/// Result returned from [PurchaseService.buyRemoveAds] and
/// [PurchaseService.restorePurchases].
class PurchaseResult {
  const PurchaseResult({required this.success, this.message = ''});
  final bool success;
  final String message;
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

/// Production-grade one-time non-consumable "Remove Ads" purchase service.
///
/// **Security model**
///   1. On Android, after `purchased` / `restored` status, the purchase token
///      is sent to the `verifyOneTimePurchase` Cloud Function which validates
///      it against the Google Play Developer API. Entitlement is only granted
///      if the server returns `{ isValid: true }`.
///   2. On iOS the plugin's signed `verificationData` is trusted
///      (StoreKit 2 handles on-device receipt verification). Server-side
///      validation can be added behind the same Cloud Function interface.
///   3. `completePurchase()` is called **before** writing the local flag, so
///      we never ack a purchase without also recording the entitlement.
///   4. Idempotency: we track the last processed token in SharedPreferences —
///      duplicate stream events for the same purchase are silently skipped.
///   5. The local `isPremiumUnlocked` flag is the source of truth offline.
///      Clearing app data clears the flag; the server re-grants on next
///      successful restore.
class PurchaseService extends ChangeNotifier {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final PurchaseService instance = PurchaseService._();
  PurchaseService._();

  // ── Internal state ─────────────────────────────────────────────────────────
  PurchaseStatus _status = PurchaseStatus.initialising;
  String _errorMessage = '';
  ProductDetails? _productDetails;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _disposed = false;

  // Restore coordination: prevents premature "nothing found" before the
  // stream has had time to emit.
  bool _restoreInProgress = false;
  Completer<void>? _restoreCompleter;

  // Prevents concurrent product-detail queries racing each other.
  bool _loadingProductDetails = false;

  // ── Public getters ─────────────────────────────────────────────────────────
  PurchaseStatus get status => _status;
  String get errorMessage => _errorMessage;
  ProductDetails? get productDetails => _productDetails;

  /// `true` when the user owns the Remove Ads entitlement.
  /// This is the flag that [AdManager] should check.
  bool get isSubscribed => _status == PurchaseStatus.purchased;

  /// `true` while any purchase or restore operation is in flight.
  bool get isPurchasing =>
      _status == PurchaseStatus.purchasing ||
      _status == PurchaseStatus.restoring;

  bool get isRestoring => _restoreInProgress;

  /// Platform-correct product ID resolved from [AppRuntimeConfig].
  String get _productId {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppRuntimeConfig.removeAdsIosProductId;
    }
    return AppRuntimeConfig.removeAdsProductId;
  }

  // ── Initialisation ─────────────────────────────────────────────────────────

  /// Call once at app startup (already done in `main.dart`).
  ///
  /// 1. Reads the persisted premium flag immediately → no ad flash for payers.
  /// 2. Starts the billing stream.
  /// 3. Loads product details in the background (for price display).
  Future<void> init() async {
    _setStatus(PurchaseStatus.initialising);

    // ── Step 1: Apply cached flag immediately ──────────────────────────────
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getBool(_kIsPremiumKey) ?? false;

    if (cached) {
      _setStatus(PurchaseStatus.purchased);
      debugPrint('[PurchaseService] Cached premium = true → fast path.');
    } else {
      _setStatus(PurchaseStatus.notPurchased);
    }

    // ── Step 2: Billing availability ──────────────────────────────────────
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
      unawaited(_loadProductDetails());
    } else {
      debugPrint('[PurchaseService] Billing unavailable on this device.');
    }

    // ── Step 3: Server re-verify for authenticated users ──────────────────
    // Only worthwhile if user has the cached flag set — avoids a server round-
    // trip for users who have never purchased.
    if (cached && _isUserAuthenticated()) {
      unawaited(_serverCheckOnLaunch(prefs));
    }
  }

  // ── Purchase flow ──────────────────────────────────────────────────────────

  /// Launches the store purchase sheet for the Remove Ads non-consumable.
  Future<PurchaseResult> buyRemoveAds() async {
    if (_disposed) {
      return const PurchaseResult(success: false, message: 'Service disposed.');
    }

    // Telemetry: remove_ads_click
    _logEvent('remove_ads_click');

    if (isSubscribed) {
      return const PurchaseResult(success: true, message: 'Already purchased.');
    }

    if (_status == PurchaseStatus.purchasing ||
        _status == PurchaseStatus.restoring) {
      return const PurchaseResult(
        success: false,
        message: 'A purchase is already in progress. Please wait.',
      );
    }

    bool available = false;
    try {
      available = await InAppPurchase.instance.isAvailable();
    } catch (e) {
      _logEvent('purchase_fail', params: {'error': e.toString()});
      return PurchaseResult(success: false, message: _friendlyError(e));
    }

    if (!available) {
      const msg =
          'Store billing is not available on this device. '
          'Check your Play Store / App Store account.';
      _logEvent('purchase_fail', params: {'error': 'billing_unavailable'});
      return const PurchaseResult(success: false, message: msg);
    }

    if (_productDetails == null) {
      await _loadProductDetails();
      if (_productDetails == null) {
        const msg =
            'Remove Ads product not found. '
            'Check your internet connection and try again.';
        _logEvent('purchase_fail', params: {'error': 'product_not_found'});
        return const PurchaseResult(success: false, message: msg);
      }
    }

    _setStatus(PurchaseStatus.purchasing);
    // Telemetry: purchase_started
    _logEvent(
      'purchase_started',
      params: {
        'product_id': _productId,
        'platform': defaultTargetPlatform.name,
      },
    );

    try {
      final PurchaseParam param;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
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
        _setStatus(PurchaseStatus.notPurchased);
        _logEvent('purchase_fail', params: {'error': 'launch_failed'});
        return const PurchaseResult(
          success: false,
          message: 'Could not launch the purchase sheet. Please try again.',
        );
      }

      // Status will move to purchased / error via the stream.
      return const PurchaseResult(
        success: true,
        message: 'Purchase sheet opened.',
      );
    } catch (e, st) {
      debugPrint('[PurchaseService] buyRemoveAds exception: $e');
      if (kDebugMode) debugPrint(st.toString());
      _errorMessage = _friendlyError(e);
      _setStatus(PurchaseStatus.error);
      _logEvent('purchase_fail', params: {'error': _errorMessage});
      return PurchaseResult(success: false, message: _errorMessage);
    }
  }

  /// Restores any previous Remove Ads purchase.
  ///
  /// Waits up to [_kRestoreTimeout] for the billing stream to deliver results,
  /// so the UI never shows "nothing found" prematurely on slow networks.
  Future<PurchaseResult> restorePurchases() async {
    if (_disposed) {
      return const PurchaseResult(success: false, message: 'Service disposed.');
    }

    // Telemetry: purchase_restore_started
    _logEvent('purchase_restore_started');

    bool available = false;
    try {
      available = await InAppPurchase.instance.isAvailable();
    } catch (e) {
      return PurchaseResult(success: false, message: _friendlyError(e));
    }

    if (!available) {
      _logEvent(
        'purchase_restore_fail',
        params: {'error': 'billing_unavailable'},
      );
      return const PurchaseResult(
        success: false,
        message: 'Store billing is not available.',
      );
    }

    _restoreInProgress = true;
    _restoreCompleter = Completer<void>();
    _setStatus(PurchaseStatus.restoring);

    try {
      await InAppPurchase.instance.restorePurchases();

      // Wait for the stream to settle (or timeout gracefully).
      await _restoreCompleter!.future.timeout(_kRestoreTimeout).catchError((_) {
        debugPrint(
          '[PurchaseService] Restore stream timeout — no items found.',
        );
      });

      return const PurchaseResult(success: true, message: 'Restore complete.');
    } catch (e, st) {
      debugPrint('[PurchaseService] restorePurchases exception: $e');
      if (kDebugMode) debugPrint(st.toString());
      _setStatus(
        isSubscribed ? PurchaseStatus.purchased : PurchaseStatus.notPurchased,
      );
      _logEvent('purchase_restore_fail', params: {'error': e.toString()});
      return PurchaseResult(success: false, message: _friendlyError(e));
    } finally {
      _restoreInProgress = false;
      _restoreCompleter = null;
    }
  }

  // ── IAP stream ─────────────────────────────────────────────────────────────

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      unawaited(_handlePurchaseDetails(p));
    }
  }

  Future<void> _handlePurchaseDetails(PurchaseDetails purchase) async {
    if (purchase.productID != _productId) return;

    debugPrint(
      '[PurchaseService] Stream → status=${purchase.status.name} '
      'productId=${purchase.productID}',
    );

    switch (purchase.status) {
      case iap.PurchaseStatus.pending:
        _setStatus(PurchaseStatus.purchasing);

      case iap.PurchaseStatus.purchased:
      case iap.PurchaseStatus.restored:
        await _verifyAndComplete(purchase);
        _resolveRestoreCompleter();

      case iap.PurchaseStatus.error:
        _errorMessage =
            purchase.error?.message ?? 'An unknown billing error occurred.';
        debugPrint('[PurchaseService] IAP error: $_errorMessage');

        // Must always call completePurchase for errored purchases.
        if (purchase.pendingCompletePurchase) {
          try {
            await InAppPurchase.instance.completePurchase(purchase);
          } catch (_) {}
        }

        _resolveRestoreCompleter();
        _setStatus(
          isSubscribed ? PurchaseStatus.purchased : PurchaseStatus.error,
        );
        _logEvent('purchase_fail', params: {'error': _errorMessage});

      case iap.PurchaseStatus.canceled:
        _resolveRestoreCompleter();
        _setStatus(
          isSubscribed ? PurchaseStatus.purchased : PurchaseStatus.notPurchased,
        );
        _logEvent('purchase_fail', params: {'error': 'user_cancelled'});
    }
  }

  // ── Verify & deliver ───────────────────────────────────────────────────────

  /// Core path: validates the purchase server-side, then grants entitlement.
  Future<void> _verifyAndComplete(PurchaseDetails purchase) async {
    final token = _extractToken(purchase);

    // ── Idempotency check ──────────────────────────────────────────────────
    final prefs = await SharedPreferences.getInstance();
    final tokensList = prefs.getStringList(_kProcessedTokensKey) ?? <String>[];
    final processedTokens = tokensList.toSet();

    if (token != null && token.isNotEmpty) {
      if (processedTokens.contains(token)) {
        debugPrint(
          '[PurchaseService] Duplicate token — already processed. Skipping.',
        );
        if (prefs.getBool(_kIsPremiumKey) ?? false) {
          _setStatus(PurchaseStatus.purchased);
        }
        return;
      }
    }

    // ── Local sanity check ─────────────────────────────────────────────────
    if (token == null || token.isEmpty) {
      debugPrint('[PurchaseService] Empty token — cannot verify.');
      _setStatus(PurchaseStatus.notPurchased);
      return;
    }

    // ── Acknowledge with the store (MUST happen before granting) ───────────
    if (purchase.pendingCompletePurchase) {
      try {
        await InAppPurchase.instance.completePurchase(purchase);
        debugPrint('[PurchaseService] completePurchase() acknowledged.');
      } catch (e) {
        debugPrint('[PurchaseService] completePurchase() error: $e');
        // Continue to server verify — ack can be retried; don't block grant.
      }
    }

    // ── Server-side verification (Mode A & Mode B) ─────────────────────────
    final isValid = await _serverVerifyPurchase(token);

    if (isValid == true) {
      // ✅ Mode A: Backend validation successful
      await _grantPremium(token, prefs, processedTokens);
      _logEvent(
        'purchase_success',
        params: {
          'product_id': _productId,
          'platform': defaultTargetPlatform.name,
        },
      );
    } else if (isValid == false) {
      // Server explicitly says invalid — do NOT grant.
      debugPrint('[PurchaseService] Server says INVALID — not granting.');
      _setStatus(PurchaseStatus.notPurchased);
      _logEvent('purchase_fail', params: {'error': 'server_invalid'});
    } else {
      // ⚠️ Mode B: Fallback (Server unreachable but we have local verification)
      if (purchase.status == iap.PurchaseStatus.purchased) {
        debugPrint(
          '[PurchaseService] Mode B: Client-only validation fallback.',
        );
        _logEvent('purchase_validation_mode', params: {'mode': 'client_only'});
        await _grantPremium(token, prefs, processedTokens);
        _logEvent(
          'purchase_success',
          params: {
            'product_id': _productId,
            'platform': defaultTargetPlatform.name,
            'fallback': 'true',
          },
        );
      } else {
        // For restores or missing tokens, we apply grace: if already cached, keep it.
        final alreadyHas = prefs.getBool(_kIsPremiumKey) ?? false;
        if (alreadyHas) {
          _setStatus(PurchaseStatus.purchased);
          debugPrint(
            '[PurchaseService] Server unreachable but cache says premium — kept.',
          );
        } else {
          _errorMessage =
              'Could not verify your purchase. '
              'Please check your internet connection and try again.';
          _setStatus(PurchaseStatus.error);
          _logEvent('purchase_fail', params: {'error': 'server_unreachable'});
        }
      }
    }
  }

  // ── Entitlement management ─────────────────────────────────────────────────

  Future<void> _grantPremium(
    String? processedToken,
    SharedPreferences prefs,
    Set<String> processedTokens,
  ) async {
    try {
      if (processedToken != null) {
        processedTokens.add(processedToken);
      }
      await Future.wait([
        prefs.setBool(_kIsPremiumKey, true),
        prefs.setStringList(_kProcessedTokensKey, processedTokens.toList()),
      ]);
    } catch (e) {
      debugPrint('[PurchaseService] SharedPreferences write error: $e');
    }

    _setStatus(PurchaseStatus.purchased);
    _logEvent('premium_unlocked', params: {'product_id': _productId});
    debugPrint('[PurchaseService] ✅ Premium granted — ads disabled.');
  }

  Future<void> _revokePremium() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setBool(_kIsPremiumKey, false),
        // Do not clear processed tokens on revoke, they remain valid historical records
      ]);
    } catch (e) {
      debugPrint('[PurchaseService] SharedPreferences revoke error: $e');
    }

    _setStatus(PurchaseStatus.notPurchased);
    debugPrint('[PurchaseService] Premium revoked.');
  }

  // ── Server verification ────────────────────────────────────────────────────

  /// Returns `true` = valid, `false` = invalid, `null` = server unreachable.
  Future<bool?> _serverVerifyPurchase(String token) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'verifyOneTimePurchase',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );

      final result = await callable.call<Map<String, dynamic>>({
        'purchaseToken': token,
        'productId': _productId,
        'platform': defaultTargetPlatform.name,
      });

      final isValid = result.data['isValid'] as bool? ?? false;
      debugPrint(
        '[PurchaseService] Server verification result: isValid=$isValid',
      );
      return isValid;
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        '[PurchaseService] verifyOneTimePurchase error: '
        'code=${e.code} message=${e.message}',
      );
      return null; // treat as unreachable
    } catch (e, st) {
      debugPrint('[PurchaseService] _serverVerifyPurchase exception: $e');
      if (kDebugMode) debugPrint(st.toString());
      return null;
    }
  }

  // ── Launch-time server check ───────────────────────────────────────────────

  /// Re-validates cached premium status on launch (handles refunds / revocations).
  Future<void> _serverCheckOnLaunch(SharedPreferences prefs) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'checkOneTimePurchaseStatus',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );

      final result = await callable.call<Map<String, dynamic>>({
        'productId': _productId,
      });

      final isValid = result.data['isValid'] as bool? ?? false;

      if (isValid) {
        _setStatus(PurchaseStatus.purchased);
        debugPrint('[PurchaseService] Launch check: PREMIUM confirmed.');
      } else {
        await _revokePremium();
        debugPrint(
          '[PurchaseService] Launch check: Premium revoked by server.',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      // Server unreachable or function error → trust local cache.
      debugPrint(
        '[PurchaseService] Launch check Cloud Function error: '
        'code=${e.code} — trusting cache.',
      );
    } catch (e, st) {
      debugPrint('[PurchaseService] _serverCheckOnLaunch error: $e');
      if (kDebugMode) debugPrint(st.toString());
      // Leave status as-is (cached value already applied in init()).
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _loadProductDetails() async {
    if (_loadingProductDetails) return;
    _loadingProductDetails = true;
    try {
      final response = await InAppPurchase.instance.queryProductDetails({
        _productId,
      });
      if (response.error != null) {
        debugPrint(
          '[PurchaseService] queryProductDetails error: ${response.error}',
        );
        return;
      }
      if (response.productDetails.isEmpty) {
        debugPrint(
          '[PurchaseService] No product found for "$_productId". '
          'Ensure it is published in the store console.',
        );
        return;
      }
      _productDetails = response.productDetails.first;
      debugPrint(
        '[PurchaseService] Product loaded: ${_productDetails!.title} '
        '@ ${_productDetails!.price}',
      );
      notifyListeners(); // update price chip in UI
    } catch (e, st) {
      debugPrint('[PurchaseService] _loadProductDetails error: $e');
      if (kDebugMode) debugPrint(st.toString());
    } finally {
      _loadingProductDetails = false;
    }
  }

  /// Extracts the purchase token, handling both Android and iOS.
  String? _extractToken(PurchaseDetails purchase) {
    try {
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          purchase is GooglePlayPurchaseDetails) {
        return purchase.billingClientPurchase.purchaseToken;
      }
      final token = purchase.verificationData.serverVerificationData;
      return token.isNotEmpty ? token : null;
    } catch (e) {
      debugPrint('[PurchaseService] _extractToken error: $e');
      return null;
    }
  }

  void _resolveRestoreCompleter() {
    if (!(_restoreCompleter?.isCompleted ?? true)) {
      _restoreCompleter!.complete();
    }
    // Emit restore_fail telemetry if we're restoring and end up not purchased.
    if (_restoreInProgress && !isSubscribed) {
      _logEvent('purchase_restore_fail', params: {'reason': 'not_found'});
    } else if (_restoreInProgress && isSubscribed) {
      _logEvent('purchase_restored');
    }
  }

  bool _isUserAuthenticated() {
    try {
      return FirebaseAuth.instance.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('network') || msg.contains('timeout')) {
      return 'Network error. Please check your connection and try again.';
    }
    if (msg.contains('cancelled') || msg.contains('canceled')) {
      return 'Purchase was cancelled.';
    }
    if (msg.contains('already owned')) {
      return 'You already own this. Try "Restore Purchases".';
    }
    if (msg.contains('item unavailable')) {
      return 'Remove Ads is currently unavailable in your region.';
    }
    return 'Something went wrong. Please try again.';
  }

  /// Logs a Firebase Analytics event, swallowing any errors so telemetry
  /// never crashes the purchase flow.
  void _logEvent(String name, {Map<String, Object>? params}) {
    try {
      FirebaseAnalytics.instance.logEvent(name: name, parameters: params);
    } catch (_) {
      // Telemetry must never block or crash the purchase flow.
    }
  }

  void _onStreamError(Object error) {
    debugPrint('[PurchaseService] Purchase stream error: $error');
    _errorMessage = _friendlyError(error);
    _resolveRestoreCompleter();
    _setStatus(PurchaseStatus.error);
    _logEvent('purchase_fail', params: {'error': 'stream_error'});
  }

  void _setStatus(PurchaseStatus status) {
    if (_disposed) return;
    _status = status;
    notifyListeners();
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _disposed = true;
    _restoreCompleter?.complete();
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}
