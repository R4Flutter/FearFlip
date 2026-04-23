import 'package:flutter_test/flutter_test.dart';

import 'package:fearflipgame/services/ad_placement_policy.dart';

void main() {
  test('suppresses first game over interstitial by default', () {
    final policy = AdPlacementPolicy(
      interstitialCooldown: const Duration(minutes: 2),
    );
    final now = DateTime(2026, 4, 23, 12);

    policy.recordGameOver();

    expect(policy.canShowInterstitial(now), isFalse);
  });

  test('allows interstitial after required game overs and cooldown', () {
    final policy = AdPlacementPolicy(
      interstitialCooldown: const Duration(minutes: 2),
    );
    final now = DateTime(2026, 4, 23, 12);

    policy.recordGameOver();
    policy.recordGameOver();
    expect(policy.canShowInterstitial(now), isTrue);

    policy.recordInterstitialShown(now);
    policy.recordGameOver();
    policy.recordGameOver();

    expect(
      policy.canShowInterstitial(now.add(const Duration(seconds: 90))),
      isFalse,
    );
    expect(
      policy.canShowInterstitial(now.add(const Duration(minutes: 2))),
      isTrue,
    );
  });
}
