import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/night_hud.dart';
import 'cyber_horror_ui_components.dart';

/// A short in-run message ("KEY 1 OF 2", "SEALED"). [serial] tells repeats
/// of the same text apart so each one animates in.
@immutable
class RunBannerMessage {
  const RunBannerMessage({
    required this.title,
    required this.serial,
    this.subtitle,
    this.color = NightHud.gold,
  });

  final String title;
  final String? subtitle;
  final Color color;
  final int serial;
}

/// The message box at the top of the run: a small Pokémon-style text box
/// that pops in and fades out. It never takes touches.
class RunBanner extends StatelessWidget {
  const RunBanner({required this.message, this.scale = 1, super.key});

  static const boxKey = ValueKey<String>('run_banner');

  final ValueListenable<RunBannerMessage?> message;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<RunBannerMessage?>(
        valueListenable: message,
        builder: (context, value, _) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              ),
              child: child,
            ),
          ),
          child: value == null
              ? const SizedBox.shrink()
              : _BannerBox(
                  key: ValueKey<int>(value.serial),
                  message: value,
                  scale: scale,
                ),
        ),
      ),
    );
  }
}

class _BannerBox extends StatelessWidget {
  const _BannerBox({required this.message, required this.scale, super.key});

  final RunBannerMessage message;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final accent = NightHud.tame(message.color);
    return ConstrainedBox(
      key: RunBanner.boxKey,
      constraints: BoxConstraints(maxWidth: 360 * scale),
      child: Stack(
        children: [
          Positioned.fill(child: RealityGlassPanel(color: accent)),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 18 * scale,
              vertical: 10 * scale,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: accent,
                    fontFamily: 'FFBody',
                    fontSize: 19.5 * scale,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    shadows: const [
                      Shadow(color: NightHud.ink, offset: Offset(1.5, 1.5)),
                    ],
                  ),
                ),
                if (message.subtitle != null) ...[
                  SizedBox(height: 3 * scale),
                  Text(
                    message.subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: NightHud.bone,
                      fontFamily: 'FFBody',
                      fontSize: 13 * scale,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
