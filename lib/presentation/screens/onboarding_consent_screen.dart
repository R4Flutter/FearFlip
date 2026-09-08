import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/app_runtime_config.dart';
import '../../services/consent_service.dart';
import '../theme/app_palette.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OnboardingConsentScreen
//
// Shown exactly once per device (on first install, or after a policy version
// bump). The user must tick the agreement checkbox and tap "Accept & Continue"
// before the app proceeds to AuthGateScreen.
//
// On mobile, accepting automatically triggers the UMP / GDPR consent form so
// EEA users always see the ad-consent dialog without an extra step.
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingConsentScreen extends StatefulWidget {
  const OnboardingConsentScreen({
    required this.onAccepted,
    required this.onPrivacyPolicy,
    super.key,
  });

  /// Called after the user ticks the checkbox, taps "Accept & Continue", and
  /// UMP consent (if required) has been gathered.
  final VoidCallback onAccepted;

  /// Called when the user taps the Privacy Policy / Terms link.
  final VoidCallback onPrivacyPolicy;

  @override
  State<OnboardingConsentScreen> createState() =>
      _OnboardingConsentScreenState();
}

class _OnboardingConsentScreenState extends State<OnboardingConsentScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;
  bool _agreed = false;
  bool _isBusy = false;

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

  Future<void> _onAccept() async {
    if (!_agreed || _isBusy) return;
    setState(() => _isBusy = true);

    // Trigger UMP / GDPR ad consent automatically (Option A).
    // On non-EEA devices the UMP SDK returns immediately.
    if (AppRuntimeConfig.supportsMobileAds) {
      try {
        await ConsentService.instance
            .gatherConsentAndInitializeAds()
            .timeout(const Duration(seconds: 20));
      } catch (_) {
        // Non-fatal — consent failures are handled inside ConsentService.
        // We still let the user proceed.
      }
    }

    if (!mounted) return;
    setState(() => _isBusy = false);
    widget.onAccepted();
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
              // Animated grid glitch background
              CustomPaint(painter: _GridGlitchPainter(progress: progress)),
              // Ambient glow orb
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
                    final h = constraints.maxHeight;

                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 14 : 24,
                        (h * 0.05).clamp(18.0, 48.0),
                        compact ? 14 : 24,
                        28,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── Header ────────────────────────────────────
                              _GlitchWordmark(progress: progress),
                              const SizedBox(height: 10),
                              Center(
                                child: Text(
                                  'BEFORE YOU PLAY',
                                  style: TextStyle(
                                    color: AppPalette.neonGreen
                                        .withAlpha(220),
                                    fontWeight: FontWeight.w900,
                                    fontSize: compact ? 12 : 14,
                                    letterSpacing: 3.2,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: (h * 0.035).clamp(14.0, 30.0),
                              ),

                              // ── Disclosure cards ──────────────────────────
                              _DisclosureCard(
                                icon: Icons.shield_rounded,
                                accent: AppPalette.neonGreen,
                                title: 'Privacy & Data',
                                body:
                                    'FearFlip uses Firebase to authenticate your account, sync your '
                                    'cloud saves, and track stage progress across devices. Firebase '
                                    'Analytics and Crashlytics collect anonymous usage and crash data '
                                    'to help us improve the game. No personal data is sold to third parties.',
                              ),
                              const SizedBox(height: 10),
                              _DisclosureCard(
                                icon: Icons.campaign_rounded,
                                accent: AppPalette.accentPurple,
                                title: 'Advertising',
                                body:
                                    'Free gameplay is supported by ads from Unity Ads and Google AdMob. '
                                    'These networks may use your Advertising ID to show relevant ads. '
                                    'You can manage ad preferences at any time via Settings → Privacy & Consent. '
                                    'Remove Ads is available as a one-time purchase.',
                              ),
                              const SizedBox(height: 10),
                              _DisclosureCard(
                                icon: Icons.gavel_rounded,
                                accent: AppPalette.accentPink,
                                title: 'Terms of Service',
                                body:
                                    'By playing FearFlip you agree to our Terms of Service and Privacy Policy. '
                                    'In-app purchases are non-refundable unless required by law. '
                                    'Leaderboard data is public. You must be 13+ (16+ in the EU) to play.',
                              ),
                              const SizedBox(height: 18),

                              // ── Policy links ──────────────────────────────
                              Center(
                                child: GestureDetector(
                                  onTap: widget.onPrivacyPolicy,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.open_in_new_rounded,
                                        size: 13,
                                        color: AppPalette.accentPurple
                                            .withAlpha(200),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Read full Privacy Policy & Terms',
                                        style: TextStyle(
                                          color: AppPalette.accentPurple
                                              .withAlpha(200),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          decoration:
                                              TextDecoration.underline,
                                          decorationColor:
                                              AppPalette.accentPurple
                                                  .withAlpha(120),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),

                              // ── Checkbox agreement ────────────────────────
                              Container(
                                decoration: BoxDecoration(
                                  color: AppPalette.surfaceSoft,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _agreed
                                        ? AppPalette.neonGreen.withAlpha(180)
                                        : AppPalette.accentPurple,
                                    width: 1.4,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      key: const Key(
                                        'onboarding_terms_checkbox',
                                      ),
                                      value: _agreed,
                                      onChanged: _isBusy
                                          ? null
                                          : (v) => setState(
                                                () => _agreed = v ?? false,
                                              ),
                                      activeColor: AppPalette.neonGreen,
                                      checkColor: Colors.black,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8,
                                        ),
                                        child: RichText(
                                          text: TextSpan(
                                            style: TextStyle(
                                              color: AppPalette.textPrimary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: compact ? 12 : 13,
                                              height: 1.35,
                                            ),
                                            children: const [
                                              TextSpan(
                                                text:
                                                    'I have read and agree to the ',
                                              ),
                                              TextSpan(
                                                text: 'Privacy Policy',
                                                style: TextStyle(
                                                  color:
                                                      AppPalette.accentPurple,
                                                  fontWeight: FontWeight.w800,
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                              ),
                                              TextSpan(text: ' and '),
                                              TextSpan(
                                                text: 'Terms of Service',
                                                style: TextStyle(
                                                  color:
                                                      AppPalette.accentPurple,
                                                  fontWeight: FontWeight.w800,
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                              ),
                                              TextSpan(
                                                text:
                                                    ', and consent to data collection and advertising as described above.',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),

                              // ── Accept button ─────────────────────────────
                              ElevatedButton(
                                key: const Key(
                                  'onboarding_accept_button',
                                ),
                                onPressed:
                                    (_agreed && !_isBusy) ? _onAccept : null,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(58),
                                  elevation: 0,
                                  backgroundColor: AppPalette.neonGreen,
                                  foregroundColor: Colors.black,
                                  disabledBackgroundColor:
                                      AppPalette.neonGreen.withAlpha(90),
                                  disabledForegroundColor:
                                      Colors.black.withAlpha(100),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(0),
                                  ),
                                ),
                                child: _isBusy
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.black,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 20,
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            'ACCEPT & CONTINUE',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),

                              // ── Hint when checkbox not ticked ─────────────
                              if (!_agreed && !_isBusy) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppPalette.surfaceSoft,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppPalette.accentPink,
                                    ),
                                  ),
                                  child: const Text(
                                    'Please read the disclosures above and tick the checkbox to continue.',
                                    style: TextStyle(
                                      color: AppPalette.accentPink,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                            ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _DisclosureCard extends StatelessWidget {
  const _DisclosureCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppPalette.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withAlpha(140)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withAlpha(18), AppPalette.surfaceSoft],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withAlpha(22),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: accent.withAlpha(120)),
            ),
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlitchWordmark extends StatelessWidget {
  const _GlitchWordmark({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final fontSize = width < 400 ? 42.0 : 58.0;
    final driftX = math.sin(progress * math.pi * 14) * 2.4;
    final driftY = math.cos(progress * math.pi * 22) * 1.6;

    Text layer(Color color) => Text(
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

    final glitchPaint = Paint()
      ..color = AppPalette.accentPurple.withAlpha(80);
    for (var i = 0; i < 6; i++) {
      final wave = progress * math.pi * (8 + i * 2.4);
      final top =
          (size.height * (0.12 + 0.14 * i) + math.sin(wave) * 17).clamp(
        0.0,
        size.height - 4,
      );
      final left =
          (size.width * (0.08 + i * 0.03) + math.cos(wave * 1.3) * 26)
              .clamp(0.0, size.width - 100);
      final w = (size.width * (0.23 + i * 0.05)).clamp(88.0, size.width - left);
      canvas.drawRect(
        Rect.fromLTWH(left.toDouble(), top.toDouble(), w.toDouble(), 3),
        glitchPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridGlitchPainter old) =>
      old.progress != progress;
}
