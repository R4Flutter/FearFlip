import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_runtime_config.dart';
import '../../services/leaderboard_service.dart';
import '../theme/app_palette.dart';

// ── Rank colour palette (matches AppPalette neons) ─────────────────────────
const _kGold   = AppPalette.neonGreen;   // #1 — neon green crown
const _kSilver = AppPalette.accentPurple; // #2 — purple
const _kBronze = AppPalette.accentPink;   // #3 — pink
const _kCyan   = Color(0xFF4DEFFF);

// Avatar colors cycling through brand neons
const _kAvatarPalette = [
  _kCyan, AppPalette.neonGreen, AppPalette.accentPink,
  AppPalette.accentPurple, Color(0xFFFFD86A), Color(0xFFFF8A80),
];

Color _uidColor(String? uid) {
  if (uid == null || uid.isEmpty) return _kCyan;
  return _kAvatarPalette[uid.hashCode.abs() % _kAvatarPalette.length];
}

String _initials(String? name) {
  final n = (name ?? '?').trim();
  if (n.isEmpty) return '?';
  final p = n.split(' ');
  return p.length >= 2
      ? '${p[0][0]}${p[1][0]}'.toUpperCase()
      : n[0].toUpperCase();
}

// ── Screen ──────────────────────────────────────────────────────────────────

class GlobalPanicLeaderboardScreen extends StatefulWidget {
  const GlobalPanicLeaderboardScreen({super.key, required this.service});
  final LeaderboardService service;
  @override
  State<GlobalPanicLeaderboardScreen> createState() =>
      _State();
}

class _State extends State<GlobalPanicLeaderboardScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bg =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))
        ..repeat();
  late final AnimationController _enter =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  late final Animation<double> _enterCurve =
      CurvedAnimation(parent: _enter, curve: Curves.easeOutExpo);

  Stream<LeaderboardSnapshot>? _stream;
  late Future<LeaderboardSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _loadData();
    _enter.forward();
  }

  void _loadData() {
    if (AppRuntimeConfig.leaderboardRealtimeEnabled) {
      _stream = widget.service.globalPanicLeaderboardStream(limit: 20);
      _future = Future.value(LeaderboardSnapshot(
          mode: 'global_panic', entries: const [], totalPlayers: 0, fetchedAt: DateTime.now()));
    } else {
      _future = widget.service.getGlobalPanicLeaderboard(limit: 20);
    }
  }

  Future<void> _refresh() async {
    setState(_loadData);
    _enter.forward(from: 0);
    if (!AppRuntimeConfig.leaderboardRealtimeEnabled) await _future;
  }

  @override
  void dispose() { _bg.dispose(); _enter.dispose(); super.dispose(); }

  Widget _body(BuildContext ctx, AsyncSnapshot<LeaderboardSnapshot> snap) {
    if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator(color: _kGold, strokeWidth: 2));
    }
    if (!snap.hasData || snap.data!.entries.isEmpty) {
      return _Empty(onRefresh: _refresh);
    }
    return _Board(data: snap.data!, enter: _enterCurve, onRefresh: _refresh);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.backgroundDark,
      body: Stack(fit: StackFit.expand, children: [
        AnimatedBuilder(
          animation: _bg,
          builder: (ctx, child) => CustomPaint(painter: _GridPainter(_bg.value)),
        ),
        SafeArea(child: Column(children: [
          _Header(onBack: Navigator.of(context).maybePop, onRefresh: _refresh),
          Expanded(
            child: AppRuntimeConfig.leaderboardRealtimeEnabled
                ? StreamBuilder<LeaderboardSnapshot>(stream: _stream, builder: _body)
                : FutureBuilder<LeaderboardSnapshot>(future: _future, builder: _body),
          ),
        ])),
      ]),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onRefresh});
  final VoidCallback onBack;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext ctx) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
    child: Row(children: [
      _NavBtn(icon: Icons.arrow_back_rounded, onTap: onBack),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(colors: [
            AppPalette.neonGreen, AppPalette.accentPurple,
          ]).createShader(r),
          child: const Text('GLOBAL PANIC',
              style: TextStyle(color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        ),
        Row(children: [
          Container(width: 6, height: 6,
              decoration: const BoxDecoration(color: AppPalette.neonGreen, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          const Text('LIVE · ARCADE RANKINGS',
              style: TextStyle(color: AppPalette.neonGreen, fontSize: 9,
                  fontWeight: FontWeight.w800, letterSpacing: 1.8)),
        ]),
      ])),
      _NavBtn(icon: Icons.refresh_rounded, onTap: () => unawaited(onRefresh())),
    ]),
  );
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, required this.onTap});
  final IconData icon; final VoidCallback onTap;
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42, height: 42,
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kCyan.withAlpha(80)),
        boxShadow: [BoxShadow(color: _kCyan.withAlpha(30), blurRadius: 8)],
      ),
      child: Icon(icon, color: AppPalette.textPrimary, size: 20),
    ),
  );
}

