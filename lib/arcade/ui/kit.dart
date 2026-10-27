import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ff_icons.dart';
import 'sfx.dart';

export 'ff_icons.dart';
export 'sfx.dart';

/// The menu look, matched to the maze art (2D-gameplay-assets.md "Night 32"):
/// cold stone and cobbles, bone text boxes like Pokémon FireRed's, amber
/// candlelight for actions, spirit blue for safety, blood for danger.
abstract final class FF {
  // Night 32.
  static const void_ = Color(0xFF0A0A0F);
  static const ink = Color(0xFF16151F);
  static const slate = Color(0xFF23222F);
  static const slate2 = Color(0xFF34344A);
  static const navy = Color(0xFF1E2A3A);
  static const stone = Color(0xFF3B4660);
  static const stone2 = Color(0xFF55627E);
  static const stone3 = Color(0xFF7884A0);
  static const stoneLight = Color(0xFFA3AEC4);
  static const stoneHi = Color(0xFFD3D9E4);
  static const bone = Color(0xFFF0E6D2);
  static const bone2 = Color(0xFFD8C3A0);
  static const boneDim = Color(0xFFB39572);
  static const leather = Color(0xFF8A6B50);
  static const leatherDark = Color(0xFF5E4636);
  static const wood = Color(0xFF3E2A20);
  static const rust = Color(0xFF9C5A2B);
  static const amberDark = Color(0xFFC98A2E);
  static const amber = Color(0xFFF2B544);
  static const gold = Color(0xFFFFE08A);
  static const blood0 = Color(0xFF2A080C);
  static const bloodDeep = Color(0xFF4D0E15);
  static const blood2 = Color(0xFF7A1520);
  static const blood3 = Color(0xFFB0202A);
  static const blood = Color(0xFFE03A32);
  static const bruise = Color(0xFF45294F);
  static const spirit = Color(0xFF9CC8F0);
  static const spiritHi = Color(0xFFE4F2FF);

  static const String titleFont = 'FFTitle';
  static const String bodyFont = 'FFBody';

  /// Jersey 15 is narrow and short for its size; body text is drawn this
  /// much larger so callers can think in ordinary point sizes.
  static const double bodyScale = 1.22;

  /// Big gothic pixel title with a hard ink shadow and a glow.
  static TextStyle title(double size, {Color color = bone, Color? glow}) =>
      TextStyle(
        fontFamily: titleFont,
        fontSize: size,
        color: color,
        height: 0.95,
        letterSpacing: 1,
        shadows: [
          Shadow(color: ink, offset: Offset(size * 0.04, size * 0.04)),
          Shadow(color: ink, offset: Offset(-size * 0.02, size * 0.04)),
          if (glow != null) Shadow(color: glow, blurRadius: size * 0.35),
        ],
      );

  /// Pixel body text. [outline] adds the dark rim used over maze and stone.
  static TextStyle text(
    double size, {
    Color color = bone,
    FontWeight weight = FontWeight.w600,
    bool outline = true,
    double letterSpacing = 0.5,
    double height = 1.15,
  }) => TextStyle(
    fontFamily: bodyFont,
    fontSize: size * bodyScale,
    color: color,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
    shadows: outline
        ? [
            Shadow(color: ink, offset: Offset(0, max(1.0, size * 0.09))),
            Shadow(color: ink.withValues(alpha: 0.7), blurRadius: 2),
          ]
        : null,
  );

  /// Dark text for bone boxes, with FireRed's soft drop shadow.
  static TextStyle boxText(double size, {Color color = slate}) => TextStyle(
    fontFamily: bodyFont,
    fontSize: size * bodyScale,
    color: color,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: 0.4,
    shadows: const [Shadow(color: bone2, offset: Offset(1.2, 1.2))],
  );

  static const String _ui = 'assets/images/2d/ui';

  static ImageProvider texture(String name) => AssetImage('$_ui/$name');

  static const floorTex = 'tex_floor.jpg';
  static const rubbleTex = 'tex_rubble.jpg';
  static const bloodFloorTex = 'tex_floor_blood.jpg';
  static const bonesTex = 'tex_bones.jpg';

  /// A delivered painted icon (assets/images/2d/ui/icon_[name].png).
  static Widget art(String name, {double size = 24}) => Image.asset(
    '$_ui/$name.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.medium,
    errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
  );
}

