import 'dart:math';

import 'package:flutter/material.dart';

import '../arcade_controller.dart';
import '../model/worlds.dart';
import '../progress_controller.dart';
import '../ui/kit.dart';
import '../ui/runner_preview.dart';
import 'flows.dart';

/// Five worlds of twenty stages, each a winding trail of stone medallions.
class WorldMapScreen extends StatefulWidget {
  const WorldMapScreen({this.focusStage, super.key});

  final int? focusStage;

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends State<WorldMapScreen> {
  int? _world;

  @override
  Widget build(BuildContext context) {
    final arcade = ArcadeScope.of(context);
    final progress = arcade.progress;
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) {
        final focus = widget.focusStage ?? progress.nextStage;
        final index = _world ?? Worlds.forStage(focus).index;
        final world = Worlds.all[index];
        final nightmare = world.twist == WorldTwist.crumbling || world.twist == WorldTwist.rage;
        Widget body({required bool wide}) => Column(
          children: [
            _WorldHeader(
              world: world,
              progress: progress,
              wide: wide,
              onPrev: index > 0 ? () => setState(() => _world = index - 1) : null,
              onNext: index < Worlds.all.length - 1 ? () => setState(() => _world = index + 1) : null,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StonePanel(
                blood: nightmare,
                glow: Color(world.accent),
                dim: 0.45,
                padding: EdgeInsets.zero,
                child: _StageTrail(world: world, progress: progress, columns: wide ? 5 : 4),
              ),
            ),
          ],
        );
        return MenuPage(
          title: 'World Map',
          souls: progress.souls,
          trailing: StatChip(
            icon: const FFIcon(FFGlyph.star, size: 22),
            text: '${progress.totalStars}/${progress.maxStars}',
          ),
          nightmare: nightmare,
          onBack: () => Navigator.of(context).pop(),
          body: body(wide: true),
          tallBody: body(wide: false),
        );
      },
    );
  }
}

class _WorldHeader extends StatelessWidget {
  const _WorldHeader({
    required this.world,
    required this.progress,
    required this.wide,
    this.onPrev,
    this.onNext,
  });

