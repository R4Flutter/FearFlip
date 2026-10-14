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
