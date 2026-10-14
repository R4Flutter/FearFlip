import 'package:flutter/material.dart';
import '../../theme/night_hud.dart';
import '../../../domain/entities/direction4.dart';

// The controls sit over the full-screen maze, so they're drawn see-through:
// a faint bone tint and outline, brighter only where the thumb is.
const double _fill = 0.10;
const double _fillHeld = 0.32;
const double _line = 0.32;
const double _lineHeld = 0.7;

/// A fixed, see-through joystick: drag the knob to steer.
class Joystick extends StatefulWidget {
  const Joystick({
    required this.size,
    required this.onDirection,
    required this.onEnd,
    super.key,
  });

  static const knobKey = ValueKey<String>('joystick_knob');

  final double size;
  final ValueChanged<Direction4?> onDirection;
  final VoidCallback onEnd;

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  static const double _deadZone = 10;
  static const _chevrons = [
    (Icons.keyboard_arrow_up_rounded, Alignment.topCenter),
    (Icons.keyboard_arrow_down_rounded, Alignment.bottomCenter),
    (Icons.keyboard_arrow_left_rounded, Alignment.centerLeft),
    (Icons.keyboard_arrow_right_rounded, Alignment.centerRight),
  ];
  Offset _knobOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final held = _knobOffset != Offset.zero;
    return Center(
      child: GestureDetector(
        onPanDown: (details) => _handleDrag(details.localPosition),
        onPanUpdate: (details) => _handleDrag(details.localPosition),
        onPanEnd: (_) => _resetKnob(),
        onPanCancel: _resetKnob,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: NightHud.bone.withValues(alpha: _fill * 0.8),
                    border: Border.all(
                      color: NightHud.bone.withValues(alpha: _line),
                      width: 2,
                    ),
                  ),
                ),
              ),
              for (final (icon, alignment) in _chevrons)
                Align(
                  alignment: alignment,
                  child: Icon(
                    icon,
                    size: size * 0.22,
                    color: NightHud.bone.withValues(alpha: 0.35),
                  ),
                ),
              Positioned.fill(
                child: Transform.translate(
                  offset: _knobOffset,
                  child: Center(
                    child: Container(
                      key: Joystick.knobKey,
                      width: size * 0.4,
                      height: size * 0.4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: NightHud.bone.withValues(
                          alpha: held ? _fillHeld + 0.08 : _fill * 2.5,
                        ),
                        border: Border.all(
                          color: NightHud.bone.withValues(
                            alpha: held ? _lineHeld : _line + 0.2,
                          ),
                          width: 1.5,
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

/// A fixed, see-through four-arm pad: hold an arm to move that way.
class ArrowPad extends StatefulWidget {
  const ArrowPad({
    required this.size,
    required this.onDirection,
    required this.onEnd,
    super.key,
  });

  static Key armKey(Direction4 direction) =>
      ValueKey<String>('arrow_pad_${direction.name}');

  final double size;
  final ValueChanged<Direction4?> onDirection;
  final VoidCallback onEnd;

  @override
  State<ArrowPad> createState() => _ArrowPadState();
}

class _ArrowPadState extends State<ArrowPad> {
  Direction4? _held;

  static const _arms = [
    (Direction4.up, Alignment.topCenter, Icons.keyboard_arrow_up_rounded),
    (
      Direction4.down,
      Alignment.bottomCenter,
      Icons.keyboard_arrow_down_rounded,
    ),
    (Direction4.left, Alignment.centerLeft, Icons.keyboard_arrow_left_rounded),
    (
      Direction4.right,
      Alignment.centerRight,
      Icons.keyboard_arrow_right_rounded,
    ),
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

    return SizedBox(
      width: padSize,
      height: padSize,
      child: Stack(
        children: [
          for (final (direction, alignment, icon) in _arms)
            Align(
              alignment: alignment,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => _press(direction),
                onTapUp: (_) => _release(),
                onTapCancel: _release,
                child: Container(
                  key: ArrowPad.armKey(direction),
                  width: arm,
                  height: arm,
                  decoration: BoxDecoration(
                    color: NightHud.bone.withValues(
                      alpha: _held == direction ? _fillHeld : _fill,
                    ),
                    borderRadius: BorderRadius.circular(arm * 0.22),
                    border: Border.all(
                      color: NightHud.bone.withValues(
                        alpha: _held == direction ? _lineHeld : _line,
                      ),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: arm * 0.7,
                    color: NightHud.bone.withValues(
                      alpha: _held == direction ? 0.95 : 0.6,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
