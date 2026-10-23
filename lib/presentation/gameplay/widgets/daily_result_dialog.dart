import 'package:flutter/material.dart';

import '../../../game/daily/daily_nightmare.dart';
import '../../theme/night_hud.dart';
import 'cyber_horror_ui_components.dart';

/// The Daily Nightmare escape screen: the time, the streak, the share text
/// as it will be sent, and SHARE / PLAY AGAIN / MENU.
class DailyResultDialog extends StatefulWidget {
  const DailyResultDialog({
    required this.summary,
    required this.onShare,
    required this.onPlayAgain,
    required this.onMenu,
    super.key,
  });

  static const shareKey = ValueKey<String>('daily_share');

  final DailySummary summary;

  /// Shares the text; resolves true when a share sheet opened, false when it
  /// was copied to the clipboard instead.
  final Future<bool> Function() onShare;
  final VoidCallback onPlayAgain;
  final VoidCallback onMenu;

  @override
  State<DailyResultDialog> createState() => _DailyResultDialogState();
}

class _DailyResultDialogState extends State<DailyResultDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();
  String? _shareFeedback;
  bool _sharing = false;

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    var label = 'SHARE FAILED';
    try {
      label = await widget.onShare() ? 'SHARED' : 'COPIED TO CLIPBOARD';
    } catch (_) {
      label = 'SHARE FAILED';
    }
    if (!mounted) return;
    setState(() {
      _sharing = false;
      _shareFeedback = label;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    return ScaleTransition(
      scale: CurvedAnimation(parent: _entry, curve: Curves.easeOutBack),
      child: FadeTransition(
        opacity: _entry,
        child: Stack(
          children: [
            const Positioned.fill(
              child: RealityGlassPanel(color: NightHud.gold),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HorrorHeader(
                    title: 'ESCAPED',
                    subtitle: 'DAILY NIGHTMARE #${s.number}',
                    icon: Icons.emoji_events_rounded,
                    color: NightHud.gold,
                    emblem: 'trophy',
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: HorrorStatBox(
                          label: 'TIME',
                          value: formatRunTime(s.seconds),
                          color: NightHud.gold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: HorrorStatBox(
                          label: 'BEST TODAY',
                          value: formatRunTime(s.bestSeconds),
                          color: NightHud.amber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: HorrorStatBox(
                          label: 'STREAK',
                          value: '${s.streak} DAY${s.streak == 1 ? '' : 'S'}',
                          color: NightHud.blood,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: HorrorStatBox(
                          label: 'FREEZES',
                          value: '${s.freezes}',
                          color: NightHud.spirit,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // The text exactly as it will be shared.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      border: Border.all(
                        color: NightHud.boneDim.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      s.shareText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: NightHud.bone,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FearButton(
                    key: DailyResultDialog.shareKey,
                    label: _sharing
                        ? 'SHARING...'
                        : (_shareFeedback ?? 'SHARE RESULT'),
                    onPressed: () => _share(),
                    color: NightHud.gold,
                    isPrimary: true,
                  ),
                  const SizedBox(height: 12),
                  FearButton(
                    label: 'PLAY AGAIN',
                    onPressed: widget.onPlayAgain,
                    color: NightHud.amber,
                  ),
                  const SizedBox(height: 12),
                  FearButton(
                    label: 'MENU',
                    onPressed: widget.onMenu,
                    color: NightHud.boneDim,
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