// ── Empty state ─────────────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  const _Empty({required this.onRefresh});
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext ctx) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.emoji_events_rounded, color: _kGold, size: 56),
    const SizedBox(height: 12),
    const Text('NO CHAMPIONS YET', style: TextStyle(
        color: AppPalette.textPrimary, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
    const SizedBox(height: 6),
    const Text('Clear stages to claim the throne',
        style: TextStyle(color: AppPalette.textMuted, fontSize: 13)),
    const SizedBox(height: 18),
    OutlinedButton.icon(
      onPressed: () => unawaited(onRefresh()),
      icon: const Icon(Icons.refresh_rounded, size: 16),
      label: const Text('REFRESH'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppPalette.neonGreen,
        side: const BorderSide(color: AppPalette.neonGreen),
      ),
    ),
  ]));
}

// ── Board ───────────────────────────────────────────────────────────────────

class _Board extends StatelessWidget {
  const _Board({required this.data, required this.enter, required this.onRefresh});
  final LeaderboardSnapshot data;
  final Animation<double> enter;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext ctx) {
    final top3 = data.entries.take(3).toList();
    final rest = data.entries.skip(3).toList();
    return RefreshIndicator(
      color: AppPalette.neonGreen,
      backgroundColor: AppPalette.surface,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _StatsBar(data: data)),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: enter,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(enter),
                child: _Podium(top3: top3, myRank: data.myRank),
              ),
            ),
          ),
          if (rest.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
                child: Row(children: [
                  Container(width: 3, height: 14,
                      decoration: BoxDecoration(color: AppPalette.accentPurple,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  const Text('RANKINGS',
                      style: TextStyle(color: AppPalette.textMuted, fontSize: 11,
                          fontWeight: FontWeight.w800, letterSpacing: 2)),
                ]),
              ),
            ),
            SliverList(delegate: SliverChildBuilderDelegate((ctx, i) {
              final e = rest[i];
              return AnimatedBuilder(
                animation: enter,
                builder: (ctx, child) => FadeTransition(
                  opacity: enter,
                  child: SlideTransition(
                    position: Tween(
                      begin: Offset(0, 0.2 + i * 0.04),
                      end: Offset.zero,
                    ).animate(enter),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                      child: _Row(entry: e, isMe: data.myRank != null && e.rank == data.myRank),
                    ),
                  ),
                ),
              );
            }, childCount: rest.length)),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }
}