/// A scale for the current screen: 1.0 on a 1280×720 window, smaller on a
/// phone, never so small that text is unreadable.
double uiScaleOf(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final byWidth = size.width / 1280;
  final byHeight = size.height / 720;
  final wide = size.width >= size.height;
  final s = wide ? min(byWidth, byHeight) : size.width / 430;
  return s.clamp(0.72, 1.35);
}

bool isWideLayout(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.width >= size.height * 1.1 && size.width >= 640;
}

// -----------------------------------------------------------------------------
// Panels
// -----------------------------------------------------------------------------

/// A stone frame: a rubble-stone rim around a dark cobble floor, like a
/// window cut into the maze wall.
class StonePanel extends StatelessWidget {
  const StonePanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.rim = 9,
    this.glow,
    this.blood = false,
    this.dim = 0.62,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double rim;
  final Color? glow;

  /// Nightmare variant: bone wall and blood-soaked floor.
  final bool blood;

  /// How dark the floor inside is (0–1).
  final double dim;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FF.ink, width: 3),
        image: DecorationImage(
          image: FF.texture(blood ? FF.bonesTex : FF.rubbleTex),
          repeat: ImageRepeat.repeat,
          scale: 2.2,
          colorFilter: ColorFilter.mode(
            (blood ? FF.blood0 : FF.ink).withValues(alpha: 0.25),
            BlendMode.darken,
          ),
        ),
        boxShadow: [
          const BoxShadow(
            color: Color(0xAA000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
          if (glow != null)
            BoxShadow(color: glow!.withValues(alpha: 0.35), blurRadius: 26),
        ],
      ),
      padding: EdgeInsets.all(rim),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: FF.ink, width: 2.5),
          image: DecorationImage(
            image: FF.texture(blood ? FF.bloodFloorTex : FF.floorTex),
            repeat: ImageRepeat.repeat,
            scale: 2.6,
            colorFilter: ColorFilter.mode(
              FF.ink.withValues(alpha: dim),
              BlendMode.srcATop,
            ),
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 0, spreadRadius: 0),
          ],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          border: Border(
            top: BorderSide(color: FF.stoneLight.withValues(alpha: 0.35)),
          ),
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}

/// The Pokémon-style text box: bone paper, a double ink-and-leather border.
class BoneBox extends StatelessWidget {
  const BoneBox({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 10, 14, 10),
    this.color = FF.bone,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: FF.ink, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x99000000), blurRadius: 10, offset: Offset(0, 5)),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: FF.leather, width: 2),
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}

/// A sunken dark slot inside a panel (list rows, stat chips).
class Slot extends StatelessWidget {
  const Slot({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    this.highlight,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: FF.ink.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: highlight ?? FF.slate2,
          width: highlight == null ? 1.5 : 2,
        ),
        boxShadow: highlight == null
            ? null
            : [
                BoxShadow(
                  color: highlight!.withValues(alpha: 0.3),
                  blurRadius: 12,
                ),
              ],
      ),
      child: child,
    );
  }
}

// -----------------------------------------------------------------------------
// Buttons
// -----------------------------------------------------------------------------

enum ButtonTone { amber, blood, spirit, stone, bone, gold }

class _Tone {
  const _Tone(this.top, this.mid, this.bottom, this.edge, this.label, this.labelShadow);

  final Color top;
  final Color mid;
  final Color bottom;
  final Color edge;
  final Color label;
  final Color labelShadow;
}

const Map<ButtonTone, _Tone> _tones = {
  ButtonTone.amber: _Tone(FF.gold, FF.amber, FF.amberDark, FF.rust, FF.ink, Color(0x66FFF3C4)),
  ButtonTone.gold: _Tone(Color(0xFFFFF3C4), FF.gold, FF.amber, FF.amberDark, FF.ink, Color(0x88FFFFFF)),
  ButtonTone.blood: _Tone(FF.blood, FF.blood3, FF.blood2, FF.bloodDeep, FF.bone, FF.ink),
  ButtonTone.spirit: _Tone(FF.spiritHi, FF.spirit, Color(0xFF6A94C0), Color(0xFF3B5E86), FF.ink, Color(0x88FFFFFF)),
  ButtonTone.stone: _Tone(FF.stone3, FF.stone2, FF.stone, FF.slate, FF.bone, FF.ink),
  ButtonTone.bone: _Tone(FF.bone, FF.bone2, FF.boneDim, FF.leather, FF.ink, Color(0x88FFFFFF)),
};

