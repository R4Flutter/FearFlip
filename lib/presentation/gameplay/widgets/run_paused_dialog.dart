import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_palette.dart';
import 'cyber_horror_ui_components.dart';

class RunPausedDialog extends StatefulWidget {
  const RunPausedDialog({
    required this.stage,
    required this.checkpoint,
    required this.nextCheckpoint,
    required this.checkpointText,
    required this.modeLabel,
    required this.timeRemainingLabel,
    required this.onResumePressed,
    required this.onExitPressed,
    super.key,
  });

  final int stage;
  final int checkpoint;
  final int nextCheckpoint;
  final String checkpointText;
  final String modeLabel;
  final String timeRemainingLabel;
  final VoidCallback onResumePressed;
  final Future<void> Function() onExitPressed;

  @override
  State<RunPausedDialog> createState() => _RunPausedDialogState();
}

class _RunPausedDialogState extends State<RunPausedDialog>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _entryController;
  late Animation<double> _glowPulse;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _glowPulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeInOut),
    );

    _scale = CurvedAnimation(
      parent: _entryController,
      curve: Curves.elasticOut,
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: FadeTransition(
        opacity: _entryController,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            const Positioned.fill(
              child: RealityGlassPanel(color: AppPalette.accentPurple),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HorrorHeader(
                    title: 'FEAR CYCLE',
                    subtitle: 'REALITY SHIFT IN STASIS',
                    icon: Icons.security_rounded,
                    color: AppPalette.accentPurple,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: HorrorStatBox(
                          label: 'STAGE',
                          value: '${widget.stage}',
                          color: AppPalette.accentPurple,
                          icon: Icons.layers_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: HorrorStatBox(
                          label: 'REMAINING',
                          value: widget.timeRemainingLabel,
                          color: AppPalette.neonGreen,
                          icon: Icons.timer_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  HorrorStatBox(
                    label: 'REALITY LAYER',
                    value: widget.modeLabel.toUpperCase(),
                    color: const Color(0xFF87ECFF),
                    isWide: true,
                  ),
                  const SizedBox(height: 32),
                  AnimatedBuilder(
                    animation: _glowPulse,
                    builder: (context, child) {
                      return Column(
                        children: [
                          Text(
                            'BREAK THE LOOP?',
                            style: TextStyle(
                              color: AppPalette.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              shadows: [
                                Shadow(
                                  color: AppPalette.neonGreen.withValues(alpha: _glowPulse.value),
                                  blurRadius: 15 * _glowPulse.value,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.checkpointText.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppPalette.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  FearButton(
                    label: 'RESUME SURVIVAL',
                    onPressed: widget.onResumePressed,
                    color: AppPalette.neonGreen,
                    isPrimary: true,
                  ),
                  const SizedBox(height: 12),
                  FearButton(
                    label: 'ABANDON RUN',
                    onPressed: () => unawaited(widget.onExitPressed()),
                    color: AppPalette.danger,
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
