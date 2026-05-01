import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_palette.dart';

// ─── Data ─────────────────────────────────────────────────────────────────

const _kEffectiveDate = 'May 1, 2026';
const _kContactEmail  = 'privacy@fearflipgame.com';
const _kAppName        = 'FearFlip';
const _kDeveloper      = 'FearFlip Studios';

const _kSections = <_Section>[
  _Section(
    icon: Icons.info_outline_rounded,
    title: '1. Overview',
    body:
        '$_kAppName ("we", "our", "us") is a mobile maze-escape game. This '
        'Privacy Policy explains what information we collect, why we collect '
        'it, how we use it, and your rights regarding that information. By '
        'downloading or playing $_kAppName you agree to the practices '
        'described here.',
  ),
  _Section(
    icon: Icons.data_usage_rounded,
    title: '2. Information We Collect',
    body:
        'Account & Identity\n'
        '• Firebase Authentication identifiers (guest UID or linked Google '
        'account — email address, display name, profile picture URL).\n\n'
        'Gameplay Data\n'
        '• Stage progression, trophy counts, leaderboard scores, and '
        'session event metadata.\n\n'
        'Device & Diagnostic Data\n'
        '• Device model, OS version, app version, crash stack traces, and '
        'ANR reports collected by Firebase Crashlytics.\n\n'
        'Analytics Events\n'
        '• In-app events (screen views, button taps, session length) '
        'collected by Firebase Analytics. No personally identifiable '
        'event parameters are logged.\n\n'
        'Advertising Signals\n'
        '• Advertising ID, IP address, and ad interaction data collected '
        'by Google Mobile Ads (AdMob) solely for ad delivery and measurement. '
        'This is subject to your consent choices where required by law.',
  ),
  _Section(
    icon: Icons.track_changes_rounded,
    title: '3. How We Use Your Data',
    body:
        '• Provide, maintain, and improve the game.\n'
        '• Authenticate your account and sync progress across devices.\n'
        '• Display your rank on the Global Panic leaderboard.\n'
        '• Diagnose crashes and fix performance issues.\n'
        '• Measure aggregate usage patterns via analytics.\n'
        '• Serve relevant ads and measure ad performance.\n'
        '• Comply with legal obligations.',
  ),
  _Section(
    icon: Icons.share_rounded,
    title: '4. Third-Party Services',
    body:
        'We use the following third-party services that process data under '
        'their own privacy policies:\n\n'
        '• Firebase Authentication (Google LLC)\n'
        '• Cloud Firestore (Google LLC)\n'
        '• Firebase Analytics (Google LLC)\n'
        '• Firebase Crashlytics (Google LLC)\n'
        '• Google Mobile Ads / AdMob (Google LLC)\n\n'
        'Each service acts as a data processor or independent controller. '
        'We encourage you to review Google\'s Privacy Policy at '
        'https://policies.google.com/privacy.',
  ),
  _Section(
    icon: Icons.child_friendly_rounded,
    title: '5. Children\'s Privacy',
    body:
        '$_kAppName is not directed to children under 13 (or under 16 in the '
        'EU). We do not knowingly collect personal data from children. If '
        'you believe a child has provided us with personal information, '
        'contact us at $_kContactEmail and we will promptly delete it.',
  ),
  _Section(
    icon: Icons.lock_outline_rounded,
    title: '6. Data Security',
    body:
        'All data in transit is encrypted using TLS. Data at rest in '
        'Cloud Firestore is encrypted by Google. We apply Firestore Security '
        'Rules to prevent unauthorised access. However, no system is '
        'completely secure and we cannot guarantee absolute security.',
  ),
  _Section(
    icon: Icons.schedule_rounded,
    title: '7. Data Retention',
    body:
        'Account and gameplay data is retained while your account is active. '
        'You may request deletion at any time (see Section 8). Analytics '
        'event data is retained for 14 months per Firebase defaults. '
        'Crashlytics data is retained for 90 days.',
  ),
  _Section(
    icon: Icons.manage_accounts_rounded,
    title: '8. Your Rights & Choices',
    body:
        'Access & Portability — You may request a copy of data we hold '
        'about you.\n\n'
        'Deletion — Delete your account and all associated data via '
        'Settings → Account → Delete Account & Data, or submit a request at '
        'https://fearflipgame.com/account-deletion.\n\n'
        'Ad Personalisation — Manage ad consent choices via the in-game '
        'consent flow (Settings → Privacy & Consent).\n\n'
        'Analytics Opt-Out — Disable Firebase Analytics collection by '
        'opting out through your device\'s Google account settings.\n\n'
        'GDPR / CCPA — If you are located in the EU/EEA or California, '
        'you have additional rights including restriction and objection. '
        'Contact us at $_kContactEmail to exercise any right.',
  ),
  _Section(
    icon: Icons.public_rounded,
    title: '9. International Transfers',
    body:
        'Your data may be processed in the United States and other countries '
        'where Google operates infrastructure. Google maintains appropriate '
        'transfer mechanisms (e.g. Standard Contractual Clauses) as required '
        'by applicable law.',
  ),
  _Section(
    icon: Icons.update_rounded,
    title: '10. Changes to This Policy',
    body:
        'We may update this policy periodically. Material changes will be '
        'notified within the app or via the Google Play Store update notes. '
        'Continued use of $_kAppName after changes constitutes acceptance '
        'of the updated policy.',
  ),
  _Section(
    icon: Icons.mail_outline_rounded,
    title: '11. Contact Us',
    body:
        'Questions, requests, or complaints? Reach us at:\n\n'
        '$_kDeveloper\n'
        'Email: $_kContactEmail\n'
        'Web: https://fearflipgame.com',
  ),
];