/// A raised slab button: lit from the top, a dark edge underneath that sinks
/// when pressed, a click, and a soft breathing glow when [pulse] is on.
class SlabButton extends StatefulWidget {
  const SlabButton({
    required this.label,
    required this.onPressed,
    this.tone = ButtonTone.amber,
    this.icon,
    this.trailing,
    this.height = 52,
    this.width,
    this.fontSize,
    this.pulse = false,
    this.sublabel,
    this.sound = Sound.click,
    super.key,
  });

  final String label;
  final String? sublabel;
  final VoidCallback? onPressed;
  final ButtonTone tone;
  final Widget? icon;
  final Widget? trailing;
  final double height;
  final double? width;
  final double? fontSize;
  final bool pulse;
  final Sound? sound;

  @override
  State<SlabButton> createState() => _SlabButtonState();
}

class _SlabButtonState extends State<SlabButton>
    with SingleTickerProviderStateMixin {
  bool _down = false;
  bool _hover = false;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant SlabButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.pulse && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _tap() {
    final onPressed = widget.onPressed;
    if (onPressed == null) return;
    final sound = widget.sound;
    if (sound != null) Sfx.instance.play(sound, volume: 0.6);
    HapticFeedback.selectionClick();
    onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final tone = _tones[enabled ? widget.tone : ButtonTone.stone]!;
    final depth = widget.height * 0.11;
    final pressed = _down && enabled;
    final fontSize = widget.fontSize ?? widget.height * 0.36;

    final label = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          maxLines: 1,
          overflow: TextOverflow.visible,
          softWrap: false,
          style: TextStyle(
            fontFamily: FF.bodyFont,
            fontSize: fontSize * FF.bodyScale,
            fontWeight: FontWeight.w700,
                    color: enabled ? tone.label : FF.stoneLight,
            letterSpacing: 1.2,
            height: 1,
            shadows: [Shadow(color: tone.labelShadow, offset: const Offset(0, 1.5))],
          ),
        ),
        if (widget.sublabel != null) ...[
          SizedBox(height: fontSize * 0.18),
          Text(
            widget.sublabel!,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontFamily: FF.bodyFont,
              fontSize: fontSize * 0.5 * FF.bodyScale,
              fontWeight: FontWeight.w600,
              color: (enabled ? tone.label : FF.stoneLight).withValues(alpha: 0.8),
              letterSpacing: 0.8,
              height: 1,
            ),
          ),
        ],
      ],
    );

    final face = AnimatedContainer(
      duration: const Duration(milliseconds: 70),
      margin: EdgeInsets.only(
        top: pressed ? depth * 0.7 : 0,
        bottom: pressed ? depth * 0.3 : depth,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(tone.top, Colors.white, _hover && enabled ? 0.12 : 0)!,
            Color.lerp(tone.mid, Colors.white, _hover && enabled ? 0.08 : 0)!,
            tone.bottom,
          ],
          stops: const [0, 0.45, 1],
        ),
        border: Border.all(color: FF.ink, width: 2.5),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.45), width: 2),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: widget.height * 0.32),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            widget.icon!,
            SizedBox(width: widget.height * 0.16),
          ],
          Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: label)),
          if (widget.trailing != null) ...[
            SizedBox(width: widget.height * 0.16),
            widget.trailing!,
          ],
        ],
      ),
    );

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: enabled ? _tap : null,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final glow = widget.pulse && enabled ? _pulse.value : 0.0;
            return AnimatedScale(
              scale: _hover && enabled && !pressed ? 1.03 : 1,
              duration: const Duration(milliseconds: 120),
              child: Container(
                width: widget.width,
                height: widget.height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: tone.edge,
                  border: Border.all(color: FF.ink, width: 2.5),
                  boxShadow: [
                    const BoxShadow(
                      color: Color(0x88000000),
                      blurRadius: 8,
                      offset: Offset(0, 5),
                    ),
                    if (glow > 0)
                      BoxShadow(
                        color: tone.mid.withValues(alpha: 0.25 + 0.4 * glow),
                        blurRadius: 14 + 16 * glow,
                        spreadRadius: 1 + 3 * glow,
                      ),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: face,
        ),
      ),
    );
  }
}

