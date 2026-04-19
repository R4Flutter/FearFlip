import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/leaderboard_service.dart';

class LeaderboardNextLevelScreen extends StatefulWidget {
  const LeaderboardNextLevelScreen({
    super.key,
    required this.service,
    this.limit = 20,
  });

  final LeaderboardService service;
  final int limit;

  @override
  State<LeaderboardNextLevelScreen> createState() =>
      _LeaderboardNextLevelScreenState();
}

class _LeaderboardNextLevelScreenState extends State<LeaderboardNextLevelScreen>
    with SingleTickerProviderStateMixin {
  late Future<LeaderboardSnapshot> _future;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<LeaderboardSnapshot> _load() {
    final safeLimit = widget.limit.clamp(1, 100);
    return widget.service.getGlobalPanicLeaderboard(limit: safeLimit);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  String _formatClock(DateTime value) {
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _V2Palette.bgDeep,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ArenaBackdropPainter(
                      progress: _pulseController.value,
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: -120,
              right: -80,
              child: IgnorePointer(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x66FF6A3D), Color(0x00FF6A3D)],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: -100,
              bottom: -120,
              child: IgnorePointer(
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x4D00E5FF), Color(0x0000E5FF)],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderBar(onRefresh: _refresh),
                  const SizedBox(height: 10),
                  Expanded(
                    child: FutureBuilder<LeaderboardSnapshot>(
                      future: _future,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const _StatusPanel(
                            icon: Icons.bolt_rounded,
                            title: 'Syncing Arena Rankings',
                            message:
                                'Compiling live panic standings and trophy signals...',
                            showLoader: true,
                            accent: _V2Palette.energyBlue,
                          );
                        }

                        if (snapshot.hasError) {
                          return _StatusPanel(
                            icon: Icons.wifi_off_rounded,
                            title: 'Signal Lost',
                            message:
                                'The leaderboard feed is not reachable right now.',
                            accent: _V2Palette.alert,
                            action: FilledButton.icon(
                              onPressed: () {
                                unawaited(_refresh());
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Reconnect'),
                              style: FilledButton.styleFrom(
                                backgroundColor: _V2Palette.alert,
                                foregroundColor: Colors.black,
                              ),
                            ),
                          );
                        }

                        final data = snapshot.data;
                        if (data == null || data.entries.isEmpty) {
                          return _StatusPanel(
                            icon: Icons.rocket_launch_rounded,
                            title: 'No Champions Yet',
                            message:
                                'Be the first player to claim the global panic throne.',
                            accent: _V2Palette.energyBlue,
                            action: FilledButton.icon(
                              onPressed: () {
                                unawaited(_refresh());
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Refresh'),
                              style: FilledButton.styleFrom(
                                backgroundColor: _V2Palette.energyBlue,
                                foregroundColor: Colors.black,
                              ),
                            ),
                          );
                        }

                        return _LeaderboardBody(
                          data: data,
                          formatClock: _formatClock,
                          onRefresh: _refresh,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GlassIconButton(
          icon: Icons.arrow_back_rounded,
          onTap: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GLOBAL PANIC LEADERBOARD',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.orbitron(
                  color: _V2Palette.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Neon Arena Ranking Grid',
                style: GoogleFonts.exo2(
                  color: _V2Palette.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        _GlassIconButton(
          icon: Icons.refresh_rounded,
          accent: _V2Palette.accent,
          onTap: () {
            unawaited(onRefresh());
          },
        ),
      ],
    );
  }
}

class _LeaderboardBody extends StatelessWidget {
  const _LeaderboardBody({
    required this.data,
    required this.formatClock,
    required this.onRefresh,
  });

  final LeaderboardSnapshot data;
  final String Function(DateTime) formatClock;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final top3 = data.entries.take(3).toList(growable: false);

    return RefreshIndicator(
      color: _V2Palette.energyBlue,
      backgroundColor: _V2Palette.panel,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          _IdentityDeck(data: data, formatClock: formatClock),
          const SizedBox(height: 12),
          if (top3.isNotEmpty) ...[
            _TopPodium(topEntries: top3),
            const SizedBox(height: 12),
          ],
          _SectionLabel(
            title: 'ARENA RANKINGS',
            subtitle: '${data.totalPlayers} active competitors',
          ),
          const SizedBox(height: 8),
          ...List<Widget>.generate(data.entries.length, (index) {
            final entry = data.entries[index];
            final isCurrentUser =
                data.myRank != null && entry.rank == data.myRank;
            final stagger = (index * 30).clamp(0, 300);
            final duration = Duration(milliseconds: 240 + stagger);

            return TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: duration,
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - value) * 16),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LeaderboardEntryTile(
                  entry: entry,
                  isCurrentUser: isCurrentUser,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _IdentityDeck extends StatelessWidget {
  const _IdentityDeck({required this.data, required this.formatClock});

  final LeaderboardSnapshot data;
  final String Function(DateTime) formatClock;

  @override
  Widget build(BuildContext context) {
    final rankLabel = data.myRank == null ? '--' : '#${data.myRank}';
    final stageLabel = '${data.myMaxStage ?? 0}';
    final trophyLabel = '${data.myTotalTrophies ?? 0}';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF161D30), Color(0xFF111624), Color(0xFF0D101A)],
        ),
        border: Border.all(color: _V2Palette.energyBlue.withAlpha(170)),
        boxShadow: [
          BoxShadow(
            color: _V2Palette.energyBlue.withAlpha(55),
            blurRadius: 14,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [_V2Palette.accent, _V2Palette.energyBlue],
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.shield_rounded,
                  color: Colors.black,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your Combat Snapshot',
                  style: GoogleFonts.orbitron(
                    color: _V2Palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Text(
                'Updated ${formatClock(data.fetchedAt)}',
                style: GoogleFonts.exo2(
                  color: _V2Palette.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 380;
              if (compact) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'RANK',
                            value: rankLabel,
                            color: _V2Palette.energyBlue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            title: 'STAGE',
                            value: stageLabel,
                            color: _V2Palette.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _StatCard(
                      title: 'TROPHIES',
                      value: trophyLabel,
                      color: _V2Palette.gold,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'RANK',
                      value: rankLabel,
                      color: _V2Palette.energyBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      title: 'STAGE',
                      value: stageLabel,
                      color: _V2Palette.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      title: 'TROPHIES',
                      value: trophyLabel,
                      color: _V2Palette.gold,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _V2Palette.panelStrong,
        border: Border.all(color: color.withAlpha(190)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.exo2(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.orbitron(
              color: _V2Palette.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopPodium extends StatelessWidget {
  const _TopPodium({required this.topEntries});

  final List<LeaderboardEntry> topEntries;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: _V2Palette.panel,
        border: Border.all(color: _V2Palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(
            title: 'TOP PODIUM',
            subtitle: 'Elite players currently leading the arena',
          ),
          const SizedBox(height: 9),
          Row(
            children: List<Widget>.generate(topEntries.length, (index) {
              final entry = topEntries[index];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == topEntries.length - 1 ? 0 : 8,
                  ),
                  child: _PodiumCard(entry: entry),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final rankColor = _rankColor(entry.rank);
    final name = _displayName(entry.displayName);
    final stage = entry.maxStage ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [rankColor.withAlpha(72), rankColor.withAlpha(26)],
        ),
        border: Border.all(color: rankColor.withAlpha(210)),
      ),
      child: Column(
        children: [
          Icon(_rankIcon(entry.rank), color: rankColor, size: 18),
          const SizedBox(height: 4),
          Text(
            '#${entry.rank}',
            style: GoogleFonts.orbitron(
              color: _V2Palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.exo2(
              color: _V2Palette.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'STG $stage',
            style: GoogleFonts.exo2(
              color: _V2Palette.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardEntryTile extends StatelessWidget {
  const _LeaderboardEntryTile({
    required this.entry,
    required this.isCurrentUser,
  });

  final LeaderboardEntry entry;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final rankColor = _rankColor(entry.rank);
    final name = _displayName(entry.displayName);

    final bgA = isCurrentUser
        ? const Color(0x2437F6FF)
        : const Color(0x1A1A1F2C);
    final bgB = isCurrentUser
        ? const Color(0x1A7AFFC4)
        : const Color(0x1A111521);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bgA, bgB],
        ),
        border: Border.all(
          color: isCurrentUser ? _V2Palette.energyBlue : _V2Palette.line,
          width: isCurrentUser ? 1.5 : 1.0,
        ),
        boxShadow: isCurrentUser
            ? [
                BoxShadow(
                  color: _V2Palette.energyBlue.withAlpha(45),
                  blurRadius: 10,
                  spreadRadius: -2,
                  offset: const Offset(0, 4),
                ),
              ]
            : const <BoxShadow>[],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: rankColor.withAlpha(38),
              border: Border.all(color: rankColor.withAlpha(220)),
            ),
            alignment: Alignment.center,
            child: Text(
              '${entry.rank}',
              style: GoogleFonts.orbitron(
                color: rankColor,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.exo2(
                          color: _V2Palette.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _V2Palette.energyBlue,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'YOU',
                          style: GoogleFonts.exo2(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    _MiniChip(
                      label: 'STAGE ${entry.maxStage ?? 0}',
                      accent: _V2Palette.accent,
                    ),
                    const SizedBox(width: 6),
                    _MiniChip(
                      label: 'TROPHIES ${entry.totalTrophies ?? 0}',
                      accent: _V2Palette.gold,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            _rankIcon(entry.rank),
            color: rankColor,
            size: entry.rank <= 3 ? 20 : 16,
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: accent.withAlpha(30),
        border: Border.all(color: accent.withAlpha(180)),
      ),
      child: Text(
        label,
        style: GoogleFonts.exo2(
          color: _V2Palette.textPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.orbitron(
                  color: _V2Palette.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: GoogleFonts.exo2(
                  color: _V2Palette.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.accent,
    this.action,
    this.showLoader = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color accent;
  final Widget? action;
  final bool showLoader;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _V2Palette.panel,
            border: Border.all(color: accent.withAlpha(210), width: 1.4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showLoader)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: accent,
                  ),
                )
              else
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: accent,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: Colors.black, size: 24),
                ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.orbitron(
                  color: _V2Palette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.exo2(
                  color: _V2Palette.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (action != null) ...[const SizedBox(height: 12), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.accent = _V2Palette.energyBlue,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _V2Palette.panelStrong,
            border: Border.all(color: accent.withAlpha(180)),
          ),
          child: Icon(icon, color: _V2Palette.textPrimary),
        ),
      ),
    );
  }
}

class _ArenaBackdropPainter extends CustomPainter {
  const _ArenaBackdropPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_V2Palette.bgTop, _V2Palette.bgMid, _V2Palette.bgDeep],
      ).createShader(rect);
    canvas.drawRect(rect, background);

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _V2Palette.grid.withAlpha(42);

    const step = 34.0;
    final sweep = (progress * step) % step;

    for (double x = -step + sweep; x <= size.width + step; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final pulse = 0.5 + 0.5 * math.sin(progress * math.pi * 2);
    final scanPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _V2Palette.energyBlue.withAlpha((18 + (18 * pulse)).round()),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromLTWH(
              0,
              size.height * 0.18,
              size.width,
              size.height * 0.28,
            ),
          );

    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.18, size.width, size.height * 0.26),
      scanPaint,
    );

    final sparkPaint = Paint()..style = PaintingStyle.fill;
    const particleCount = 20;
    for (var i = 0; i < particleCount; i++) {
      final t = (progress + (i / particleCount)) % 1.0;
      final x = (size.width * t + i * 23) % size.width;
      final y = (size.height * (0.15 + 0.75 * ((i * 0.137) % 1.0)));
      final radius = 1.2 + (i % 3) * 0.5;
      sparkPaint.color =
          (i % 2 == 0 ? _V2Palette.accent : _V2Palette.energyBlue).withAlpha(
            50 + ((1 - t) * 80).round(),
          );
      canvas.drawCircle(Offset(x, y), radius, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ArenaBackdropPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

String _displayName(String? raw) {
  final trimmed = (raw ?? '').trim();
  return trimmed.isEmpty ? 'Player' : trimmed;
}

Color _rankColor(int rank) {
  if (rank == 1) {
    return _V2Palette.gold;
  }
  if (rank == 2) {
    return const Color(0xFFB9C8DA);
  }
  if (rank == 3) {
    return const Color(0xFFE89C63);
  }
  if (rank <= 10) {
    return _V2Palette.energyBlue;
  }
  return _V2Palette.textMuted;
}

IconData _rankIcon(int rank) {
  if (rank == 1) {
    return Icons.workspace_premium_rounded;
  }
  if (rank == 2) {
    return Icons.military_tech_rounded;
  }
  if (rank == 3) {
    return Icons.stars_rounded;
  }
  return Icons.bolt_rounded;
}

class _V2Palette {
  static const Color bgTop = Color(0xFF16213A);
  static const Color bgMid = Color(0xFF0D1425);
  static const Color bgDeep = Color(0xFF070B14);

  static const Color panel = Color(0xCC0F1628);
  static const Color panelStrong = Color(0xD9162136);
  static const Color line = Color(0xFF2B3A59);
  static const Color grid = Color(0xFF32537D);

  static const Color textPrimary = Color(0xFFF3F6FF);
  static const Color textMuted = Color(0xFFA8B3C7);

  static const Color energyBlue = Color(0xFF37F6FF);
  static const Color accent = Color(0xFFFF6A3D);
  static const Color gold = Color(0xFFFFC857);
  static const Color alert = Color(0xFFFF5E5E);
}
