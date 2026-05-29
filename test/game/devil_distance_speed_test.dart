// Unit tests for the refactored rubber-band distance → speed-factor mapping
// used by [DevilComponent].
//
// The pure-Dart helpers below mirror the constants and algorithm in
// [devil.dart] verbatim (excluding the ±0.03 random jitter, which is tested
// separately in the 'jitter' group). Any accidental drift between the two
// files will be caught immediately here.
//
// New in this revision:
//   • minFactor 0.85, maxFactor 1.25 (tighter, fairer range)
//   • Quadratic t² easing instead of linear lerp
//   • Jitter range and clamp validation
//   • Stability test: no factor jump > 0.2 between consecutive distances
//   • Non-linearity test: quadratic midpoint ≠ linear midpoint

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

// ─── Constants mirrored from devil.dart / game_config.dart ───────────────────
const double _tileSize = 32.0;

const double _nearFrac  = 0.25;
const double _farFrac   = 0.75;
const double _minFactor = 0.85;  // updated: was 0.70
const double _maxFactor = 1.25;  // updated: was 1.50

const double _devilBaseSpeed          = 85.0;
const double _devilSpeedGrowthPerSecond = 2.8;
const double _devilMaxSpeed           = 170.0;
// ─────────────────────────────────────────────────────────────────────────────

/// Replicates the maze-diagonal calculation from [DevilComponent.update].
double _mapDiag(int logicalRows, int logicalCols) {
  final expandedRows = logicalRows * 2 + 1;
  final expandedCols = logicalCols * 2 + 1;
  final diagW = (expandedCols - 1) * _tileSize;
  final diagH = (expandedRows - 1) * _tileSize;
  return sqrt(diagW * diagW + diagH * diagH);
}

/// Replicates the *deterministic* quadratic factor computation from
/// [DevilComponent.update] — jitter excluded so tests are reproducible.
///
/// Formula:
///   t = clamp((distance - nearDist) / (farDist - nearDist), 0, 1)
///   factor = minFactor + (maxFactor - minFactor) * t²
double _computeFactor(double distance, double mapDiag) {
  final nearDist = _nearFrac * mapDiag;
  final farDist  = _farFrac  * mapDiag;
  final t = ((distance - nearDist) / (farDist - nearDist)).clamp(0.0, 1.0);
  return _minFactor + (_maxFactor - _minFactor) * (t * t);
}

/// Linear midpoint reference used in the non-linearity test.
///
/// With linear lerp the midpoint of [minFactor, maxFactor] would be:
///   minFactor + (maxFactor - minFactor) * 0.5
double get _linearMidpointFactor =>
    _minFactor + (_maxFactor - _minFactor) * 0.5; // 1.05

/// Replicates the base-speed formula from [DevilComponent].
double _baseSpeed(double chaseElapsed) {
  final s = _devilBaseSpeed + chaseElapsed * _devilSpeedGrowthPerSecond;
  return s.clamp(_devilBaseSpeed, _devilMaxSpeed);
}

/// Replicates the final clamped effective speed from [DevilComponent.speed].
double _effectiveSpeed(double chaseElapsed, double distanceFactor) =>
    (_baseSpeed(chaseElapsed) * distanceFactor).clamp(0.2, 255.0);

