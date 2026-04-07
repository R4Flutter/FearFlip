import 'package:flame/components.dart';
import 'dart:math';

class RealityFlipSystem extends Component {
  RealityFlipSystem({
    required this.flipInterval,
    required this.warningDuration,
    this.flipRandomness = 0,
    Random? random,
    required this.onWarning,
    required this.onFlip,
  }) : _random = random ?? Random();

  final double flipInterval;
  final double warningDuration;
  final double flipRandomness;
  final void Function(double secondsLeft) onWarning;
  final void Function() onFlip;
  final Random _random;

  double _elapsed = 0;
  bool _warningFired = false;
  late double _currentTargetInterval = _nextInterval();

  double get secondsUntilFlip =>
      (_currentTargetInterval - _elapsed).clamp(0, _currentTargetInterval);

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;

    if (!_warningFired &&
        _elapsed >= _currentTargetInterval - warningDuration) {
      _warningFired = true;
      onWarning(secondsUntilFlip);
    }

    if (_elapsed >= _currentTargetInterval) {
      _elapsed = 0;
      _warningFired = false;
      _currentTargetInterval = _nextInterval();
      onFlip();
    }
  }

  void reset() {
    _elapsed = 0;
    _warningFired = false;
    _currentTargetInterval = _nextInterval();
  }

  double _nextInterval() {
    final randomness = flipRandomness.clamp(0.0, 0.80);
    if (randomness == 0) {
      return flipInterval;
    }
    final spread = flipInterval * randomness;
    final jitter = (_random.nextDouble() * 2 - 1) * spread;
    return (flipInterval + jitter).clamp(1.2, 30.0);
  }
}
