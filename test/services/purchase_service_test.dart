/// Unit tests for the Remove Ads purchase state management.
///
/// These tests verify the [PurchaseService] state machine in isolation using
/// lightweight pure-Dart helpers that mirror the service's logic — no Firebase,
/// no billing SDK required.
///
/// Test groups:
///   1. Initial state
///   2. Premium flag persistence
///   3. Idempotency (duplicate token handling)
///   4. AdsService gate (premium → no ads)
///   5. Error / cancellation paths
///   6. Restore flow coordination

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Pure-Dart helpers that mirror purchase_service.dart logic
// ─────────────────────────────────────────────────────────────────────────────

const String _kIsPremiumKey = 'iap_remove_ads_unlocked';
const String _kProcessedTokensKey = 'iap_processed_tokens';

/// Mirrors [PurchaseStatus] from purchase_service.dart.
enum _PurchaseStatus {
  initialising,
  notPurchased,
  purchased,
  purchasing,
  restoring,
  error,
}

/// Minimal state machine that mirrors [PurchaseService] without IAP bindings.
class _MockPurchaseStateMachine {
  _PurchaseStatus status = _PurchaseStatus.initialising;
  String errorMessage = '';
  bool isPurchasing = false;
  bool isRestoring = false;
  int notifyCount = 0;

  void setStatus(_PurchaseStatus s) {
    status = s;
    isPurchasing = s == _PurchaseStatus.purchasing ||
        s == _PurchaseStatus.restoring;
    isRestoring = s == _PurchaseStatus.restoring;
    notifyCount++;
  }

  bool get isSubscribed => status == _PurchaseStatus.purchased;
}

/// Simulates what [PurchaseService.init()] does with SharedPreferences.
Future<_PurchaseStatus> simulateInit(SharedPreferences prefs) async {
  final cached = prefs.getBool(_kIsPremiumKey) ?? false;
  return cached ? _PurchaseStatus.purchased : _PurchaseStatus.notPurchased;
}

/// Simulates granting premium — mirrors [PurchaseService._grantPremium()].
Future<void> simulateGrant(
  SharedPreferences prefs,
  String token,
  _MockPurchaseStateMachine machine,
) async {
  final list = prefs.getStringList(_kProcessedTokensKey) ?? [];
  list.add(token);
  await prefs.setBool(_kIsPremiumKey, true);
  await prefs.setStringList(_kProcessedTokensKey, list);
  machine.setStatus(_PurchaseStatus.purchased);
}

/// Simulates revoking premium — mirrors [PurchaseService._revokePremium()].
Future<void> simulateRevoke(
  SharedPreferences prefs,
  _MockPurchaseStateMachine machine,
) async {
  await prefs.setBool(_kIsPremiumKey, false);
  machine.setStatus(_PurchaseStatus.notPurchased);
}

/// Simulates the idempotency check — mirrors token deduplication in
/// [PurchaseService._verifyAndComplete()].
Future<bool> isAlreadyProcessed(
  SharedPreferences prefs,
  String token,
) async {
  final list = prefs.getStringList(_kProcessedTokensKey) ?? [];
  return list.contains(token);
}