/// A round stone button holding one icon (back, settings, close).
class RoundButton extends StatefulWidget {
  const RoundButton({
    required this.icon,
    required this.onPressed,
    this.size = 46,
    this.tooltip,
    this.badge = 0,
    this.tone = ButtonTone.stone,
    super.key,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final double size;
  final String? tooltip;
  final int badge;
  final ButtonTone tone;

  @override
  State<RoundButton> createState() => _RoundButtonState();
}

class _RoundButtonState extends State<RoundButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final tone = _tones[widget.tone]!;
    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onPressed == null
            ? null
            : () {
                Sfx.instance.play(Sound.click, volume: 0.6);
                widget.onPressed!();
              },
        child: AnimatedScale(
          scale: _down ? 0.92 : (_hover ? 1.07 : 1),
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.5),
                colors: [tone.top, tone.mid, tone.bottom],
                stops: const [0, 0.55, 1],
              ),
              border: Border.all(color: FF.ink, width: 2.5),
              boxShadow: const [
                BoxShadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(0, 3)),
              ],
            ),
            alignment: Alignment.center,
            child: widget.icon,
          ),
        ),
      ),
    );
    final withBadge = widget.badge > 0
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              button,
              Positioned(right: -3, top: -3, child: BadgeDot(count: widget.badge)),
            ],
          )
        : button;
    return widget.tooltip == null
        ? withBadge
        : Tooltip(message: widget.tooltip!, child: withBadge);
  }
}

/// A red notification dot, with a count when there is more than one.
class BadgeDot extends StatefulWidget {
  const BadgeDot({this.count = 1, this.size = 20, super.key});

  final int count;
  final double size;

  @override
  State<BadgeDot> createState() => _BadgeDotState();
}

class _BadgeDotState extends State<BadgeDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.1).animate(
          CurvedAnimation(parent: _c, curve: Curves.easeInOut),
        ),
        child: Container(
          constraints: BoxConstraints(minWidth: widget.size, minHeight: widget.size),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: FF.blood,
            borderRadius: BorderRadius.circular(widget.size),
            border: Border.all(color: FF.ink, width: 2),
            boxShadow: const [BoxShadow(color: Color(0x88E03A32), blurRadius: 8)],
          ),
          alignment: Alignment.center,
          child: Text(
            widget.count > 1 ? '${widget.count}' : '!',
            style: FF.text(widget.size * 0.62, weight: FontWeight.w700, outline: false),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Counters, stars, bars
// -----------------------------------------------------------------------------

/// A number that counts up or down to its new value.
class RollingNumber extends StatelessWidget {
  const RollingNumber({required this.value, required this.style, super.key});

  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.toDouble()),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(formatNumber(v.round()), style: style),
    );
  }
}

String formatNumber(int n) {
  final s = n.abs().toString();
  final out = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

/// The wallet pill: a soul wisp and the count.
class SoulCounter extends StatelessWidget {
  const SoulCounter({required this.souls, this.scale = 1, this.onTap, super.key});

  final int souls;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      height: 40 * scale,
      padding: EdgeInsets.only(left: 6 * scale, right: 14 * scale),
      decoration: BoxDecoration(
        color: FF.ink.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: FF.spirit.withValues(alpha: 0.7), width: 2),
        boxShadow: [BoxShadow(color: FF.spirit.withValues(alpha: 0.18), blurRadius: 12)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FFIcon(FFGlyph.soul, size: 30 * scale),
          SizedBox(width: 6 * scale),
          RollingNumber(value: souls, style: FF.text(19 * scale, weight: FontWeight.w700)),
          if (onTap != null) ...[
            SizedBox(width: 8 * scale),
            FFIcon(FFGlyph.plus, size: 18 * scale),
          ],
        ],
      ),
    );
    if (onTap == null) return pill;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Sfx.instance.play(Sound.click, volume: 0.6);
          onTap!();
        },
        child: pill,
      ),
    );
  }
}

/// A small icon-and-number chip.
class StatChip extends StatelessWidget {
  const StatChip({
    required this.icon,
    required this.text,
    this.scale = 1,
    this.color = FF.bone,
    super.key,
  });

