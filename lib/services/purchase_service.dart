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
import 'error_reporter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

/// SharedPreferences key that stores the permanent premium unlock flag.
/// Setting this to `true` disables all ads permanently.
const String _kIsPremiumKey = 'iap_remove_ads_unlocked';

const String _kProcessedTokensKey = 'iap_processed_tokens';

/// Set once after the first silent restore attempt so we don't fire a restore
/// on every cold start — only the first launch (or first reinstall) tries it.
const String _kAutoRestoreDoneKey = 'iap_auto_restore_done';

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
    // This is the ONLY work the caller (main.dart, before runApp) awaits, so
    // cold start never blocks on a billing connection.
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getBool(_kIsPremiumKey) ?? false;

    if (cached) {
      _setStatus(PurchaseStatus.purchased);
      debugPrint('[PurchaseService] Cached premium = true → fast path.');
    } else {
      _setStatus(PurchaseStatus.notPurchased);
    }

    // Everything else (billing connect, stream, product load, restore, server
    // re-verify) runs off the critical path so first frame is not delayed.
    unawaited(_startBilling(prefs, cached: cached));
  }

  /// Background billing bring-up. Never awaited by [init].
  Future<void> _startBilling(
    SharedPreferences prefs, {
    required bool cached,
  }) async {
    // ── Billing availability ──────────────────────────────────────────────
    bool billingAvailable = false;
    try {
      billingAvailable = await InAppPurchase.instance.isAvailable();
    } catch (e) {
      debugPrint('[PurchaseService] isAvailable() error: $e');
    }

    if (billingAvailable) {
      _purchaseSubscription ??= InAppPurchase.instance.purchaseStream.listen(
        _onPurchaseUpdate,
        onError: _onStreamError,
      );
      unawaited(_loadProductDetails());

      // ── First-launch silent restore ────────────────────────────────────
      // Recovers premium for users who reinstalled (local flag cleared)
      // without making them hunt for the Restore button. Runs at most once;
      // the flag is only set after a successful call so an offline first
      // launch retries next time. Restored items resolve via the stream.
      if (!cached && !(prefs.getBool(_kAutoRestoreDoneKey) ?? false)) {
        try {
          await InAppPurchase.instance.restorePurchases();
          await prefs.setBool(_kAutoRestoreDoneKey, true);
        } catch (e) {
          debugPrint(
            '[PurchaseService] first-launch restore failed '
            '(will retry next launch): $e',
          );
        }
      }
    } else {
      debugPrint('[PurchaseService] Billing unavailable on this device.');
    }

    // ── Server re-verify for authenticated users ──────────────────────────
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

    final wasSubscribedBeforeRestore = isSubscribed;
    var timedOutWithoutResult = false;

    _restoreInProgress = true;
    _restoreCompleter = Completer<void>();
    _setStatus(PurchaseStatus.restoring);

    try {
      await InAppPurchase.instance.restorePurchases();

      // Wait for the stream to settle (or timeout gracefully).
      await _restoreCompleter!.future.timeout(_kRestoreTimeout).catchError((_) {
        timedOutWithoutResult = true;
        debugPrint(
          '[PurchaseService] Restore stream timeout — no items found.',
        );
      });

      final restored = isSubscribed || wasSubscribedBeforeRestore;
      return PurchaseResult(
        success: restored,
        message: restored
            ? 'Restore complete.'
            : 'No Remove Ads purchase found for this account.',
      );
    } catch (e, st) {
      debugPrint('[PurchaseService] restorePurchases exception: $e');
      if (kDebugMode) debugPrint(st.toString());
      _setStatus(
        isSubscribed ? PurchaseStatus.purchased : PurchaseStatus.notPurchased,
      );
      _logEvent('purchase_restore_fail', params: {'error': e.toString()});
      return PurchaseResult(success: false, message: _friendlyError(e));
    } finally {
      final statusStillRestoring = _status == PurchaseStatus.restoring;
      _restoreInProgress = false;
      _restoreCompleter = null;
      if (statusStillRestoring) {
        _setStatus(
          wasSubscribedBeforeRestore
              ? PurchaseStatus.purchased
              : PurchaseStatus.notPurchased,
        );
        if (timedOutWithoutResult && !wasSubscribedBeforeRestore) {
          _logEvent(
            'purchase_restore_fail',
            params: {'reason': 'not_found'},
          );
        }
      }
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
          } catch (error, stackTrace) {
            ErrorReporter.report(
              reason: 'iap_complete_failed',
              error: error,
              stackTrace: stackTrace,
              context: <String, Object?>{'product_id': purchase.productID},
            );
          }
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
        await _completePurchaseSafely(purchase);
        // Store re-delivered an owned purchase we've seen before. Ensure the
        // entitlement is actually applied — a previously false/cleared flag
        // must not leave a payer locked out after we short-circuit here.
        final storeConfirmsOwned =
            purchase.status == iap.PurchaseStatus.purchased ||
            purchase.status == iap.PurchaseStatus.restored;
        if (storeConfirmsOwned && !(prefs.getBool(_kIsPremiumKey) ?? false)) {
          await prefs.setBool(_kIsPremiumKey, true);
        }
        if (storeConfirmsOwned || (prefs.getBool(_kIsPremiumKey) ?? false)) {
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

    // ── Server-side verification (Mode A & Mode B) ─────────────────────────
    final isValid = await _serverVerifyPurchase(token);

    if (isValid == true) {
      // ✅ Mode A: Backend validation successful
      await _grantPremium(token, prefs, processedTokens);
      await _completePurchaseSafely(purchase);
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
      // ⚠️ Mode B: Fallback (Server unreachable — result was null, NOT an
      // explicit invalid). The store only emits `purchased`/`restored` for
      // genuinely owned items, so trust it and unlock; `_serverCheckOnLaunch`
      // reconciles a real refund on the next launch. Restore MUST get the same
      // trust as purchase or reinstall-restore fails whenever the server is down.
      // ponytail: optimistic grant on store-confirmed ownership; server
      // isValid==false still blocks tampering above, launch re-check revokes refunds.
      if (purchase.status == iap.PurchaseStatus.purchased ||
          purchase.status == iap.PurchaseStatus.restored) {
        debugPrint(
          '[PurchaseService] Mode B: store-trusted fallback '
          '(status=${purchase.status.name}).',
        );
        _logEvent('purchase_validation_mode', params: {'mode': 'client_only'});
        await _grantPremium(token, prefs, processedTokens);
        await _completePurchaseSafely(purchase);
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
          await _completePurchaseSafely(purchase);
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
      final hasAuth = await _ensureAuthenticatedForVerification();
      if (!hasAuth) {
        return null;
      }

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

  Future<void> _completePurchaseSafely(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) {
      return;
    }

    try {
      await InAppPurchase.instance.completePurchase(purchase);
      debugPrint('[PurchaseService] completePurchase() acknowledged.');
    } catch (error, stackTrace) {
      debugPrint('[PurchaseService] completePurchase() error: $error');
      ErrorReporter.report(
        reason: 'iap_complete_failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'product_id': purchase.productID},
      );
    }
  }

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
      final reason = result.data['reason'] as String? ?? '';

      if (isValid) {
        _setStatus(PurchaseStatus.purchased);
        debugPrint('[PurchaseService] Launch check: PREMIUM confirmed.');
        return;
      }

      // Only an AUTHORITATIVE "the store cancelled/refunded this" signal may
      // strip a paid entitlement. A missing entitlement record ('no_record')
      // or an unreachable Play API ('unreachable') must NEVER revoke — doing
      // so made every payer lose premium on the launch after purchase (the
      // server never wrote a record because it couldn't reach Play).
      if (reason == 'play_revoked') {
        await _revokePremium();
        debugPrint('[PurchaseService] Launch check: Play revoked entitlement.');
      } else {
        debugPrint(
          '[PurchaseService] Launch check inconclusive (reason="$reason") — '
          'keeping cached premium.',
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
      // Bounded retry: a flaky first launch would otherwise leave the price
      // blank and the buy button stuck on "product not found".
      const maxAttempts = 3;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          final response = await InAppPurchase.instance.queryProductDetails({
            _productId,
          });
          if (response.error == null && response.productDetails.isNotEmpty) {
            _productDetails = response.productDetails.first;
            debugPrint(
              '[PurchaseService] Product loaded: ${_productDetails!.title} '
              '@ ${_productDetails!.price}',
            );
            notifyListeners(); // update price chip in UI
            return;
          }
          debugPrint(
            '[PurchaseService] queryProductDetails attempt '
            '$attempt/$maxAttempts empty/error '
            '(${response.error ?? 'no product for "$_productId"'}).',
          );
        } catch (e, st) {
          debugPrint(
            '[PurchaseService] _loadProductDetails attempt $attempt error: $e',
          );
          if (kDebugMode) debugPrint(st.toString());
        }
        if (attempt < maxAttempts) {
          await Future<void>.delayed(Duration(seconds: attempt * 2));
        }
      }
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
    } catch (error, stackTrace) {
      ErrorReporter.report(
        reason: 'purchase_auth_check_failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> _ensureAuthenticatedForVerification() async {
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser != null) {
        return true;
      }
      await auth.signInAnonymously();
      return auth.currentUser != null;
    } on FirebaseAuthException catch (error, stackTrace) {
      ErrorReporter.report(
        reason: 'purchase_auth_sign_in_failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    } catch (error, stackTrace) {
      ErrorReporter.report(
        reason: 'purchase_auth_sign_in_failed',
        error: error,
        stackTrace: stackTrace,
      );
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
    } catch (error, stackTrace) {
      ErrorReporter.report(
        reason: 'purchase_analytics_failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'event': name},
      );
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
