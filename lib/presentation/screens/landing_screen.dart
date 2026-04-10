import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({
    required this.isStarting,
    required this.onPlay,
    required this.onChooseCharacter,
    required this.onSettings,
    required this.onLeaderboard,
    required this.onRemoveAds,
    required this.playerName,
    required this.totalTrophies,
    required this.globalPanicRank,
    super.key,
  });

  final bool isStarting;
  final VoidCallback onPlay;
  final VoidCallback onChooseCharacter;
  final VoidCallback onSettings;
  final VoidCallback onLeaderboard;
  final VoidCallback onRemoveAds;
  final String playerName;
  final int totalTrophies;
  final int? globalPanicRank;

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5600),
    )..repeat();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _loop,
      builder: (context, _) {
        final progress = _loop.value;
        final pulse = 0.86 + math.sin(progress * math.pi * 2) * 0.14;

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppPalette.backgroundLight, AppPalette.backgroundDark],
              stops: [0.5, 0.5],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _GridGlitchPainter(progress: progress)),
              IgnorePointer(
                child: Opacity(
                  opacity: pulse.clamp(0.72, 1),
                  child: Align(
                    alignment: const Alignment(0, -0.82),
                    child: Container(
                      width: 560,
                      height: 260,
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Color(0x66E26AE6),
                            Color(0x5533FF2B),
                            Color(0x00FFFFFF),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 540;
                    final widthScale = (constraints.maxWidth / 390)
                        .clamp(0.86, 1.18)
                        .toDouble();
                    final topBreathingSpace = (constraints.maxHeight * 0.07)
                        .clamp(28.0, 72.0)
                        .toDouble();
                    final actionSectionDrop = (constraints.maxHeight * 0.10)
                        .clamp(52.0, 110.0)
                        .toDouble();
                    final actionGap = (constraints.maxHeight * 0.022)
                        .clamp(16.0, 24.0)
                        .toDouble();

                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 14 : 22,
                        topBreathingSpace,
                        compact ? 14 : 22,
                        36,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _TopMetaBar(
                                widthScale: widthScale,
                                playerName: widget.playerName,
                                totalTrophies: widget.totalTrophies,
                              ),
                              SizedBox(
                                height: (constraints.maxHeight * 0.02)
                                    .clamp(10.0, 22.0)
                                    .toDouble(),
                              ),
                              _GlitchWordmark(progress: progress),
                              SizedBox(height: actionSectionDrop),
                              _DashboardActionButton(
                                label: widget.isStarting
                                    ? 'LOADING...'
                                    : 'START SURVIVAL',
                                sublabel:
                                    'Enter active run mode and start your survival chain',
                                icon: Icons.play_arrow_rounded,
                                color: AppPalette.accentPink,
                                foreground: Colors.black,
                                enabled: !widget.isStarting,
                                onPressed: widget.onPlay,
                              ),
                              SizedBox(height: actionGap),
                              _DashboardActionButton(
                                label: 'CHOOSE CHARACTER',
                                sublabel:
                                    'Select your runner before entering the maze',
                                icon: Icons.person,
                                color: AppPalette.neonGreen,
                                foreground: Colors.black,
                                enabled: true,
                                onPressed: widget.onChooseCharacter,
                              ),
                              SizedBox(height: actionGap),
                              _DashboardActionButton(
                                label: 'SETTINGS',
                                sublabel:
                                    'Tune controls, input style, and session preferences',
                                icon: Icons.settings,
                                color: AppPalette.accentPurple,
                                foreground: Colors.black,
                                enabled: true,
                                onPressed: widget.onSettings,
                              ),
                              SizedBox(height: actionGap),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: widget.onLeaderboard,
                                      icon: const Icon(Icons.emoji_events),
                                      label: const Text('Leaderboard'),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(56),
                                        backgroundColor: AppPalette.neonGreen,
                                        foregroundColor: Colors.black,
                                        textStyle: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          letterSpacing: 0.2,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: widget.onRemoveAds,
                                      icon: const Icon(Icons.block),
                                      label: const Text('Remove Ads'),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(56),
                                        backgroundColor: AppPalette.accentPink,
                                        foregroundColor: Colors.black,
                                        textStyle: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          letterSpacing: 0.2,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: (constraints.maxHeight * 0.03)
                                    .clamp(22.0, 38.0)
                                    .toDouble(),
                              ),
                              _RankPanel(
                                widthScale: widthScale,
                                globalPanicRank: widget.globalPanicRank,
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopMetaBar extends StatelessWidget {
  const _TopMetaBar({
    required this.widthScale,
    required this.playerName,
    required this.totalTrophies,
  });

  final double widthScale;
  final String playerName;
  final int totalTrophies;

  @override
  Widget build(BuildContext context) {
    final titleSize = (17 * widthScale).clamp(13.0, 20.0).toDouble();
    final bodySize = (12 * widthScale).clamp(10.0, 14.0).toDouble();

    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: _ArcadeTrophyBadge(
              trophies: totalTrophies,
              scale: widthScale,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppPalette.surfaceSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppPalette.accentPurple.withAlpha(130)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  playerName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppPalette.accentPurple,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    fontSize: bodySize,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'FLIP IN & ESCAPE',
                  style: TextStyle(
                    color: AppPalette.neonGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: titleSize,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ArcadeTrophyBadge extends StatelessWidget {
  const _ArcadeTrophyBadge({required this.trophies, required this.scale});

  final int trophies;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final safeTrophies = trophies < 0 ? 0 : trophies;
    final titleSize = (9 * scale).clamp(8.0, 11.0);
    final valueSize = (16 * scale).clamp(13.0, 20.0);
    final iconSize = (16 * scale).clamp(13.0, 19.0);

    return Container(
      padding: EdgeInsets.fromLTRB(
        (10 * scale).clamp(8.0, 12.0),
        (7 * scale).clamp(6.0, 9.0),
        (12 * scale).clamp(10.0, 14.0),
        (7 * scale).clamp(6.0, 9.0),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular((14 * scale).clamp(11.0, 18.0)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF24153D), Color(0xFF0C0A16)],
        ),
        border: Border.all(color: const Color(0xFF4DEFFF), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x884DEFFF),
            blurRadius: 16,
            spreadRadius: -2,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x552A8FFF),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: (26 * scale).clamp(20.0, 32.0),
            height: (26 * scale).clamp(20.0, 32.0),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFD86A), Color(0xFFFFA93D)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x88FFCB46),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.emoji_events_rounded,
              size: iconSize,
              color: const Color(0xFF3A2200),
            ),
          ),
          SizedBox(width: (8 * scale).clamp(6.0, 10.0)),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TROPHIES',
                style: TextStyle(
                  color: const Color(0xFF7FF8FF),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  fontSize: titleSize,
                ),
              ),
              Text(
                '$safeTrophies',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: valueSize,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlitchWordmark extends StatelessWidget {
  const _GlitchWordmark({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final fontSize = width < 400 ? 44.0 : 62.0;
    final driftX = math.sin(progress * math.pi * 14) * 2.4;
    final driftY = math.cos(progress * math.pi * 22) * 1.6;

    Text layer(Color color) {
      return Text(
        'FEARFLIP',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          height: 1,
          letterSpacing: 1.6,
          shadows: const [
            Shadow(
              color: Color(0x96000000),
              blurRadius: 14,
              offset: Offset(0, 3),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: fontSize + 12,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: Offset(-driftX, driftY),
            child: layer(AppPalette.neonGreen.withAlpha(170)),
          ),
          Transform.translate(
            offset: Offset(driftX, -driftY),
            child: layer(AppPalette.accentPurple.withAlpha(170)),
          ),
          layer(AppPalette.accentPurple),
        ],
      ),
    );
  }
}

class _DashboardActionButton extends StatelessWidget {
  const _DashboardActionButton({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
    required this.foreground,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
  final Color foreground;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        elevation: 0,
        minimumSize: const Size.fromHeight(84),
        disabledBackgroundColor: color.withAlpha(130),
        disabledForegroundColor: foreground.withAlpha(120),
        backgroundColor: color,
        foregroundColor: foreground,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: foreground.withAlpha(34),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sublabel,
                  style: TextStyle(
                    color: foreground.withAlpha(210),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: foreground.withAlpha(185)),
        ],
      ),
    );
  }
}

class _RankPanel extends StatelessWidget {
  const _RankPanel({required this.widthScale, required this.globalPanicRank});

  final double widthScale;
  final int? globalPanicRank;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppPalette.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.accentPurple),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GLOBAL PANIC LEADERBOARD',
            style: TextStyle(
              color: AppPalette.neonGreen,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              fontSize: (14 * widthScale).clamp(12.0, 16.0).toDouble(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            globalPanicRank == null ? 'Rank: N/A' : 'Rank: #$globalPanicRank',
            style: TextStyle(
              color: AppPalette.accentPurple,
              fontWeight: FontWeight.w900,
              fontSize: (36 * widthScale).clamp(28.0, 42.0).toDouble(),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridGlitchPainter extends CustomPainter {
  _GridGlitchPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppPalette.neonGreen.withAlpha(38)
      ..strokeWidth = 1;

    const spacing = 34.0;
    for (var x = 0.0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final scanlineTop = (size.height + 90) * progress - 45;
    final scanRect = Rect.fromLTWH(0, scanlineTop, size.width, 40);
    final scanPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x0033FF2B), Color(0x6633FF2B), Color(0x0033FF2B)],
      ).createShader(scanRect);
    canvas.drawRect(scanRect, scanPaint);

    final glitchPaint = Paint()..color = AppPalette.accentPurple.withAlpha(80);
    for (var i = 0; i < 6; i++) {
      final wave = progress * math.pi * (8 + i * 2.4);
      final top = (size.height * (0.12 + 0.14 * i) + math.sin(wave) * 17).clamp(
        0.0,
        size.height - 4,
      );
      final left = (size.width * (0.08 + i * 0.03) + math.cos(wave * 1.3) * 26)
          .clamp(0.0, size.width - 100);
      final width = (size.width * (0.23 + i * 0.05)).clamp(
        88.0,
        size.width - left,
      );

      canvas.drawRect(
        Rect.fromLTWH(left.toDouble(), top.toDouble(), width.toDouble(), 3),
        glitchPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridGlitchPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
