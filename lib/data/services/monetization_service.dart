import '../../services/purchase_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

/// Defines the monetization contract used by game systems.
///
/// Concrete implementations:
///   • [FlutterMonetizationService] – production, wired to [PurchaseService]
///   • [NoopMonetizationService]   – testing / stub environments
abstract class MonetizationService {
  Future<bool> showReviveRewardedAd();
  Future<bool> unlockCosmetic(String cosmeticId);

  /// Returns `true` when the user has permanently unlocked the Remove Ads
  /// entitlement. Callers ([AdsService], UI) should suppress all ads when true.
  Future<bool> isPremiumUnlocked();
}

// ─────────────────────────────────────────────────────────────────────────────
// Production implementation
// ─────────────────────────────────────────────────────────────────────────────

/// Concrete [MonetizationService] backed by [PurchaseService].
///
/// `isPremiumUnlocked` is synchronous in practice — it reads the in-memory
/// flag from [PurchaseService.isSubscribed] which is initialised from
/// SharedPreferences at startup.  The `Future` wrapper is kept to preserve
/// the interface contract.
class FlutterMonetizationService implements MonetizationService {
  const FlutterMonetizationService();

  @override
  Future<bool> isPremiumUnlocked() async =>
      PurchaseService.instance.isSubscribed;

  /// Rewarded revive ads are handled by [AdsService] directly.
  /// This stub returns false; override if needed.
  @override
  Future<bool> showReviveRewardedAd() async => false;

  /// Cosmetic unlocks are not yet implemented.
  @override
  Future<bool> unlockCosmetic(String cosmeticId) async => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// No-op stub for tests / non-IAP builds
// ─────────────────────────────────────────────────────────────────────────────

/// Safe stub that always reports the user as non-premium.
/// Use in unit tests and CI environments where billing is unavailable.
class NoopMonetizationService implements MonetizationService {
  const NoopMonetizationService();

  @override
  Future<bool> isPremiumUnlocked() async => false;

  @override
  Future<bool> showReviveRewardedAd() async => false;

  @override
  Future<bool> unlockCosmetic(String cosmeticId) async => false;
}