class _Section {
  const _Section({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
}

// ─── Screen ───────────────────────────────────────────────────────────────

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.backgroundDark,
      body: Stack(fit: StackFit.expand, children: [
        // Subtle grid background
        CustomPaint(painter: _BgPainter()),
        SafeArea(
          child: Column(children: [
            _TopBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 32),
                children: [
                  _Hero(),
                  const SizedBox(height: 20),
                  ..._kSections.map((s) => _SectionCard(section: s)),
                  const SizedBox(height: 10),
                  _CopyBtn(),
                ],
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─── Top bar ──────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
    child: Row(children: [
      _IconBtn(icon: Icons.arrow_back_rounded,
          onTap: Navigator.of(context).maybePop),
      const SizedBox(width: 12),
      const Expanded(
        child: Text('PRIVACY POLICY',
            style: TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2)),
      ),
    ]),
  );
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon; final VoidCallback onTap;
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
      child: Icon(icon, color: AppPalette.textPrimary, size: 20),
    ),
  );
}

// ─── Hero banner ──────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
    decoration: BoxDecoration(
      color: AppPalette.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppPalette.neonGreen.withAlpha(120)),
      boxShadow: [
        BoxShadow(color: AppPalette.neonGreen.withAlpha(30), blurRadius: 20),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: AppPalette.neonGreen.withAlpha(22),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppPalette.neonGreen.withAlpha(120)),
          ),
          child: const Icon(Icons.shield_rounded,
              color: AppPalette.neonGreen, size: 22),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$_kAppName — Privacy Policy',
                style: TextStyle(color: AppPalette.textPrimary,
                    fontWeight: FontWeight.w900, fontSize: 15)),
            SizedBox(height: 2),
            Text('Effective: $_kEffectiveDate',
                style: TextStyle(color: AppPalette.neonGreen,
                    fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
        ),
      ]),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppPalette.accentPurple.withAlpha(14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppPalette.accentPurple.withAlpha(80)),
        ),
        child: const Text(
          'We respect your privacy. This policy explains exactly what data '
          '$_kAppName collects, why, and the choices you have. We comply '
          'with Google Play Developer Policies, GDPR, and CCPA.',
          style: TextStyle(color: AppPalette.textMuted,
              fontSize: 12, height: 1.5, fontWeight: FontWeight.w600),
        ),
      ),
    ]),
  );
}

// ─── Section card ─────────────────────────────────────────────────────────

class _SectionCard extends StatefulWidget {
  const _SectionCard({required this.section});
  final _Section section;
  @override State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _expanded
                ? AppPalette.accentPurple.withAlpha(160)
                : AppPalette.borderSoft,
          ),
        ),
        child: Column(children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
              child: Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: AppPalette.accentPurple.withAlpha(18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppPalette.accentPurple.withAlpha(100)),
                  ),
                  child: Icon(widget.section.icon,
                      color: AppPalette.accentPurple, size: 17),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.section.title,
                      style: const TextStyle(
                          color: AppPalette.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppPalette.textMuted, size: 22,
                ),
              ]),
            ),
          ),
          if (_expanded) ...[
            Container(height: 1, color: AppPalette.borderSoft),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: SelectableText(
                widget.section.body,
                style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 13, height: 1.6,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─── Copy URL button ──────────────────────────────────────────────────────

class _CopyBtn extends StatelessWidget {
  @override
  Widget build(BuildContext ctx) => OutlinedButton.icon(
    onPressed: () {
      Clipboard.setData(const ClipboardData(
          text: 'https://fearflipgame.com/privacy'));
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: const Text('Privacy Policy URL copied'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppPalette.surfaceAlt,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    },
    icon: const Icon(Icons.copy_rounded, size: 16),
    label: const Text('COPY POLICY URL'),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(50),
      foregroundColor: AppPalette.neonGreen,
      side: const BorderSide(color: AppPalette.neonGreen),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8),
    ),
  );
}

// ─── Background ───────────────────────────────────────────────────────────

class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size,
        Paint()..color = AppPalette.backgroundDark);
    final p = Paint()
      ..color = const Color(0xFF181818)
      ..strokeWidth = 0.7;
    const step = 36.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    // Purple corner glow top-right
    canvas.drawRect(Offset.zero & size, Paint()
      ..shader = RadialGradient(colors: [
        AppPalette.accentPurple.withAlpha(40), Colors.transparent,
      ]).createShader(Rect.fromCenter(
          center: Offset(size.width, 0),
          width: size.width * 0.65, height: size.width * 0.65)));
    // Green corner glow bottom-left
    canvas.drawRect(Offset.zero & size, Paint()
      ..shader = RadialGradient(colors: [
        AppPalette.neonGreen.withAlpha(25), Colors.transparent,
      ]).createShader(Rect.fromCenter(
          center: Offset(0, size.height),
          width: size.width * 0.55, height: size.width * 0.55)));
  }

  @override
  bool shouldRepaint(_BgPainter _) => false;
}
