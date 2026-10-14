import 'package:flutter/material.dart';
import '../../theme/night_hud.dart';
import '../../../domain/entities/direction4.dart';

/// The bloody cross-in-a-ring base with the pearl knob; drag to steer.
class Joystick extends StatefulWidget {
  const Joystick({
    required this.size,
    required this.onDirection,
    required this.onEnd,
    super.key,
  });

  final double size;
  final ValueChanged<Direction4?> onDirection;
  final VoidCallback onEnd;

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  static const double _deadZone = 10;
  Offset _knobOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final knob = widget.size * 0.36;
    return Center(
      child: GestureDetector(
        onPanDown: (details) => _handleDrag(details.localPosition),
        onPanUpdate: (details) => _handleDrag(details.localPosition),
        onPanEnd: (_) => _resetKnob(),
        onPanCancel: _resetKnob,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            children: [
              Positioned.fill(
                child: NightHud.art(
                  'joystick',
                  width: widget.size,
                  fallback: const DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: NightHud.slate,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Transform.translate(
                  offset: _knobOffset,
                  child: Center(
                    child: NightHud.art(
                      'knob',
                      width: knob,
                      fallback: const DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: NightHud.bone,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleDrag(Offset local) {
    final radius = widget.size / 2;
    final maxKnobOffset = widget.size * 0.28;
    final dx = local.dx - radius;
    final dy = local.dy - radius;
    final vector = Offset(dx, dy);
    final distance = vector.distance;

    Offset limited = vector;
    if (distance > maxKnobOffset && distance > 0) {
      limited = vector / distance * maxKnobOffset;
    }

    setState(() {
      _knobOffset = limited;
    });

    widget.onDirection(_directionFromVector(vector));
  }

  void _resetKnob() {
    if (_knobOffset != Offset.zero) {
      setState(() {
        _knobOffset = Offset.zero;
      });
    }
    widget.onEnd();
  }

  Direction4? _directionFromVector(Offset vector) {
    final dx = vector.dx;
    final dy = vector.dy;
    if (dx.abs() < _deadZone && dy.abs() < _deadZone) {
      return null;
    }
    if (dx.abs() > dy.abs()) {
      return dx >= 0 ? Direction4.right : Direction4.left;
    }
    return dy >= 0 ? Direction4.down : Direction4.up;
  }
}

/// The carved stone cross. Holding an arm moves that way; the stone shows
/// that arm pressed in (the pressed art has its socket on the up arm, so it
/// turns a quarter per direction).
class ArrowPad extends StatefulWidget {
  const ArrowPad({
    required this.size,
    required this.onDirection,
    required this.onEnd,
    super.key,
  });

  static const artKey = ValueKey<String>('arrow_pad_art');

  final double size;
  final ValueChanged<Direction4?> onDirection;
  final VoidCallback onEnd;

  @override
  State<ArrowPad> createState() => _ArrowPadState();
}

class _ArrowPadState extends State<ArrowPad> {
  Direction4? _held;

  static const _arms = [
    (Direction4.up, Alignment.topCenter),
    (Direction4.down, Alignment.bottomCenter),
    (Direction4.left, Alignment.centerLeft),
    (Direction4.right, Alignment.centerRight),
  ];

  void _press(Direction4 direction) {
    setState(() => _held = direction);
    widget.onDirection(direction);
  }

  void _release() {
    if (_held != null) {
      setState(() => _held = null);
    }
    widget.onEnd();
  }

  @override
  Widget build(BuildContext context) {
    final padSize = (widget.size * 1.08).clamp(104.0, 188.0);
    final arm = padSize * 0.34;
    final held = _held;

    return SizedBox(
      width: padSize,
      height: padSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotatedBox(
            key: ArrowPad.artKey,
            quarterTurns: switch (held) {
              null || Direction4.up => 0,
              Direction4.right => 1,
              Direction4.down => 2,
              Direction4.left => 3,
            },
            child: NightHud.art(
              held == null ? 'dpad' : 'dpad_pressed',
              width: padSize,
              fallback: Icon(
                Icons.gamepad_rounded,
                color: NightHud.bone,
                size: padSize * 0.8,
              ),
            ),
          ),
          for (final (direction, alignment) in _arms)
            Align(
              alignment: alignment,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => _press(direction),
                onTapUp: (_) => _release(),
                onTapCancel: _release,
                child: SizedBox(width: arm, height: arm),
              ),
            ),
        ],
      ),
    );
  }
}
