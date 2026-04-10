import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

class AuthGateScreen extends StatefulWidget {
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
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;
  var _acceptedPolicy = false;

  bool get _actionsEnabled => _acceptedPolicy && !widget.isAuthenticating;

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

  void _onPolicyChanged(bool? checked) {
    if (widget.isAuthenticating) {
      return;
    }
    setState(() {
      _acceptedPolicy = checked ?? false;
    });
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
                    final topBreathingSpace = (constraints.maxHeight * 0.065)
                        .clamp(26.0, 62.0);
                    final signInSectionDrop = (constraints.maxHeight * 0.10)
                        .clamp(52.0, 110.0);
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 14 : 22,
                        topBreathingSpace,
                        compact ? 14 : 22,
                        36,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          key: const Key('auth_gate_root'),
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              compact ? 6 : 12,
                              12,
                              compact ? 6 : 12,
                              12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _GlitchWordmark(progress: progress),
                                SizedBox(height: signInSectionDrop),
                                _AuthActionButton(
                                  key: const Key('auth_google_button'),
                                  label: 'Continue with Google',
                                  sublabel:
                                      'Sync trophies, unlock backup recovery, and keep your identity secure',
                                  icon: Icons.login,
                                  color: AppPalette.neonGreen,
                                  foreground: Colors.black,
                                  enabled: _actionsEnabled,
                                  onPressed: widget.onGoogleSignIn,
                                ),
                                const SizedBox(height: 18),
                                _AuthActionButton(
                                  key: const Key('auth_guest_button'),
                                  label: 'Play as Guest',
                                  sublabel:
                                      'Launch instantly and optionally upgrade to Google account later',
                                  icon: Icons.videogame_asset,
                                  color: AppPalette.accentPink,
                                  foreground: Colors.black,
                                  enabled: _actionsEnabled,
                                  onPressed: widget.onGuestPlay,
                                ),
                                const SizedBox(height: 18),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppPalette.surfaceSoft,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppPalette.accentPurple,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Checkbox(
                                        key: const Key('auth_terms_checkbox'),
                                        value: _acceptedPolicy,
                                        onChanged: _onPolicyChanged,
                                        activeColor: AppPalette.neonGreen,
                                        checkColor: Colors.black,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 7,
                                          ),
                                          child: Text(
                                            'I agree to account sync and data storage required for cloud saves, ranking updates, and cross-device recovery.',
                                            style: TextStyle(
                                              color: AppPalette.textPrimary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: compact ? 12 : 13,
                                              height: 1.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _AuthStatusPanel(
                                  isAuthenticating: widget.isAuthenticating,
                                  errorMessage: widget.errorMessage,
                                  needsPolicyAcceptance: !_acceptedPolicy,
                                ),
                                const SizedBox(height: 32),
                              ],
                            ),
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

class _GlitchWordmark extends StatelessWidget {
  const _GlitchWordmark({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final fontSize = width < 400 ? 42.0 : 60.0;
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

class _AuthActionButton extends StatelessWidget {
  const _AuthActionButton({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
    required this.foreground,
    required this.enabled,
    required this.onPressed,
    super.key,
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

class _AuthStatusPanel extends StatelessWidget {
  const _AuthStatusPanel({
    required this.isAuthenticating,
    required this.errorMessage,
    required this.needsPolicyAcceptance,
  });

  final bool isAuthenticating;
  final String? errorMessage;
  final bool needsPolicyAcceptance;

  @override
  Widget build(BuildContext context) {
    if (isAuthenticating) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: AppPalette.surfaceSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppPalette.neonGreen),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Authenticating session...',
              style: TextStyle(
                color: AppPalette.neonGreen,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            SizedBox(height: 8),
            LinearProgressIndicator(
              minHeight: 4,
              color: AppPalette.neonGreen,
              backgroundColor: Color(0x22283238),
            ),
          ],
        ),
      );
    }

    final error = errorMessage?.trim();
    if (error != null && error.isNotEmpty) {
      return Container(
        key: const Key('auth_error_text'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x35FF3D3D),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x75FF6A6A)),
        ),
        child: Text(
          error,
          style: const TextStyle(
            color: Color(0xFFFFBBB0),
            fontWeight: FontWeight.w700,
            fontSize: 13,
            height: 1.25,
          ),
        ),
      );
    }

    if (needsPolicyAcceptance) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppPalette.surfaceSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppPalette.accentPink),
        ),
        child: const Text(
          'Accept the policy checkbox to continue with Google or Guest sign-in.',
          style: TextStyle(
            color: AppPalette.accentPink,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
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
