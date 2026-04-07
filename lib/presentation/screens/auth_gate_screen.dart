import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

class AuthGateScreen extends StatelessWidget {
  const AuthGateScreen({
    required this.isAuthenticating,
    required this.onGoogleSignIn,
    required this.onGuestPlay,
    this.errorMessage,
    super.key,
  });

  final bool isAuthenticating;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onGuestPlay;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppPalette.backgroundLight, AppPalette.backgroundDark],
          stops: [0.5, 0.5],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 22,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppPalette.accentPink,
                    width: 1.3,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x59E85BDA),
                      blurRadius: 24,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'FEARFLIP',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppPalette.accentPurple,
                        fontSize: 54,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in to sync progress and leaderboards',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppPalette.textMuted,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _AuthActionButton(
                      label: 'Continue with Google',
                      icon: Icons.g_mobiledata_rounded,
                      color: AppPalette.accentPink,
                      foreground: Colors.black,
                      enabled: !isAuthenticating,
                      onPressed: onGoogleSignIn,
                    ),
                    const SizedBox(height: 12),
                    _AuthActionButton(
                      label: 'Play as Guest',
                      icon: Icons.person_outline,
                      color: AppPalette.surfaceAlt,
                      foreground: AppPalette.textPrimary,
                      enabled: !isAuthenticating,
                      onPressed: onGuestPlay,
                    ),
                    const SizedBox(height: 14),
                    if (isAuthenticating)
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Authenticating...',
                            style: TextStyle(
                              color: AppPalette.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    else
                      const SizedBox(height: 16),
                    if (errorMessage != null && errorMessage!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppPalette.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      const Text(
                        'Tip: For Android Google login, add SHA-1 and SHA-256 in Firebase app settings and refresh FlutterFire config.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppPalette.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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

class _AuthActionButton extends StatelessWidget {
  const _AuthActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.foreground,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color foreground;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 28),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 19,
            letterSpacing: 0.5,
          ),
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: foreground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
