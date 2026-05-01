import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_runtime_config.dart';
import '../../services/leaderboard_service.dart';
import '../theme/app_palette.dart';

// ── Palette ─────────────────────────────────────────────────────────────────
const _kGold   = Color(0xFFFFD700);
const _kSilver = Color(0xFFA8C0D6);
const _kBronze = Color(0xFFCD7F32);
const _kCyan   = Color(0xFF4DEFFF);

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

Color _rankNeon(int rank) {
  if (rank == 1) return _kGold;
  if (rank == 2) return _kSilver;
  return _kBronze;
}

// ── Screen ──────────────────────────────────────────────────────────────────

class GlobalPanicLeaderboardScreen extends StatefulWidget {
  const GlobalPanicLeaderboardScreen({super.key, required this.service});
  final LeaderboardService service;
  @override
  State<GlobalPanicLeaderboardScreen> createState() => _State();
}

class _State extends State<GlobalPanicLeaderboardScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bg =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))
        ..repeat();
  late final AnimationController _enter =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final Animation<double> _curve =
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
          mode: 'global_panic', entries: const [],
          totalPlayers: 0, fetchedAt: DateTime.now()));
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
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.emoji_events_rounded, color: _kGold, size: 56),
        const SizedBox(height: 12),
        const Text('NO CHAMPIONS YET', style: TextStyle(
            color: AppPalette.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 6),
        const Text('Clear stages to claim the throne',
            style: TextStyle(color: AppPalette.textMuted, fontSize: 13)),
      ]));
    }
    return _Board(data: snap.data!, anim: _curve, onRefresh: _refresh);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.backgroundDark,
      body: Stack(fit: StackFit.expand, children: [
        AnimatedBuilder(
          animation: _bg,
          builder: (_, _) => CustomPaint(painter: _GridPainter(_bg.value)),
        ),
        SafeArea(child: Column(children: [
          // Header — no refresh button
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(children: [
              _BackBtn(onTap: Navigator.of(context).maybePop),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(colors: [
                    AppPalette.neonGreen, AppPalette.accentPurple,
                  ]).createShader(r),
                  child: const Text('Leaderboard',
                      style: TextStyle(color: Colors.white, fontSize: 22,
                          fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                ),
                Row(children: [
                  Container(width: 6, height: 6,
                      decoration: const BoxDecoration(
                          color: AppPalette.neonGreen, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  const Text('LIVE · GLOBAL PANIC',
                      style: TextStyle(color: AppPalette.neonGreen, fontSize: 9,
                          fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                ]),
              ])),
            ]),
          ),
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

class _BackBtn extends StatelessWidget {
  const _BackBtn({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42, height: 42,
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppPalette.borderSoft),
      ),
      child: const Icon(Icons.arrow_back_rounded, color: AppPalette.textPrimary, size: 20),
    ),
  );
}

// ── Board ────────────────────────────────────────────────────────────────────

class _Board extends StatelessWidget {
  const _Board({required this.data, required this.anim, required this.onRefresh});
  final LeaderboardSnapshot data;
  final Animation<double> anim;
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
          // Podium
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(anim),
                child: _Podium(top3: top3, myRank: data.myRank),
              ),
            ),
          ),
          // Divider
          if (rest.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                child: Container(height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.transparent,
                        AppPalette.borderSoft,
                        Colors.transparent,
                      ]),
                    )),
              ),
            ),
          // List
          SliverList(delegate: SliverChildBuilderDelegate((ctx, i) {
            final e = rest[i];
            final isMe = data.myRank != null && e.rank == data.myRank;
            final delay = (0.06 * i).clamp(0.0, 0.3);
            final itemAnim = CurvedAnimation(
              parent: anim,
              curve: Interval(delay, 1.0, curve: Curves.easeOutCubic),
            );
            return FadeTransition(
              opacity: itemAnim,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(itemAnim),
                child: _ListRow(entry: e, isMe: isMe),
              ),
            );
          }, childCount: rest.length)),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }
}

