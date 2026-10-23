import 'package:flutter/material.dart';

import '../gameplay/widgets/cyber_horror_ui_components.dart';
import '../theme/night_hud.dart';

/// Offered once, after a guest's first stage clear: sign in with Google to
/// keep the progress, or carry on as a guest. It replaces the sign-in screen
/// that used to stand before the first maze.
class SaveProgressDialog extends StatefulWidget {
  const SaveProgressDialog({
    required this.onSignIn,
    required this.onClose,
    super.key,
  });

  static const signInKey = ValueKey<String>('save_progress_sign_in');
  static const laterKey = ValueKey<String>('save_progress_later');

  /// Signs in; resolves null on success, else the error to show ('' when the
  /// player cancelled the account picker).
  final Future<String?> Function() onSignIn;

  /// Closes the offer (after a sign-in, or LATER).
  final VoidCallback onClose;

  @override
  State<SaveProgressDialog> createState() => _SaveProgressDialogState();
}

class _SaveProgressDialogState extends State<SaveProgressDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onSignIn();
    if (!mounted) return;
    if (error == null) {
      setState(() => _busy = false);
      widget.onClose();
      return;
    }
    setState(() {
      _busy = false;
      _error = error.isEmpty ? null : error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 440,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: RealityGlassPanel(color: NightHud.amber),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const HorrorHeader(
                            title: 'SAVE YOUR RUN',
                            subtitle: 'YOU ARE PLAYING AS A GUEST',
                            icon: Icons.save_rounded,
                            color: NightHud.amber,
                            emblem: 'flag',
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Sign in with Google to keep your trophies, '
                            'stages and leaderboard rank, on this phone and '
                            'any other.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: NightHud.bone,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: NightHud.blood,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FearButton(
                            key: SaveProgressDialog.signInKey,
                            label: _busy
                                ? 'SIGNING IN...'
                                : 'SIGN IN WITH GOOGLE',
                            onPressed: () => _signIn(),
                            color: NightHud.amber,
                            isPrimary: true,
                          ),
                          const SizedBox(height: 12),
                          FearButton(
                            key: SaveProgressDialog.laterKey,
                            label: 'LATER',
                            onPressed: () {
                              if (!_busy) widget.onClose();
                            },
                            color: NightHud.boneDim,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