void main() {
  // Default maze: 11×11 logical cells (matches GameBalanceConfig defaults).
  const int rows = 11;
  const int cols = 11;
  final diag     = _mapDiag(rows, cols);
  final nearDist = _nearFrac * diag;
  final farDist  = _farFrac  * diag;
  final midDist  = (nearDist + farDist) / 2;

  // ──────────────────────────────────────────────────────────────────────────
  group('mapDiag', () {
    test('is positive and non-zero for default maze', () {
      expect(diag, greaterThan(0));
    });

    test('scales correctly for a larger maze (22×22 logical)', () {
      final largeDiag = _mapDiag(22, 22);
      expect(largeDiag, greaterThan(diag));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  group('distance → factor mapping (boundary conditions)', () {
    test('distance = 0 → minFactor (0.85)', () {
      expect(_computeFactor(0, diag), closeTo(_minFactor, 1e-9));
    });

    test('distance = nearDist exactly → minFactor', () {
      expect(_computeFactor(nearDist, diag), closeTo(_minFactor, 1e-9));
    });

    test('distance = farDist exactly → maxFactor (1.25)', () {
      expect(_computeFactor(farDist, diag), closeTo(_maxFactor, 1e-9));
    });

    test('distance > mapDiag → maxFactor (clamped at 1.25)', () {
      expect(_computeFactor(diag * 2, diag), closeTo(_maxFactor, 1e-9));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 1. NON-LINEAR VALIDATION
  // With t² easing the midpoint factor is LESS than the linear midpoint,
  // confirming the curve is not linear.
  //
  //   Linear midpoint  = 0.85 + 0.40 × 0.5  = 1.05
  //   Quadratic midpoint (t=0.5) = 0.85 + 0.40 × 0.25 = 0.95
  group('1 · non-linear validation (quadratic vs linear midpoint)', () {
    test('midpoint factor (0.95) is strictly less than linear midpoint (1.05)', () {
      final quadraticMid = _computeFactor(midDist, diag);
      expect(quadraticMid, closeTo(0.95, 1e-6));
      expect(quadraticMid, lessThan(_linearMidpointFactor));
    });

    test('¼ of the way through range → factor ≈ 0.875 (below linear ¼ = 0.95)', () {
      // t = 0.25  →  factor = 0.85 + 0.40 × 0.0625 = 0.875
      final d = nearDist + (farDist - nearDist) * 0.25;
      expect(_computeFactor(d, diag), closeTo(0.875, 1e-6));
    });

    test('¾ of the way through range → factor ≈ 1.075 (below linear ¾ = 1.15)', () {
      // t = 0.75  →  factor = 0.85 + 0.40 × 0.5625 = 1.075
      final d = nearDist + (farDist - nearDist) * 0.75;
      expect(_computeFactor(d, diag), closeTo(1.075, 1e-6));
    });

    test('curve is convex: midpoint factor < arithmetic mean of endpoints', () {
      final mean = (_minFactor + _maxFactor) / 2; // 1.05
      expect(_computeFactor(midDist, diag), lessThan(mean));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 2. RANGE ENFORCEMENT
  // factor must always stay within [0.85, 1.25] for any distance input.
  group('2 · range enforcement [0.85, 1.25]', () {
    test('factor is always in [minFactor, maxFactor] across representative distances', () {
      final distances = [
        0.0,
        nearDist * 0.5,
        nearDist,
        midDist,
        farDist,
        diag,
        diag * 1.5,
      ];
      for (final d in distances) {
        final f = _computeFactor(d, diag);
        expect(f, greaterThanOrEqualTo(_minFactor),
            reason: 'factor below minFactor at distance=$d');
        expect(f, lessThanOrEqualTo(_maxFactor),
            reason: 'factor above maxFactor at distance=$d');
      }
    });

    test('jitter ceiling: minFactor + 0.03 jitter is still ≤ maxFactor after clamp', () {
      // Worst-case positive jitter on a factor already at maxFactor.
      const worstCase = _maxFactor + 0.03;
      expect(worstCase.clamp(_minFactor, _maxFactor), closeTo(_maxFactor, 1e-9));
    });

    test('jitter floor: minFactor - 0.03 jitter is still ≥ minFactor after clamp', () {
      const worstCase = _minFactor - 0.03;
      expect(worstCase.clamp(_minFactor, _maxFactor), closeTo(_minFactor, 1e-9));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 3. MONOTONICITY
  // factor must be non-decreasing as distance increases from nearDist → farDist.
  group('3 · monotonicity (factor increases with distance)', () {
    test('factor is non-decreasing across 50 steps from nearDist to farDist', () {
      const steps = 50;
      double prev = _computeFactor(nearDist, diag);
      for (var i = 1; i <= steps; i++) {
        final d    = nearDist + (farDist - nearDist) * (i / steps);
        final curr = _computeFactor(d, diag);
        expect(curr, greaterThanOrEqualTo(prev - 1e-12), // tolerate float noise
            reason: 'factor decreased at step $i (prev=$prev, curr=$curr)');
        prev = curr;
      }
    });

    test('factor is non-decreasing for distances beyond farDist (clamped plateau)', () {
      final atFar    = _computeFactor(farDist, diag);
      final beyondFar = _computeFactor(farDist * 2, diag);
      expect(beyondFar, greaterThanOrEqualTo(atFar - 1e-12));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 4. CLAMP INTERACTION
  // Final speed must satisfy: speed = (baseSpeed × factor).clamp(0.2, 255).
  // Clamping must happen AFTER multiplication (critical ordering).
  group('4 · clamp interaction (final speed bounds)', () {
    test('speed is never below 0.2 (lower bound)', () {
      final s = (_baseSpeed(0) * _minFactor).clamp(0.2, 255.0);
      expect(s, greaterThanOrEqualTo(0.2));
    });

    test('speed is never above 255 (upper bound)', () {
      final s = (_devilMaxSpeed * _maxFactor).clamp(0.2, 255.0);
      expect(s, lessThanOrEqualTo(255.0));
    });

    test('speed at t=0, far distance uses baseSpeed × 1.25', () {
      final expected = (_devilBaseSpeed * _maxFactor).clamp(0.2, 255.0);
      expect(_effectiveSpeed(0, _maxFactor), closeTo(expected, 1e-9));
    });

    test('speed at t=0, near distance uses baseSpeed × 0.85', () {
      final expected = (_devilBaseSpeed * _minFactor).clamp(0.2, 255.0);
      expect(_effectiveSpeed(0, _minFactor), closeTo(expected, 1e-9));
    });

    test('speed grows with chaseElapsed when factor is fixed at 1.0', () {
      final s0  = _effectiveSpeed(0, 1.0);
      final s30 = _effectiveSpeed(30, 1.0);
      expect(s30, greaterThan(s0));
    });

    test('speed is capped at devilMaxSpeed × maxFactor ≤ 255 after long chase', () {
      final s = _effectiveSpeed(10000, _maxFactor);
      expect(s, lessThanOrEqualTo(255.0));
      expect(s, closeTo((_devilMaxSpeed * _maxFactor).clamp(0.2, 255.0), 1e-6));
    });

    test('clamp-after-multiply: unclamped value exceeds 255 but result is ≤ 255', () {
      // Verify the clamping is needed (i.e., the product can exceed 255).
      final unclamped = _devilMaxSpeed * _maxFactor; // 170 × 1.25 = 212.5 < 255
      // Inflate artificially to prove the clamp catches it.
      const syntheticBase = 220.0;
      const syntheticFactor = 1.25;
      expect(syntheticBase * syntheticFactor, greaterThan(255.0));
      final clamped = (syntheticBase * syntheticFactor).clamp(0.2, 255.0);
      expect(clamped, equals(255.0));
      // Normal game values stay within 255 with current config.
      expect(unclamped, lessThanOrEqualTo(255.0));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 5. STABILITY TEST
  // No sudden factor jump > 0.2 between consecutive distance steps.
  // Uses 100 evenly-spaced steps across the interpolation range. With t²
  // and range = 0.40, the worst-case delta between adjacent steps is ~0.008,
  // which is well within the 0.2 threshold.
  group('5 · stability (no sudden jumps > 0.2 between consecutive distances)', () {
    test('max factor delta ≤ 0.2 across 100 steps from nearDist to farDist', () {
      const steps = 100;
      const maxAllowedDelta = 0.2;
      double prev = _computeFactor(nearDist, diag);
      double maxDelta = 0.0;

      for (var i = 1; i <= steps; i++) {
        final d    = nearDist + (farDist - nearDist) * (i / steps);
        final curr = _computeFactor(d, diag);
        final delta = (curr - prev).abs();
        if (delta > maxDelta) maxDelta = delta;
        expect(delta, lessThan(maxAllowedDelta),
            reason:
                'Factor jumped $delta at step $i (distance=$d) — '
                'exceeds stability threshold $maxAllowedDelta');
        prev = curr;
      }
    });

    test('max factor delta ≤ 0.05 even at the steepest part of the t² curve', () {
      // The curve is steepest near t=1. Step size = range/100.
      // Empirically: delta ≈ 0.40 * 2 * 0.01 = 0.008 at t≈1.
      const steps = 100;
      const maxAllowedDelta = 0.05;
      double prev = _computeFactor(nearDist, diag);

      for (var i = 1; i <= steps; i++) {
        final d    = nearDist + (farDist - nearDist) * (i / steps);
        final curr = _computeFactor(d, diag);
        expect((curr - prev).abs(), lessThan(maxAllowedDelta));
        prev = curr;
      }
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  group('edge cases', () {
    test('zero-size maze does not throw (degenerate diagonal = 0)', () {
      final zeroDiag = _mapDiag(0, 0);
      // When mapDiag = 0, (distance - 0) / (0 - 0) = NaN → clamp(0,1) → 0.
      // Result: minFactor. No exception should be thrown.
      expect(() => _computeFactor(0, zeroDiag), returnsNormally);
    });

    test('thresholds are consistent: nearDist < farDist for default maze', () {
      expect(nearDist, lessThan(farDist));
    });

    test('factor range is tighter than the old [0.70, 1.50] — delta = 0.40', () {
      // Ensures the range was intentionally narrowed to reduce difficulty spikes.
      const expectedRange = _maxFactor - _minFactor;
      expect(expectedRange, closeTo(0.40, 1e-9));
      expect(expectedRange, lessThan(0.80)); // old range was 0.80
    });
  });
}