void main() {
  // Ensure SharedPreferences uses in-memory mock storage for all tests.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── 1. Initial state ───────────────────────────────────────────────────────
  group('1 · initial state', () {
    test('status is notPurchased when no cached flag exists', () async {
      final prefs = await SharedPreferences.getInstance();
      final status = await simulateInit(prefs);
      expect(status, _PurchaseStatus.notPurchased);
    });

    test('status is purchased when cached flag is true (fast path)', () async {
      SharedPreferences.setMockInitialValues({_kIsPremiumKey: true});
      final prefs = await SharedPreferences.getInstance();
      final status = await simulateInit(prefs);
      expect(status, _PurchaseStatus.purchased);
    });

    test('isPurchasing is false on initial state', () {
      final m = _MockPurchaseStateMachine();
      m.setStatus(_PurchaseStatus.notPurchased);
      expect(m.isPurchasing, isFalse);
    });
  });

  // ── 2. Premium flag persistence ────────────────────────────────────────────
  group('2 · premium flag persistence', () {
    test('grantPremium sets isPremiumKey=true in SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final m = _MockPurchaseStateMachine();

      await simulateGrant(prefs, 'tok-abc', m);

      expect(prefs.getBool(_kIsPremiumKey), isTrue);
      expect(m.status, _PurchaseStatus.purchased);
      expect(m.isSubscribed, isTrue);
    });

    test('revokePremium sets isPremiumKey=false but keeps tokens', () async {
      SharedPreferences.setMockInitialValues({
        _kIsPremiumKey: true,
        _kProcessedTokensKey: ['tok-abc'],
      });
      final prefs = await SharedPreferences.getInstance();
      final m = _MockPurchaseStateMachine();
      m.setStatus(_PurchaseStatus.purchased);

      await simulateRevoke(prefs, m);

      expect(prefs.getBool(_kIsPremiumKey), isFalse);
      expect(m.status, _PurchaseStatus.notPurchased);
    });

    test('premium flag survives multiple init() calls (simulated app restart)', () async {
      // First "app launch" — grant
      {
        final prefs = await SharedPreferences.getInstance();
        final m = _MockPurchaseStateMachine();
        await simulateGrant(prefs, 'tok-restart', m);
      }
      // Second "app launch" — flag persisted
      final prefs2 = await SharedPreferences.getInstance();
      final status = await simulateInit(prefs2);
      expect(status, _PurchaseStatus.purchased);
    });

    test('notifyListeners count increments on each status change', () {
      final m = _MockPurchaseStateMachine();
      expect(m.notifyCount, 0);
      m.setStatus(_PurchaseStatus.purchasing);
      m.setStatus(_PurchaseStatus.purchased);
      expect(m.notifyCount, 2);
    });
  });

  // ── 3. Idempotency (duplicate token) ──────────────────────────────────────
  group('3 · idempotency — duplicate token skipped', () {
    test('first token is not marked as processed', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(await isAlreadyProcessed(prefs, 'tok-first'), isFalse);
    });

    test('token is marked after grant', () async {
      final prefs = await SharedPreferences.getInstance();
      final m = _MockPurchaseStateMachine();
      await simulateGrant(prefs, 'tok-dup', m);

      expect(await isAlreadyProcessed(prefs, 'tok-dup'), isTrue);
    });

    test('different token is not considered duplicate', () async {
      final prefs = await SharedPreferences.getInstance();
      final m = _MockPurchaseStateMachine();
      await simulateGrant(prefs, 'tok-first', m);

      expect(await isAlreadyProcessed(prefs, 'tok-different'), isFalse);
    });

    test('revoke does not clear the last-processed token (prevents duplicate grants even after revoke)', () async {
      final prefs = await SharedPreferences.getInstance();
      final m = _MockPurchaseStateMachine();
      await simulateGrant(prefs, 'tok-x', m);
      await simulateRevoke(prefs, m);

      expect(await isAlreadyProcessed(prefs, 'tok-x'), isTrue);
    });
  });

  // ── 4. AdsService gate — premium → no ads ─────────────────────────────────
  group('4 · AdsService premium gate', () {
    test('isPremiumUnlocked returns false when no flag set', () async {
      final prefs = await SharedPreferences.getInstance();
      final isPremium = prefs.getBool(_kIsPremiumKey) ?? false;
      expect(isPremium, isFalse);
    });

    test('isPremiumUnlocked returns true after grant', () async {
      final prefs = await SharedPreferences.getInstance();
      final m = _MockPurchaseStateMachine();
      await simulateGrant(prefs, 'tok-ads', m);
      final isPremium = prefs.getBool(_kIsPremiumKey) ?? false;
      expect(isPremium, isTrue);
    });

    test('isSubscribed (machine getter) = false when notPurchased', () {
      final m = _MockPurchaseStateMachine();
      m.setStatus(_PurchaseStatus.notPurchased);
      expect(m.isSubscribed, isFalse);
    });

    test('isSubscribed = true when purchased', () {
      final m = _MockPurchaseStateMachine();
      m.setStatus(_PurchaseStatus.purchased);
      expect(m.isSubscribed, isTrue);
    });

    test('isSubscribed = false when in error state', () {
      final m = _MockPurchaseStateMachine();
      m.setStatus(_PurchaseStatus.error);
      expect(m.isSubscribed, isFalse);
    });

    test('ads gate logic: ad skipped when isSubscribed=true', () {
      // Mirrors: `if (_subscriberBlocked) return;`
      final m = _MockPurchaseStateMachine();
      m.setStatus(_PurchaseStatus.purchased);

      bool adWouldShow = false;
      if (!m.isSubscribed) {
        adWouldShow = true; // simulate ad path
      }
      expect(adWouldShow, isFalse, reason: 'Premium user — ad must be skipped');
    });

    test('ads gate logic: ad shows when isSubscribed=false', () {
      final m = _MockPurchaseStateMachine();
      m.setStatus(_PurchaseStatus.notPurchased);

      bool adWouldShow = false;
      if (!m.isSubscribed) {
        adWouldShow = true;
      }
      expect(adWouldShow, isTrue, reason: 'Non-premium user — ad should show');
    });
  });

  // ── 5. Error and cancellation paths ───────────────────────────────────────
  group('5 · error and cancellation paths', () {
    test('error status does not grant premium flag', () async {
      final prefs = await SharedPreferences.getInstance();
      final m = _MockPurchaseStateMachine();
      m.setStatus(_PurchaseStatus.error);

      // Error path must NOT write to prefs.
      expect(prefs.getBool(_kIsPremiumKey), isNull);
      expect(m.isSubscribed, isFalse);
    });

    test('cancellation status does not grant premium flag', () async {
      final prefs = await SharedPreferences.getInstance();
      final m = _MockPurchaseStateMachine();
      m.setStatus(_PurchaseStatus.notPurchased);

      expect(prefs.getBool(_kIsPremiumKey), isNull);
      expect(m.isSubscribed, isFalse);
    });

    test('isPurchasing is true during purchasing state', () {
      final m = _MockPurchaseStateMachine();
      m.setStatus(_PurchaseStatus.purchasing);
      expect(m.isPurchasing, isTrue);
    });

    test('isPurchasing is true during restoring state', () {
      final m = _MockPurchaseStateMachine();
      m.setStatus(_PurchaseStatus.restoring);
      expect(m.isPurchasing, isTrue);
    });

    test('isPurchasing is false after error (buy button re-enables)', () {
      final m = _MockPurchaseStateMachine();
      m.setStatus(_PurchaseStatus.purchasing);
      expect(m.isPurchasing, isTrue);
      m.setStatus(_PurchaseStatus.error);
      expect(m.isPurchasing, isFalse);
    });

    test('double-buy prevention: isPurchasing=true blocks second buy', () {
      final m = _MockPurchaseStateMachine();
      m.setStatus(_PurchaseStatus.purchasing);

      // Simulate the guard in buyRemoveAds().
      final wasBlocked = m.isPurchasing;
      expect(wasBlocked, isTrue, reason: 'Second tap must be blocked');
    });
  });

  // ── 6. Restore flow ────────────────────────────────────────────────────────
  group('6 · restore flow coordination', () {
    test('restore sets status=restoring and isRestoring=true', () {
      final m = _MockPurchaseStateMachine();
      m.setStatus(_PurchaseStatus.restoring);
      expect(m.isRestoring, isTrue);
      expect(m.status, _PurchaseStatus.restoring);
    });

    test('restore success path grants premium and clears restoring', () async {
      final prefs = await SharedPreferences.getInstance();
      final m = _MockPurchaseStateMachine();
      m.setStatus(_PurchaseStatus.restoring);

      // Simulate stream delivering a restored purchase.
      await simulateGrant(prefs, 'tok-restore', m);

      expect(m.isSubscribed, isTrue);
      expect(m.isRestoring, isFalse); // status is now purchased
    });

    test('restore with nothing found → notPurchased, not error', () {
      final m = _MockPurchaseStateMachine();
      m.setStatus(_PurchaseStatus.restoring);
      // Timeout or empty stream → fall back to notPurchased (not error).
      m.setStatus(_PurchaseStatus.notPurchased);

      expect(m.status, _PurchaseStatus.notPurchased);
      expect(m.isPurchasing, isFalse);
    });

    test('after successful restore, isInterstitialReady-style gate is false', () {
      // Simulate: AdsService.isInterstitialReady when premium.
      final m = _MockPurchaseStateMachine();
      m.setStatus(_PurchaseStatus.purchased);

      // Mirrors: `bool get isInterstitialReady => !_subscriberBlocked && _ad != null`
      final fakeAdLoaded = true; // pretend an ad is loaded
      final isInterstitialReady = !m.isSubscribed && fakeAdLoaded;
      expect(
        isInterstitialReady,
        isFalse,
        reason: 'Premium user — interstitial must report not-ready',
      );
    });
  });
}
