import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_palette.dart';
import 'cyber_horror_ui_components.dart';

class RunFailedDialog extends StatefulWidget {
  const RunFailedDialog({
    required this.stage,
    required this.maxStage,
    required this.escapePercent,
    required this.checkpointText,
    required this.modeLabel,
    required this.timeRemainingLabel,
    required this.lossReason,
    required this.comebackHook,
    required this.lostByTime,
    required this.lostByTrap,
    required this.trapDeathQuote,
    required this.adActionInProgress,
    required this.onRevivePressed,
    required this.onRestartPressed,
    /// Lives left in this checkpoint band. -1 = unlimited (stages 1–25).
    this.livesRemaining = -1,
    /// Max lives in the band. 0 when unlimited.
    this.maxLives = 0,
    super.key,
  });

  final int stage;
  final int maxStage;
  final int escapePercent;
  final String checkpointText;
  final String modeLabel;
  final String timeRemainingLabel;
  final String lossReason;
  final String comebackHook;
  final bool lostByTime;
  final bool lostByTrap;
  final String? trapDeathQuote;
  final bool adActionInProgress;
  final int livesRemaining;
  final int maxLives;
  final Future<void> Function() onRevivePressed;
  final Future<void> Function() onRestartPressed;

  /// True when the band has a life cap AND no lives remain.
  bool get _livesExhausted =>
      livesRemaining >= 0 && maxLives > 0 && livesRemaining <= 0;

  /// True when lives are capped (stage > 25).
  bool get _showLives => livesRemaining >= 0 && maxLives > 0;

  @override
  State<RunFailedDialog> createState() => _RunFailedDialogState();
}

class _RunFailedDialogState extends State<RunFailedDialog>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _entryController;
  late Animation<double> _pulse;

  static const Color _kHeartFull = Color(0xFFFF3D8B);
  static const Color _kHeartEmpty = Color(0x44FF3D8B);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _pulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  // ── Hearts row ─────────────────────────────────────────────────────────────

  Widget _buildHeartsRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget._livesExhausted ? 'NO REVIVES LEFT' : 'REVIVES REMAINING',
            style: TextStyle(
              color: widget._livesExhausted
                  ? AppPalette.danger
                  : _kHeartFull.withValues(alpha: 0.85),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(widget.maxLives, (i) {
              final isFilled = i < widget.livesRemaining;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Icon(
                  isFilled
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFilled ? _kHeartFull : _kHeartEmpty,
                  size: widget.maxLives <= 3 ? 22 : 18,
                  shadows: isFilled
                      ? [
                          Shadow(
                            color: _kHeartFull.withValues(alpha: 0.6),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Revive button ──────────────────────────────────────────────────────────

  String _reviveLabel() {
    if (widget.adActionInProgress) return 'RE-LINKING...';
    if (widget._livesExhausted) return 'NO REVIVES LEFT';
    return 'EMERGENCY REVIVE';
  }

  Color _reviveColor() {
    if (widget._livesExhausted) return const Color(0xFF555555);
    return AppPalette.neonGreen;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final criticalColor = widget.lostByTrap
        ? const Color(0xFFFF4D4D)
        : (widget.lostByTime ? AppPalette.danger : const Color(0xFFFF6B6B));

    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _entryController,
        curve: Curves.elasticOut,
      ),
      child: FadeTransition(
        opacity: _entryController,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: RealityGlassPanel(color: criticalColor),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ────────────────────────────────────────────────
                  HorrorHeader(
                    title: 'DEATH GRIP',
                    subtitle: widget.lossReason.toUpperCase(),
                    icon: Icons.dangerous_rounded,
                    color: criticalColor,
                  ),
                  const SizedBox(height: 24),

                  // ── Stats ─────────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: HorrorStatBox(
                          label: 'LAST SECTOR',
                          value: '${widget.stage}',
                          color: criticalColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: HorrorStatBox(
                          label: 'PERSONAL BEST',
                          value: '${widget.maxStage}',
                          color: AppPalette.accentPurple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  HorrorStatBox(
                    label: 'SURVIVAL PERCENT',
                    value: '${widget.escapePercent}%',
                    color: AppPalette.neonGreen,
                    isWide: true,
                  ),
                  const SizedBox(height: 20),

                  // ── Hearts row (only for limited bands) ───────────────────
                  if (widget._showLives) _buildHeartsRow(),

                  // ── Death text / quote ────────────────────────────────────
                  if (widget.trapDeathQuote != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        border: Border.all(
                          color: criticalColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '"${widget.trapDeathQuote}"',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppPalette.textPrimary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, child) {
                        return Text(
                          'CYCLE TERMINATED',
                          style: TextStyle(
                            color: criticalColor,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            shadows: [
                              Shadow(
                                color: criticalColor.withValues(
                                  alpha: _pulse.value * 0.8,
                                ),
                                blurRadius: 12 * _pulse.value,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 16),

                  // ── Revive button ─────────────────────────────────────────
                  // When lives are exhausted the button is visually muted;
                  // tapping it triggers a checkpoint restart via the
                  // _onReviveFromLoss guard in game_screen.dart.
                  FearButton(
                    label: _reviveLabel(),
                    onPressed: widget._livesExhausted
                        ? widget.onRestartPressed
                        : widget.onRevivePressed,
                    color: _reviveColor(),
                    isPrimary: !widget._livesExhausted,
                  ),
                  const SizedBox(height: 12),

                  // ── Checkpoint restart button ─────────────────────────────
                  FearButton(
                    label: widget.adActionInProgress
                        ? 'RESETTING...'
                        : 'CHECKPOINT RESTART',
                    onPressed: widget.onRestartPressed,
                    color: AppPalette.accentPink,
                  ),
                ],
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}