  final Widget icon;
  final String text;
  final double scale;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34 * scale,
      padding: EdgeInsets.symmetric(horizontal: 10 * scale),
      decoration: BoxDecoration(
        color: FF.ink.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: FF.slate2, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          SizedBox(width: 6 * scale),
          Text(text, style: FF.text(15 * scale, color: color, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Three stars, [earned] of them lit.
class StarRow extends StatelessWidget {
  const StarRow({required this.earned, this.size = 18, this.gap = 2, super.key});

  final int earned;
  final double size;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) SizedBox(width: gap),
          FFIcon(i < earned ? FFGlyph.star : FFGlyph.starEmpty, size: size),
        ],
      ],
    );
  }
}

/// A progress bar in a bone frame, filled with candlelight.
class BoneBar extends StatelessWidget {
  const BoneBar({
    required this.value,
    this.height = 14,
    this.color = FF.amber,
    this.label,
    super.key,
  });

  final double value;
  final double height;
  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: FF.ink,
        borderRadius: BorderRadius.circular(height),
        border: Border.all(color: FF.boneDim, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color.lerp(color, Colors.white, 0.4)!, color, Color.lerp(color, FF.ink, 0.35)!],
                  ),
                ),
              ),
            ),
            if (label != null)
              Center(
                child: Text(
                  label!,
                  style: FF.text(height * 0.62, weight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Backgrounds and titles
// -----------------------------------------------------------------------------

/// The menu backdrop: the maze's cobbles in torchlight, drifting dust and
/// soul wisps, and a dark vignette.
class DungeonBackdrop extends StatefulWidget {
  const DungeonBackdrop({this.child, this.nightmare = false, super.key});

  final Widget? child;
  final bool nightmare;

  @override
  State<DungeonBackdrop> createState() => _DungeonBackdropState();
}

class _DungeonBackdropState extends State<DungeonBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: FF.void_,
            image: DecorationImage(
              image: FF.texture(widget.nightmare ? FF.bloodFloorTex : FF.floorTex),
              repeat: ImageRepeat.repeat,
              scale: 1.5,
              colorFilter: ColorFilter.mode(
                FF.void_.withValues(alpha: widget.nightmare ? 0.5 : 0.42),
                BlendMode.srcATop,
              ),
            ),
          ),
        ),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              painter: _AtmospherePainter(
                t: _c.value * 60,
                nightmare: widget.nightmare,
              ),
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _AtmospherePainter extends CustomPainter {
  _AtmospherePainter({required this.t, required this.nightmare});

  final double t;
  final bool nightmare;

  @override
  void paint(Canvas canvas, Size size) {
    final light = nightmare ? FF.blood : FF.amber;
    // Two torch pools that breathe.
    for (final spot in const [Offset(0.12, 0.2), Offset(0.88, 0.75)]) {
      final flicker = 0.85 + 0.15 * sin(t * 7 + spot.dx * 10) * sin(t * 3.1);
      final c = Offset(spot.dx * size.width, spot.dy * size.height);
      final r = size.shortestSide * 0.55 * flicker;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              light.withValues(alpha: 0.16 * flicker),
              light.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
    // Dust motes and a few soul wisps.
    final rng = Random(11);
    for (var i = 0; i < 46; i++) {
      final x0 = rng.nextDouble();
      final y0 = rng.nextDouble();
      final speed = 0.004 + rng.nextDouble() * 0.01;
      final phase = rng.nextDouble() * 6.28;
      final wisp = i % 9 == 0;
      final x = (x0 + sin(t * 0.3 + phase) * 0.02) * size.width;
      final y = ((y0 - t * speed) % 1.0) * size.height;
      final a = (0.25 + 0.25 * sin(t * 1.3 + phase)).clamp(0.0, 1.0);
      final color = wisp ? (nightmare ? FF.blood : FF.spirit) : FF.bone2;
      final r = wisp ? 2.6 : 1.2 + rng.nextDouble();
      if (wisp) {
        canvas.drawCircle(
          Offset(x, y),
          r * 3.2,
          Paint()
            ..color = color.withValues(alpha: a * 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
      canvas.drawCircle(Offset(x, y), r, Paint()..color = color.withValues(alpha: a));
    }
    // Vignette.
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [
            Colors.transparent,
            FF.void_.withValues(alpha: 0.55),
            FF.void_.withValues(alpha: 0.92),
          ],
          stops: const [0.45, 0.8, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _AtmospherePainter old) =>
      old.t != t || old.nightmare != nightmare;
}

/// The FearFlip logo. Every few seconds "Flip" turns upside down.
class FearFlipLogo extends StatefulWidget {
  const FearFlipLogo({this.size = 96, super.key});

  final double size;

  @override
  State<FearFlipLogo> createState() => _FearFlipLogoState();
}

class _FearFlipLogoState extends State<FearFlipLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // Flip over between 70% and 80% of the cycle, back between 90% and 100%.
        final v = _c.value;
        double angle;
        if (v < 0.7) {
          angle = 0;
        } else if (v < 0.8) {
          angle = Curves.easeInOutBack.transform((v - 0.7) / 0.1) * pi;
        } else if (v < 0.9) {
          angle = pi;
        } else {
          angle = pi - Curves.easeInOut.transform((v - 0.9) / 0.1) * pi;
        }
        final shake = v > 0.7 && v < 0.74 ? sin(v * 600) * s * 0.02 : 0.0;
        return Transform.translate(
          offset: Offset(shake, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Fear', style: FF.title(s, color: FF.bone, glow: FF.amber.withValues(alpha: 0.45))),
              SizedBox(width: s * 0.12),
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.002)
                  ..rotateX(angle),
                child: Text(
                  'Flip',
                  style: FF.title(s, color: FF.blood, glow: FF.blood.withValues(alpha: 0.7)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Lays [wide] (1280×720) or [tall] (480×900) out at a fixed design size and
/// scales it to fit the screen, so menus look the same on every display.
class DesignCanvas extends StatelessWidget {
  const DesignCanvas({required this.wide, required this.tall, super.key});

  static const Size wideSize = Size(1280, 720);
  static const Size tallSize = Size(480, 900);

  final Widget wide;
  final Widget tall;

  static bool isWide(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width >= size.height * 0.95;
  }

  @override
  Widget build(BuildContext context) {
    final useWide = isWide(context);
    final size = useWide ? wideSize : tallSize;
    return SafeArea(
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: useWide ? wide : tall,
          ),
        ),
      ),
    );
  }
}

/// A screen with the backdrop, a top bar (back, title, souls) and a body,
/// laid out on the [DesignCanvas].
class MenuPage extends StatelessWidget {
  const MenuPage({
    required this.title,
    required this.body,
    required this.onBack,
    this.souls,
    this.trailing,
    this.nightmare = false,
    this.tallBody,
    super.key,
  });

  final String title;
  final Widget body;

  /// A different body for tall (portrait) screens; [body] otherwise.
  final Widget? tallBody;
  final VoidCallback onBack;
  final int? souls;
  final Widget? trailing;
  final bool nightmare;

  Widget _page(Widget content, {required bool wide}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 26 : 14, 18, wide ? 26 : 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              RoundButton(
                icon: const FFIcon(FFGlyph.back, size: 28),
                size: 54,
                tooltip: 'Back',
                onPressed: onBack,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FF.title(
                    wide ? 58 : 46,
                    glow: (nightmare ? FF.blood : FF.amber).withValues(alpha: 0.35),
                  ),
                ),
              ),
              if (trailing != null) ...[trailing!, const SizedBox(width: 10)],
              if (souls != null) SoulCounter(souls: souls!),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(child: content),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: DungeonBackdrop(
        nightmare: nightmare,
        child: DesignCanvas(
          wide: _page(body, wide: true),
          tall: _page(tallBody ?? body, wide: false),
        ),
      ),
    );
  }
}

/// Slides in from the bottom and fades: for screens opened from the menu.
Route<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 260),
  reverseTransitionDuration: const Duration(milliseconds: 200),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, animation, _, child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  },
);

/// Shows [child] as a modal over a dimmed screen, with a pop-in.
Future<T?> showFFDialog<T>(
  BuildContext context, {
  required Widget Function(BuildContext context) builder,
  bool dismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'Close',
    barrierColor: const Color(0xCC05050A),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, _, _) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Material(type: MaterialType.transparency, child: builder(context)),
        ),
      ),
    ),
    transitionBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: Tween<double>(begin: 0.85, end: 1).animate(curved), child: child),
      );
    },
  );
}