// ── Stats bar ────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.data});
  final LeaderboardSnapshot data;
  @override
  Widget build(BuildContext ctx) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
    child: Row(children: [
      _Pill('PLAYERS', '${data.totalPlayers}', _kCyan),
      const SizedBox(width: 8),
      _Pill('YOUR RANK', data.myRank == null ? 'N/A' : '#${data.myRank}', _kGold),
      const SizedBox(width: 8),
      _Pill('STAGE', '${data.myMaxStage ?? 0}', AppPalette.accentPurple),
      const SizedBox(width: 8),
      _Pill('TROPHIES', '${data.myTotalTrophies ?? 0}', AppPalette.accentPink),
    ]),
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.value, this.color);
  final String label, value; final Color color;
  @override
  Widget build(BuildContext ctx) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(90)),
        boxShadow: [BoxShadow(color: color.withAlpha(25), blurRadius: 8)],
      ),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14, height: 1)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(color: color.withAlpha(180), fontWeight: FontWeight.w800,
            fontSize: 7, letterSpacing: 0.6), textAlign: TextAlign.center),
      ]),
    ),
  );
}

// ── Podium ───────────────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  const _Podium({required this.top3, required this.myRank});
  final List<LeaderboardEntry> top3; final int? myRank;

  @override
  Widget build(BuildContext ctx) {
    final first  = top3.isNotEmpty ? top3[0] : null;
    final second = top3.length > 1  ? top3[1] : null;
    final third  = top3.length > 2  ? top3[2] : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: _PCard(entry: second, rank: 2, h: 108,
            neon: _kSilver, isMe: myRank != null && second != null && second.rank == myRank)),
        const SizedBox(width: 8),
        Expanded(child: _PCard(entry: first, rank: 1, h: 154,
            neon: _kGold, isMe: myRank != null && first != null && first.rank == myRank)),
        const SizedBox(width: 8),
        Expanded(child: _PCard(entry: third, rank: 3, h: 82,
            neon: _kBronze, isMe: myRank != null && third != null && third.rank == myRank)),
      ]),
    );
  }
}

class _PCard extends StatelessWidget {
  const _PCard({required this.entry, required this.rank, required this.h,
      required this.neon, required this.isMe});
  final LeaderboardEntry? entry;
  final int rank; final double h; final Color neon; final bool isMe;

  @override
  Widget build(BuildContext ctx) {
    final ac = _uidColor(entry?.uid);
    final name = (entry?.displayName ?? '---').trim();
    final dName = name.isEmpty ? '---' : name;
    final sz = rank == 1 ? 66.0 : 52.0;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (rank == 1)
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text('👑', style: TextStyle(fontSize: 24)),
        )
      else const SizedBox(height: 30),

      // Avatar circle
      Container(
        width: sz, height: sz,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppPalette.surfaceAlt,
          border: Border.all(color: isMe ? Colors.white : neon, width: 2),
          boxShadow: [BoxShadow(color: neon.withAlpha(120), blurRadius: 16, spreadRadius: 1)],
        ),
        child: Center(child: Text(_initials(entry?.displayName),
            style: TextStyle(color: neon, fontWeight: FontWeight.w900,
                fontSize: rank == 1 ? 24 : 18))),
      ),
      const SizedBox(height: 6),

      Text(dName, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
          style: TextStyle(color: AppPalette.textPrimary, fontWeight: FontWeight.w900,
              fontSize: rank == 1 ? 13 : 11)),

      if (isMe) ...[
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: AppPalette.neonGreen, borderRadius: BorderRadius.circular(99)),
          child: const Text('YOU', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 8)),
        ),
      ],
      const SizedBox(height: 4),

      // Base
      Container(
        height: h,
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          border: Border(
            top: BorderSide(color: neon, width: 2),
            left: BorderSide(color: neon.withAlpha(80)),
            right: BorderSide(color: neon.withAlpha(80)),
          ),
          boxShadow: [BoxShadow(color: neon.withAlpha(60), blurRadius: 14, offset: const Offset(0, -2))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('#$rank',
              style: TextStyle(color: neon, fontWeight: FontWeight.w900,
                  fontSize: rank == 1 ? 26 : 18, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text('STG ${entry?.maxStage ?? 0}',
              style: const TextStyle(color: AppPalette.textMuted, fontWeight: FontWeight.w800, fontSize: 10)),
          Text('🏆 ${entry?.totalTrophies ?? 0}',
              style: TextStyle(color: ac, fontWeight: FontWeight.w700, fontSize: 10)),
        ]),
      ),
    ]);
  }
}