  final WorldInfo world;
  final ProgressController progress;
  final bool wide;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final unlocked = progress.isWorldUnlocked(world);
    final accent = Color(world.accent);
    return Row(
      children: [
        Opacity(
          opacity: onPrev == null ? 0.3 : 1,
          child: RoundButton(
            icon: const FFIcon(FFGlyph.back, size: 24),
            tooltip: 'Previous world',
            onPressed: onPrev,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!unlocked) ...[const FFIcon(FFGlyph.lock, size: 30), const SizedBox(width: 8)],
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'World ${world.number}: ${world.name}',
                        style: FF.title(wide ? 46 : 36, color: accent, glow: accent.withValues(alpha: 0.4)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                unlocked
                    ? '${world.twistText}  ·  ★ ${progress.starsInWorld(world)}/${Worlds.stagesPerWorld * 3}'
                    : 'Clear stage ${world.firstStage - 1} to open this world.',
                textAlign: TextAlign.center,
                style: FF.text(wide ? 17 : 14, color: FF.bone2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Opacity(
          opacity: onNext == null ? 0.3 : 1,
          child: RoundButton(
            icon: Transform.flip(flipX: true, child: const FFIcon(FFGlyph.back, size: 24)),
            tooltip: 'Next world',
            onPressed: onNext,
          ),
        ),
      ],
    );
  }
}

class _StageTrail extends StatelessWidget {
  const _StageTrail({required this.world, required this.progress, required this.columns});

  final WorldInfo world;
  final ProgressController progress;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final count = Worlds.stagesPerWorld;
        final rows = (count / columns).ceil();
        final cellW = box.maxWidth / columns;
        final cellH = box.maxHeight / rows;
        final node = min(cellW, cellH) * 0.56;
        final centers = <Offset>[];
        for (var i = 0; i < count; i++) {
          final row = i ~/ columns;
          final colInRow = i % columns;
          final col = row.isEven ? colInRow : columns - 1 - colInRow;
          final wiggle = sin(i * 1.7) * cellH * 0.08;
          centers.add(Offset((col + 0.5) * cellW, (row + 0.5) * cellH + wiggle));
        }
        final current = progress.nextStage;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _TrailPainter(
                  centers: centers,
                  litUpTo: (progress.highestCleared - world.firstStage + 1).clamp(-1, count - 1),
                  accent: Color(world.accent),
                ),
              ),
            ),
            for (var i = 0; i < count; i++)
              Positioned(
                left: centers[i].dx - node / 2,
                top: centers[i].dy - node / 2,
                width: node,
                height: node,
                child: _StageNode(
                  stage: world.firstStage + i,
                  stars: progress.starsFor(world.firstStage + i),
                  unlocked: progress.isUnlocked(world.firstStage + i),
                  current: world.firstStage + i == current,
                  size: node,
                  accent: Color(world.accent),
                ),
              ),
            if (world.contains(current))
              Positioned(
                left: centers[current - world.firstStage].dx - node * 0.42,
                top: centers[current - world.firstStage].dy - node * 1.32,
                child: IgnorePointer(
                  child: RunnerPreview(look: progress.look, size: node * 0.84, walking: false, turning: false, floor: false),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TrailPainter extends CustomPainter {
  _TrailPainter({required this.centers, required this.litUpTo, required this.accent});

  final List<Offset> centers;
  final int litUpTo;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < centers.length - 1; i++) {
      final a = centers[i];
      final b = centers[i + 1];
      final lit = i < litUpTo;
      final steps = ((b - a).distance / 14).floor();
      for (var s = 1; s < steps; s++) {
        final p = Offset.lerp(a, b, s / steps)!;
        canvas.drawCircle(p, lit ? 4.2 : 3.4, Paint()..color = const Color(0xFF16151F));
        canvas.drawCircle(
          p,
          lit ? 2.8 : 2,
          Paint()..color = lit ? accent : const Color(0xFF55627E),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrailPainter old) =>
      old.litUpTo != litUpTo || old.centers.length != centers.length || old.accent != accent;
}

class _StageNode extends StatefulWidget {
  const _StageNode({
    required this.stage,
    required this.stars,
    required this.unlocked,
    required this.current,
    required this.size,
    required this.accent,
  });

  final int stage;
  final int stars;
  final bool unlocked;
  final bool current;
  final double size;
  final Color accent;

  @override
  State<_StageNode> createState() => _StageNodeState();
}

class _StageNodeState extends State<_StageNode> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    if (widget.current) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _StageNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.current && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.current && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final gate = Worlds.isGate(widget.stage);
    final cleared = widget.stars > 0;
    final face = widget.current
        ? FF.amber
        : cleared
        ? FF.stone2
        : FF.slate;
    final medallion = AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: [Color.lerp(face, Colors.white, 0.25)!, face, Color.lerp(face, FF.ink, 0.5)!],
          ),
          border: Border.all(
            color: gate ? FF.gold : FF.ink,
            width: gate ? 4 : 3,
          ),
          boxShadow: [
            const BoxShadow(color: Color(0xAA000000), blurRadius: 8, offset: Offset(0, 4)),
            if (widget.current)
              BoxShadow(
                color: FF.amber.withValues(alpha: 0.35 + 0.35 * _pulse.value),
                blurRadius: 14 + 14 * _pulse.value,
                spreadRadius: 2 + 3 * _pulse.value,
              ),
          ],
        ),
        alignment: Alignment.center,
        child: child,
      ),
      child: !widget.unlocked
          ? FFIcon(FFGlyph.lock, size: s * 0.46)
          : gate && !cleared
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FF.art('icon_skull', size: s * 0.38),
                Text('${widget.stage}', style: FF.text(s * 0.2, weight: FontWeight.w700)),
              ],
            )
          : Text(
              '${widget.stage}',
              style: FF.text(
                s * 0.36,
                color: widget.current ? FF.ink : FF.bone,
                weight: FontWeight.w700,
                outline: !widget.current,
              ),
            ),
    );
    return MouseRegion(
      cursor: widget.unlocked ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () {
          if (!widget.unlocked) {
            Sfx.instance.play(Sound.denied, volume: 0.5);
            return;
          }
          Sfx.instance.play(Sound.click, volume: 0.6);
          openStage(context, widget.stage);
        },
        child: AnimatedScale(
          scale: _hover && widget.unlocked ? 1.08 : 1,
          duration: const Duration(milliseconds: 120),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Opacity(opacity: widget.unlocked ? 1 : 0.55, child: medallion),
              if (widget.unlocked && cleared)
                Positioned(
                  bottom: -s * 0.2,
                  child: StarRow(earned: widget.stars, size: s * 0.27, gap: 1),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
