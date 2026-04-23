import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/app_runtime_config.dart';

class GlitchEffectController {
  GlitchEffectController({
    Random? random,
    bool effectsEnabled = AppRuntimeConfig.glitchEffectsEnabled,
  }) : _random = random ?? Random(),
       _effectsEnabled = effectsEnabled;

  static const double _minDurationSeconds = 0.30;
  static const double _maxDurationSeconds = 0.50;

  final Random _random;
  final bool _effectsEnabled;

  bool _active = false;
  double _durationSeconds = 0;
  double _remainingSeconds = 0;
  double _channelOpacity = 0;
  double _flickerOpacity = 0;
  double _scanlineOpacity = 0;
  double _scanlinePhase = 0;
  double _horizontalJitterPx = 0;
  double _rgbShiftPx = 0;
  double _jitterTimer = 0;
  double _flickerTimer = 0;

  bool get isActive => _active;
  double get channelOpacity => _channelOpacity;
  double get flickerOpacity => _flickerOpacity;
  double get scanlineOpacity => _scanlineOpacity;
  double get scanlinePhase => _scanlinePhase;
  double get horizontalJitterPx => _horizontalJitterPx;
  double get rgbShiftPx => _rgbShiftPx;

  void trigger({double? durationSeconds}) {
    if (!_effectsEnabled) {
      _deactivate();
      return;
    }

    final requested =
        durationSeconds ??
        _randomInRange(_minDurationSeconds, _maxDurationSeconds);

    _durationSeconds = requested
        .clamp(_minDurationSeconds, _maxDurationSeconds)
        .toDouble();
    _remainingSeconds = _durationSeconds;
    _active = true;
    _scanlinePhase = _random.nextDouble();
    _jitterTimer = 0;
    _flickerTimer = 0;
    _horizontalJitterPx = 0;
    _channelOpacity = 0.12;
    _scanlineOpacity = 0.08;
    _flickerOpacity = 0.10;
    _rgbShiftPx = 2.0;
  }

  void update(double deltaSeconds) {
    if (!_active) {
      return;
    }

    final dt = max(0.0, deltaSeconds);
    _remainingSeconds = (_remainingSeconds - dt).clamp(0.0, 10.0);

    if (_remainingSeconds <= 0 || _durationSeconds <= 0) {
      _deactivate();
      return;
    }

    final progress = 1.0 - (_remainingSeconds / _durationSeconds);
    final envelope = sin(pi * progress).abs();

    _scanlinePhase = (_scanlinePhase + dt * 15.0) % 1.0;
    _channelOpacity = (0.10 + 0.22 * envelope).clamp(0.08, 0.40);
    _scanlineOpacity = (0.05 + 0.16 * envelope).clamp(0.04, 0.25);
    _rgbShiftPx = (1.5 + 3.5 * envelope).clamp(1.0, 6.0);

    _jitterTimer -= dt;
    if (_jitterTimer <= 0) {
      _jitterTimer = _randomInRange(0.02, 0.06);
      _horizontalJitterPx = _randomInRange(-4.5, 4.5) * (0.5 + 0.5 * envelope);
    }

    _flickerTimer -= dt;
    if (_flickerTimer <= 0) {
      _flickerTimer = _randomInRange(0.03, 0.08);
      _flickerOpacity = _randomInRange(0.03, 0.15) * (0.55 + 0.45 * envelope);
    }
  }

  void clear() {
    _deactivate();
  }

  void _deactivate() {
    _active = false;
    _durationSeconds = 0;
    _remainingSeconds = 0;
    _channelOpacity = 0;
    _flickerOpacity = 0;
    _scanlineOpacity = 0;
    _scanlinePhase = 0;
    _horizontalJitterPx = 0;
    _rgbShiftPx = 0;
    _jitterTimer = 0;
    _flickerTimer = 0;
  }

  double _randomInRange(double minValue, double maxValue) {
    if (maxValue <= minValue) {
      return minValue;
    }
    return minValue + _random.nextDouble() * (maxValue - minValue);
  }
}

class GlitchEffectOverlay extends StatelessWidget {
  const GlitchEffectOverlay({
    super.key,
    required this.controller,
    required this.child,
  });

  final GlitchEffectController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!controller.isActive) {
      return child;
    }

    final shift = controller.rgbShiftPx;
    final jitter = controller.horizontalJitterPx;

    return Stack(
      fit: StackFit.expand,
      children: [
        Transform.translate(offset: Offset(jitter, 0), child: child),
        IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Transform.translate(
                offset: Offset(-shift, 0),
                child: Opacity(
                  opacity: controller.channelOpacity,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.red.withValues(alpha: 0.75),
                      BlendMode.modulate,
                    ),
                    child: child,
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(shift, 0),
                child: Opacity(
                  opacity: controller.channelOpacity,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      const Color(0xFF66E0FF).withValues(alpha: 0.75),
                      BlendMode.modulate,
                    ),
                    child: child,
                  ),
                ),
              ),
              Opacity(
                opacity: controller.flickerOpacity,
                child: Container(color: Colors.white),
              ),
              CustomPaint(
                painter: _ScanlinePainter(
                  opacity: controller.scanlineOpacity,
                  phase: controller.scanlinePhase,
                ),
                size: Size.infinite,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  const _ScanlinePainter({required this.opacity, required this.phase});

  final double opacity;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0 || size.isEmpty) {
      return;
    }

    final paint = Paint()
      ..color = Colors.black.withValues(alpha: opacity)
      ..strokeWidth = 1;

    final step = max(2.0, size.height / 120);
    final offset = phase * step * 2;

    for (double y = -offset; y <= size.height + step; y += step * 2) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter oldDelegate) {
    return oldDelegate.opacity != opacity || oldDelegate.phase != phase;
  }
}
