import 'package:flutter/material.dart';

/// The in-run look (2D-gameplay-assets.md): Night 32 colours, outlined
/// numbers and the delivered UI pieces, with no neon, pink or green.
abstract final class NightHud {
  static const bone = Color(0xFFF0E6D2);
  static const boneDim = Color(0xFFB39572);
  static const blood = Color(0xFFE03A32);
  static const bloodDeep = Color(0xFF7A1520);
  static const amber = Color(0xFFF2B544);
  static const gold = Color(0xFFFFE08A);
  static const spirit = Color(0xFF9CC8F0);
  static const ink = Color(0xFF16151F);
  static const slate = Color(0xFF23222F);
  static const stone = Color(0xFF3B4660);

  /// Heavy bone-white numbers with a dark outline, readable over any tile.
  /// The one place to swap in a pixel font once it is bundled.
  static TextStyle number(double size, {Color color = bone}) => TextStyle(
    color: color,
    fontSize: size,
    fontWeight: FontWeight.w900,
    height: 1,
    letterSpacing: 1,
    shadows: const [
      Shadow(color: ink, offset: Offset(1.5, 1.5)),
      Shadow(color: ink, offset: Offset(-1.5, 1.5)),
      Shadow(color: ink, offset: Offset(1.5, -1.5)),
      Shadow(color: ink, offset: Offset(-1.5, -1.5)),
    ],
  );

  /// The old neon accents (AppPalette) mapped to their Night 32 roles:
  /// green → amber (go), purple → dim bone (neutral), pink/red → blood,
  /// cyan → spirit blue, gold stays gold. Other colours pass through.
  static Color tame(Color c) => switch (c.toARGB32() & 0xFFFFFF) {
    0x33FF2B || 0xB7FFA8 => amber,
    0xE26AE6 || 0xC5B0FF => boneDim,
    0xE85BDA || 0xFF3D8B || 0xFF8A80 || 0xFF4D4D || 0xFF6B6B => blood,
    0x87ECFF || 0x79EFFF || 0x5A9FD9 => spirit,
    0xFFD700 => gold,
    _ => c,
  }.withValues(alpha: c.a);

  /// The bone-and-skull medallion with a UI icon in its dark centre.
  static Widget medallion(String icon, {double size = 64}) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        art(
          'medallion',
          width: size,
          fallback: const DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, color: slate),
          ),
        ),
        art('icon_$icon', width: size * 0.46),
      ],
    ),
  );

  /// A delivered UI piece (assets/images/2d/ui/[name].png) at [width] ×
  /// [height] (square when only [width] is given), or [fallback] until the
  /// file exists.
  static Widget art(
    String name, {
    required double width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Widget? fallback,
  }) {
    final h = height ?? width;
    return Image.asset(
      'assets/images/2d/ui/$name.png',
      width: width,
      height: h,
      fit: fit,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) =>
          SizedBox(width: width, height: h, child: fallback),
    );
  }
}
