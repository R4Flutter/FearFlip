abstract class MonetizationService {
  Future<bool> showReviveRewardedAd();
  Future<bool> unlockCosmetic(String cosmeticId);
  Future<bool> isPremiumUnlocked();
}

class NoopMonetizationService implements MonetizationService {
  @override
  Future<bool> isPremiumUnlocked() async => false;

  @override
  Future<bool> showReviveRewardedAd() async => false;

  @override
  Future<bool> unlockCosmetic(String cosmeticId) async => false;
}