// ── Rank Row ─────────────────────────────────────────────────────────────────

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.isMe});
  final LeaderboardEntry entry; final bool isMe;

  @override
  Widget build(BuildContext ctx) {
    final ac = _uidColor(entry.uid);
    final name = (entry.displayName ?? 'Player').trim();
    final dName = name.isEmpty ? 'Player' : name;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? AppPalette.neonGreen.withAlpha(14) : AppPalette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? AppPalette.neonGreen.withAlpha(160) : AppPalette.borderSoft,
          width: isMe ? 1.4 : 1,
        ),
      ),
      child: Row(children: [
        // Rank badge
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppPalette.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppPalette.borderSoft),
          ),
          child: Center(child: Text('${entry.rank}',
              style: const TextStyle(color: AppPalette.textMuted,
                  fontWeight: FontWeight.w900, fontSize: 13))),
        ),
        const SizedBox(width: 10),
        // Avatar
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ac.withAlpha(22),
            border: Border.all(color: isMe ? AppPalette.neonGreen : ac.withAlpha(150)),
            boxShadow: [BoxShadow(color: ac.withAlpha(40), blurRadius: 6)],
          ),
          child: Center(child: Text(_initials(entry.displayName),
              style: TextStyle(color: isMe ? AppPalette.neonGreen : ac,
                  fontWeight: FontWeight.w900, fontSize: 13))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(dName, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: isMe ? AppPalette.neonGreen : AppPalette.textPrimary,
                    fontWeight: FontWeight.w900, fontSize: 14))),
            if (isMe)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: AppPalette.neonGreen,
                    borderRadius: BorderRadius.circular(99)),
                child: const Text('YOU',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 9)),
              ),
          ]),
          const SizedBox(height: 3),
          Row(children: [
            _Tag('STG ${entry.maxStage ?? 1}', AppPalette.accentPurple),
            const SizedBox(width: 6),
            _Tag('🏆 ${entry.totalTrophies ?? 0}', AppPalette.accentPink),
          ]),
        ])),
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color);
  final String label; final Color color;
  @override
  Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withAlpha(22),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withAlpha(100)),
    ),
    child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 10)),
  );
}

// ── Grid Background (matches landing screen style) ───────────────────────────

class _GridPainter extends CustomPainter {
  _GridPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // Base black
    canvas.drawRect(Offset.zero & size, Paint()..color = AppPalette.backgroundDark);

    final gridPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..strokeWidth = 0.8;

    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Animated neon scan line
    final scanY = ((t * size.height * 1.4) % (size.height * 1.4)) - size.height * 0.2;
    final scanPaint = Paint()
      ..shader = LinearGradient(colors: [
        Colors.transparent,
        AppPalette.accentPurple.withAlpha(40),
        AppPalette.neonGreen.withAlpha(30),
        Colors.transparent,
      ]).createShader(Rect.fromLTWH(0, scanY - 40, size.width, 80));
    canvas.drawRect(Rect.fromLTWH(0, scanY - 40, size.width, 80), scanPaint);

    // Corner glow — top right (matches landing)
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        AppPalette.accentPurple.withAlpha(50),
        Colors.transparent,
      ]).createShader(Rect.fromCenter(
          center: Offset(size.width, 0),
          width: size.width * 0.7, height: size.width * 0.7));
    canvas.drawRect(Offset.zero & size, glow);

    // Bottom-left neon green hint (matches landing)
    final glow2 = Paint()
      ..shader = RadialGradient(colors: [
        AppPalette.neonGreen.withAlpha(30),
        Colors.transparent,
      ]).createShader(Rect.fromCenter(
          center: Offset(0, size.height),
          width: size.width * 0.6, height: size.width * 0.6));
    canvas.drawRect(Offset.zero & size, glow2);
  }

  @override
  bool shouldRepaint(_GridPainter o) => o.t != t;
}