// ── Podium ───────────────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  const _Podium({required this.top3, required this.myRank});
  final List<LeaderboardEntry> top3;
  final int? myRank;

  @override
  Widget build(BuildContext ctx) {
    final first  = top3.isNotEmpty ? top3[0] : null;
    final second = top3.length > 1 ? top3[1] : null;
    final third  = top3.length > 2 ? top3[2] : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: SizedBox(
        height: 260,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // #2 — left, medium height
          Expanded(child: Padding(
            padding: const EdgeInsets.only(top: 46),
            child: _PodiumSlot(entry: second, rank: 2,
                isMe: myRank != null && second?.rank == myRank),
          )),
          const SizedBox(width: 6),
          // #1 — center, tallest
          Expanded(child: _PodiumSlot(entry: first, rank: 1,
              isMe: myRank != null && first?.rank == myRank)),
          const SizedBox(width: 6),
          // #3 — right, shortest
          Expanded(child: Padding(
            padding: const EdgeInsets.only(top: 66),
            child: _PodiumSlot(entry: third, rank: 3,
                isMe: myRank != null && third?.rank == myRank),
          )),
        ]),
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({required this.entry, required this.rank, required this.isMe});
  final LeaderboardEntry? entry;
  final int rank;
  final bool isMe;

  @override
  Widget build(BuildContext ctx) {
    final neon = _rankNeon(rank);
    final ac = _uidColor(entry?.uid);
    final name = (entry?.displayName ?? '---').trim();
    final dName = name.isEmpty ? '---' : name;
    final avatarSize = rank == 1 ? 72.0 : 56.0;
    final trophies = entry?.totalTrophies ?? 0;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Crown for #1
      if (rank == 1)
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text('👑', style: TextStyle(fontSize: 26)),
        )
      else
        const SizedBox(height: 30),

      // Avatar with colored ring
      Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Glow behind avatar
          Container(
            width: avatarSize + 8, height: avatarSize + 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: neon.withAlpha(80), blurRadius: 20, spreadRadius: 2),
              ],
            ),
          ),
          // Avatar circle
          Container(
            width: avatarSize, height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ac.withAlpha(40), ac.withAlpha(18)],
              ),
              border: Border.all(color: neon, width: rank == 1 ? 3 : 2.5),
            ),
            child: Center(
              child: Text(_initials(entry?.displayName),
                  style: TextStyle(
                      color: ac,
                      fontWeight: FontWeight.w900,
                      fontSize: rank == 1 ? 26 : 20)),
            ),
          ),
          // Rank badge — bottom of avatar
          Positioned(
            bottom: -6,
            child: Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: neon,
                border: Border.all(color: const Color(0xFF0A0E1A), width: 2),
              ),
              child: Center(
                child: Text('$rank',
                    style: const TextStyle(color: Colors.black,
                        fontWeight: FontWeight.w900, fontSize: 11)),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),

      // Name
      Text(dName, maxLines: 1, overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: isMe ? AppPalette.neonGreen : AppPalette.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: rank == 1 ? 14 : 12)),
      const SizedBox(height: 2),

      // Score
      Text('🏆 $trophies',
          style: TextStyle(color: AppPalette.textMuted,
              fontWeight: FontWeight.w700, fontSize: 12)),

      if (isMe) ...[
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: AppPalette.neonGreen, borderRadius: BorderRadius.circular(99)),
          child: const Text('YOU',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 8)),
        ),
      ],
    ]);
  }
}

// ── List Row ─────────────────────────────────────────────────────────────────

class _ListRow extends StatelessWidget {
  const _ListRow({required this.entry, required this.isMe});
  final LeaderboardEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext ctx) {
    final ac = _uidColor(entry.uid);
    final name = (entry.displayName ?? 'Player').trim();
    final dName = name.isEmpty ? 'Player' : name;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isMe
              ? AppPalette.neonGreen.withAlpha(12)
              : const Color(0xFF111628),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMe
                ? AppPalette.neonGreen.withAlpha(140)
                : const Color(0xFF1E2340),
          ),
        ),
        child: Row(children: [
          // Rank number
          SizedBox(
            width: 28,
            child: Text('${entry.rank}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: isMe ? AppPalette.neonGreen : AppPalette.textMuted,
                    fontWeight: FontWeight.w900, fontSize: 14)),
          ),
          const SizedBox(width: 12),
          // Avatar
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ac.withAlpha(35), ac.withAlpha(14)],
              ),
              border: Border.all(
                  color: isMe ? AppPalette.neonGreen : ac.withAlpha(140)),
            ),
            child: Center(
              child: Text(_initials(entry.displayName),
                  style: TextStyle(
                      color: isMe ? AppPalette.neonGreen : ac,
                      fontWeight: FontWeight.w900, fontSize: 14)),
            ),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(dName, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: isMe ? AppPalette.neonGreen : AppPalette.textPrimary,
                            fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                  if (isMe)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppPalette.neonGreen,
                          borderRadius: BorderRadius.circular(99)),
                      child: const Text('YOU',
                          style: TextStyle(color: Colors.black,
                              fontWeight: FontWeight.w900, fontSize: 8)),
                    ),
                ]),
                const SizedBox(height: 2),
                Text('Stage ${entry.maxStage ?? 1}',
                    style: const TextStyle(color: AppPalette.textMuted,
                        fontWeight: FontWeight.w600, fontSize: 11)),
              ],
            ),
          ),
          // Trophy count — right side
          Text('${entry.totalTrophies ?? 0}',
              style: TextStyle(
                  color: isMe ? AppPalette.neonGreen : AppPalette.textPrimary,
                  fontWeight: FontWeight.w900, fontSize: 16)),
        ]),
      ),
    );
  }
}

// ── Grid Background ──────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  _GridPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size,
        Paint()..color = const Color(0xFF080C18));

    final p = Paint()
      ..color = const Color(0xFF141832)
      ..strokeWidth = 0.6;
    const step = 34.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }

    // Sweep scan line
    final scanY = ((t * size.height * 1.4) % (size.height * 1.4)) - size.height * 0.2;
    canvas.drawRect(
      Rect.fromLTWH(0, scanY - 30, size.width, 60),
      Paint()..shader = LinearGradient(colors: [
        Colors.transparent,
        AppPalette.accentPurple.withAlpha(28),
        AppPalette.neonGreen.withAlpha(18),
        Colors.transparent,
      ]).createShader(Rect.fromLTWH(0, scanY - 30, size.width, 60)),
    );

    // Top-right purple glow
    canvas.drawRect(Offset.zero & size, Paint()
      ..shader = RadialGradient(colors: [
        AppPalette.accentPurple.withAlpha(44),
        Colors.transparent,
      ]).createShader(Rect.fromCenter(
          center: Offset(size.width * 0.85, size.height * 0.08),
          width: size.width * 0.7, height: size.width * 0.7)));

    // Bottom-left green glow
    canvas.drawRect(Offset.zero & size, Paint()
      ..shader = RadialGradient(colors: [
        AppPalette.neonGreen.withAlpha(22),
        Colors.transparent,
      ]).createShader(Rect.fromCenter(
          center: Offset(size.width * 0.15, size.height * 0.92),
          width: size.width * 0.55, height: size.width * 0.55)));
  }

  @override
  bool shouldRepaint(_GridPainter o) => o.t != t;
}
