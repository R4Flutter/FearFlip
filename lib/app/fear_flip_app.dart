import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_runtime_config.dart';
import '../data/database/local_session_database.dart';
import '../domain/usecases/start_survival_use_case.dart';
import '../presentation/gameplay/game_screen.dart';
import '../presentation/providers/app_flow_provider.dart';
import '../presentation/screens/auth_gate_screen.dart';
import '../presentation/screens/landing_screen.dart';
import '../presentation/theme/app_palette.dart';
import '../services/account_deletion_service.dart';
import '../services/ads_service.dart';
import '../services/consent_service.dart';
import '../services/leaderboard_service.dart';

class _CharacterOption {
  const _CharacterOption({
    required this.title,
    required this.color,
    required this.spriteRowIndex,
  });

  final String title;
  final Color color;
  final int spriteRowIndex;
}

class _CharacterSpritePreview extends StatelessWidget {
  const _CharacterSpritePreview({
    required this.rowIndex,
    required this.accentColor,
  });

  static const double _sheetWidth = 736;
  static const double _sheetHeight = 128;
  static const double _frameSize = 32;
  static const double _previewSize = 42;
  static const double _sheetScale = 1.35;

  final int rowIndex;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final clampedRow = rowIndex.clamp(0, 3);
    final imageWidth = _sheetWidth * _sheetScale;
    final imageHeight = _sheetHeight * _sheetScale;
    final offsetY = clampedRow * _frameSize * _sheetScale;

    return Container(
      width: _previewSize,
      height: _previewSize,
      decoration: BoxDecoration(
        color: accentColor.withAlpha(46),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withAlpha(150), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            maxWidth: imageWidth,
            maxHeight: imageHeight,
            child: Transform.translate(
              offset: Offset(0, -offsetY),
              child: Image.asset(
                'assets/images/characters.png',
                width: imageWidth,
                height: imageHeight,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogGridPainter extends CustomPainter {
  const _DialogGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppPalette.neonGreen.withAlpha(30)
      ..strokeWidth = 1;

    const spacing = 30.0;
    for (var x = 0.0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final accentPaint = Paint()..color = AppPalette.accentPurple.withAlpha(70);
    for (var i = 0; i < 5; i++) {
      final top = size.height * (0.14 + i * 0.16);
      final left = size.width * (0.08 + i * 0.05);
      final width = (size.width * (0.25 + i * 0.04)).clamp(80.0, size.width);
      canvas.drawRect(Rect.fromLTWH(left, top, width, 2), accentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CharacterOptionTile extends StatelessWidget {
  const _CharacterOptionTile({
    required this.option,
    required this.isSelected,
    required this.isDefault,
    required this.onTap,
  });

  final _CharacterOption option;
  final bool isSelected;
  final bool isDefault;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = isSelected ? Colors.black : AppPalette.textPrimary;
    final mutedFg = isSelected
        ? Colors.black.withAlpha(200)
        : AppPalette.textMuted;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? option.color.withAlpha(230)
              : AppPalette.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white : AppPalette.borderSoft,
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: option.color.withAlpha(95),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            _CharacterSpritePreview(
              rowIndex: option.spriteRowIndex,
              accentColor: isSelected ? Colors.white : option.color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to activate this runner for gameplay.',
                    style: TextStyle(
                      color: mutedFg,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isDefault)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.black.withAlpha(40)
                      : AppPalette.neonGreen.withAlpha(34),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected
                        ? Colors.black.withAlpha(120)
                        : AppPalette.neonGreen.withAlpha(120),
                  ),
                ),
                child: Text(
                  'DEFAULT',
                  style: TextStyle(
                    color: isSelected ? Colors.black : AppPalette.neonGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? Colors.black : AppPalette.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsMetricChip extends StatelessWidget {
  const _SettingsMetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(150)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          children: [
            TextSpan(
              text: '$label  ',
              style: TextStyle(color: color),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppPalette.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withAlpha(140), width: 1.2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withAlpha(20), AppPalette.surfaceAlt],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppPalette.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _SettingsModeTile extends StatelessWidget {
  const _SettingsModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: selected
              ? AppPalette.accentPink.withAlpha(220)
              : AppPalette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.white : AppPalette.borderSoft,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x66E85BDA),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? Colors.black : AppPalette.textPrimary,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                color: selected ? Colors.black : AppPalette.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: selected
                    ? Colors.black.withAlpha(180)
                    : AppPalette.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 11,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsPolicyButton extends StatelessWidget {
  const _SettingsPolicyButton({
    required this.icon,
    required this.label,
    required this.url,
    required this.onCopy,
  });

  final IconData icon;
  final String label;
  final String url;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onCopy,
      icon: Icon(icon, size: 18),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          Text(
            url,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: AppPalette.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        minimumSize: const Size.fromHeight(50),
        foregroundColor: AppPalette.textPrimary,
        side: const BorderSide(color: AppPalette.borderSoft),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class FearFlipApp extends StatefulWidget {
  const FearFlipApp({super.key});

  @override
  State<FearFlipApp> createState() => _FearFlipAppState();
}

class _FearFlipAppState extends State<FearFlipApp> {
  late final AppFlowProvider _flow;
  final AdsService _restartAdsService = AdsService();
  static const List<_CharacterOption> _characterOptions = <_CharacterOption>[
    _CharacterOption(
      title: 'Steel Sentinel',
      color: Color(0xFF5A9FD9),
      spriteRowIndex: 1,
    ),
    _CharacterOption(
      title: 'Green Phantom',
      color: Color(0xFF40D66A),
      spriteRowIndex: 2,
    ),
  ];
  static const String _privacyPolicyDashbarText =
      'Last updated: 2026-04-12\n\n'
      'FearFlip uses Firebase and Google Mobile Ads to provide gameplay '
      'services, authentication, analytics, crash reporting, and '
      'monetization.\n\n'
      'Data we process\n'
      '- Authentication identifiers (guest and linked Google sign-in '
      'accounts)\n'
      '- Gameplay events and progression metrics\n'
      '- Crash diagnostics and device metadata for stability\n'
      '- Ad mediation and ad delivery signals required by Google Mobile '
      'Ads\n\n'
      'Why we process data\n'
      '- Authenticate players and keep account continuity\n'
      '- Operate leaderboards and progression systems\n'
      '- Diagnose crashes, errors, and performance issues\n'
      '- Serve ads and track ad delivery outcomes\n\n'
      'Third-party services\n'
      '- Firebase Authentication\n'
      '- Cloud Firestore\n'
      '- Firebase Analytics\n'
      '- Firebase Crashlytics\n'
      '- Google Mobile Ads (AdMob)\n\n'
      'User choices\n'
      '- Manage ad consent choices where required by law (UMP flow)\n'
      '- Request account deletion from Settings -> Account -> Delete '
      'Account & Data\n'
      '- Request deletion via web: '
      'https://fearflipgame.com/account-deletion\n\n'
      'Contact\n'
      'privacy@fearflipgame.com';

  Future<void> _openCharacterDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        var selected = _flow.selectedCharacterIndex;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 22,
          ),
          child: StatefulBuilder(
            builder: (context, setLocalState) {
              final screenHeight = MediaQuery.sizeOf(context).height;
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 640,
                  maxHeight: (screenHeight * 0.84).clamp(460.0, 760.0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppPalette.surface,
                      border: Border.all(
                        color: AppPalette.accentPurple.withAlpha(170),
                        width: 1.4,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x4A000000),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const CustomPaint(painter: _DialogGridPainter()),
                        IgnorePointer(
                          child: Align(
                            alignment: const Alignment(0, -0.9),
                            child: Container(
                              width: 420,
                              height: 180,
                              decoration: const BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    Color(0x55E26AE6),
                                    Color(0x4433FF2B),
                                    Color(0x00FFFFFF),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'CHOOSE CHARACTER',
                                  style: TextStyle(
                                    color: AppPalette.textPrimary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.9,
                                    shadows: [
                                      Shadow(
                                        color: Color(0x9033FF2B),
                                        blurRadius: 10,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Select your runner. The selection is saved and used in every run until you change it.',
                                  style: TextStyle(
                                    color: AppPalette.textMuted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: [
                                        for (
                                          var i = 0;
                                          i < _characterOptions.length;
                                          i++
                                        )
                                          Padding(
                                            padding: EdgeInsets.only(
                                              bottom:
                                                  i ==
                                                      _characterOptions.length -
                                                          1
                                                  ? 0
                                                  : 12,
                                            ),
                                            child: _CharacterOptionTile(
                                              option: _characterOptions[i],
                                              isSelected: selected == i,
                                              isDefault:
                                                  i ==
                                                  AppFlowProvider
                                                      .defaultCharacterIndex,
                                              onTap: () {
                                                setLocalState(() {
                                                  selected = i;
                                                });
                                                _flow.updateSelectedCharacter(
                                                  i,
                                                );
                                              },
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size.fromHeight(
                                            48,
                                          ),
                                          side: const BorderSide(
                                            color: AppPalette.borderSoft,
                                          ),
                                          foregroundColor:
                                              AppPalette.textPrimary,
                                        ),
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size.fromHeight(
                                            48,
                                          ),
                                          backgroundColor:
                                              AppPalette.accentPink,
                                          foregroundColor: Colors.black,
                                        ),
                                        child: const Text(
                                          'Done',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _copyUrl(BuildContext context, String label, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label URL copied'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppPalette.surfaceAlt,
      ),
    );
  }

  Future<bool> _confirmAccountDeletion(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppPalette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppPalette.danger),
          ),
          title: const Text(
            'Delete Account?',
            style: TextStyle(
              color: AppPalette.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'This requests deletion of your sign-in account, cloud progress, leaderboard identity, and related gameplay data. This cannot be undone.',
            style: TextStyle(
              color: AppPalette.textMuted,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppPalette.textMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.danger,
                foregroundColor: Colors.black,
              ),
              child: const Text(
                'Delete Account',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  Future<void> _openSettingsDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        var joystickSize = _flow.joystickSize;
        var soundVolume = _flow.soundVolume;
        var isSoundMuted = _flow.isSoundMuted;
        var useArrowController = _flow.useArrowController;
        var isDeletingAccount = _flow.isDeletingAccount;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          child: StatefulBuilder(
            builder: (context, setLocalState) {
              final screenHeight = MediaQuery.sizeOf(context).height;
              final inputLabel = useArrowController ? 'ARROW PAD' : 'JOYSTICK';
              final volumeLabel = '${(soundVolume * 100).round()}%';

              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 720,
                  maxHeight: (screenHeight * 0.9).clamp(560.0, 860.0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppPalette.surface,
                      border: Border.all(
                        color: AppPalette.accentPurple.withAlpha(180),
                        width: 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x4A000000),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const CustomPaint(painter: _DialogGridPainter()),
                        IgnorePointer(
                          child: Align(
                            alignment: const Alignment(0, -0.9),
                            child: Container(
                              width: 460,
                              height: 190,
                              decoration: const BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    Color(0x55E26AE6),
                                    Color(0x4433FF2B),
                                    Color(0x00FFFFFF),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'SYSTEM SETTINGS',
                                  style: TextStyle(
                                    color: AppPalette.textPrimary,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                    shadows: [
                                      Shadow(
                                        color: Color(0x9033FF2B),
                                        blurRadius: 10,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Everything updates live so you can tune controls instantly.',
                                  style: TextStyle(
                                    color: AppPalette.textMuted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _SettingsMetricChip(
                                      label: 'INPUT',
                                      value: inputLabel,
                                      color: useArrowController
                                          ? AppPalette.accentPink
                                          : AppPalette.neonGreen,
                                    ),
                                    _SettingsMetricChip(
                                      label: 'VOLUME',
                                      value: volumeLabel,
                                      color: isSoundMuted
                                          ? AppPalette.textMuted
                                          : AppPalette.accentPurple,
                                    ),
                                    _SettingsMetricChip(
                                      label: 'SOUND',
                                      value: isSoundMuted ? 'MUTED' : 'ACTIVE',
                                      color: isSoundMuted
                                          ? AppPalette.danger
                                          : AppPalette.neonGreen,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _SettingsSectionCard(
                                          title: 'Control Scheme',
                                          subtitle:
                                              'Choose your preferred input mode for gameplay.',
                                          accent: AppPalette.accentPurple,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: _SettingsModeTile(
                                                  icon: Icons.sports_esports,
                                                  title: 'Joystick',
                                                  subtitle:
                                                      'Analog movement control',
                                                  selected: !useArrowController,
                                                  onTap: () {
                                                    setLocalState(() {
                                                      useArrowController =
                                                          false;
                                                    });
                                                    _flow
                                                        .updateUseArrowController(
                                                          false,
                                                        );
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: _SettingsModeTile(
                                                  icon: Icons.gamepad,
                                                  title: 'Arrow Pad',
                                                  subtitle:
                                                      'Directional button control',
                                                  selected: useArrowController,
                                                  onTap: () {
                                                    setLocalState(() {
                                                      useArrowController = true;
                                                    });
                                                    _flow
                                                        .updateUseArrowController(
                                                          true,
                                                        );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        _SettingsSectionCard(
                                          title: useArrowController
                                              ? 'Arrow Pad Size'
                                              : 'Joystick Size',
                                          subtitle:
                                              'Adjust control footprint for comfort and precision.',
                                          accent: AppPalette.neonGreen,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${joystickSize.round()} px',
                                                style: const TextStyle(
                                                  color: AppPalette.neonGreen,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 18,
                                                ),
                                              ),
                                              SliderTheme(
                                                data: SliderTheme.of(context)
                                                    .copyWith(
                                                      activeTrackColor:
                                                          AppPalette.neonGreen,
                                                      inactiveTrackColor:
                                                          AppPalette.surface,
                                                      thumbColor:
                                                          AppPalette.neonGreen,
                                                      trackHeight: 4,
                                                    ),
                                                child: Slider(
                                                  min: AppFlowProvider
                                                      .minJoystickSize,
                                                  max: AppFlowProvider
                                                      .maxJoystickSize,
                                                  divisions: 16,
                                                  value: joystickSize,
                                                  label:
                                                      '${joystickSize.round()} px',
                                                  onChanged: (value) {
                                                    setLocalState(() {
                                                      joystickSize = value;
                                                    });
                                                    _flow.updateJoystickSize(
                                                      value,
                                                    );
                                                  },
                                                ),
                                              ),
                                              const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    'Compact',
                                                    style: TextStyle(
                                                      color:
                                                          AppPalette.textMuted,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Large',
                                                    style: TextStyle(
                                                      color:
                                                          AppPalette.textMuted,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        _SettingsSectionCard(
                                          title: 'Audio',
                                          subtitle:
                                              'Toggle mute and fine tune the master output level.',
                                          accent: AppPalette.accentPink,
                                          child: Column(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppPalette.surface,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color:
                                                        AppPalette.borderSoft,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      isSoundMuted
                                                          ? Icons.volume_off
                                                          : Icons.volume_up,
                                                      color: isSoundMuted
                                                          ? AppPalette.danger
                                                          : AppPalette
                                                                .accentPink,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    const Expanded(
                                                      child: Text(
                                                        'Mute all gameplay and UI sound',
                                                        style: TextStyle(
                                                          color: AppPalette
                                                              .textPrimary,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                    Switch.adaptive(
                                                      value: isSoundMuted,
                                                      activeThumbColor:
                                                          AppPalette.accentPink,
                                                      activeTrackColor:
                                                          AppPalette.accentPink
                                                              .withAlpha(100),
                                                      onChanged: (value) {
                                                        setLocalState(() {
                                                          isSoundMuted = value;
                                                        });
                                                        unawaited(
                                                          _flow
                                                              .updateSoundMuted(
                                                                value,
                                                              ),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Opacity(
                                                opacity: isSoundMuted
                                                    ? 0.55
                                                    : 1,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Master Volume: $volumeLabel',
                                                      style: TextStyle(
                                                        color: isSoundMuted
                                                            ? AppPalette
                                                                  .textMuted
                                                            : AppPalette
                                                                  .accentPink,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                    SliderTheme(
                                                      data:
                                                          SliderTheme.of(
                                                            context,
                                                          ).copyWith(
                                                            activeTrackColor:
                                                                AppPalette
                                                                    .accentPink,
                                                            inactiveTrackColor:
                                                                AppPalette
                                                                    .surface,
                                                            thumbColor:
                                                                AppPalette
                                                                    .accentPink,
                                                            trackHeight: 4,
                                                          ),
                                                      child: Slider(
                                                        min: 0,
                                                        max: 1,
                                                        divisions: 20,
                                                        value: soundVolume,
                                                        label: volumeLabel,
                                                        onChanged: (value) {
                                                          setLocalState(() {
                                                            soundVolume = value;
                                                          });
                                                          unawaited(
                                                            _flow
                                                                .updateSoundVolume(
                                                                  value,
                                                                ),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        _SettingsSectionCard(
                                          title: 'Privacy & Consent',
                                          subtitle:
                                              'Copy policy links for Play compliance, account deletion, and ad privacy review.',
                                          accent: AppPalette.accentPurple,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              _SettingsPolicyButton(
                                                icon: Icons.privacy_tip,
                                                label: 'Privacy Policy',
                                                url: AppRuntimeConfig
                                                    .privacyPolicyUrl,
                                                onCopy: () => _copyUrl(
                                                  context,
                                                  'Privacy Policy',
                                                  AppRuntimeConfig
                                                      .privacyPolicyUrl,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              _SettingsPolicyButton(
                                                icon: Icons.description,
                                                label: 'Terms',
                                                url: AppRuntimeConfig.termsUrl,
                                                onCopy: () => _copyUrl(
                                                  context,
                                                  'Terms',
                                                  AppRuntimeConfig.termsUrl,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              _SettingsPolicyButton(
                                                icon: Icons.delete_forever,
                                                label:
                                                    'Account Deletion Web Form',
                                                url: AppRuntimeConfig
                                                    .accountDeletionUrl,
                                                onCopy: () => _copyUrl(
                                                  context,
                                                  'Account Deletion',
                                                  AppRuntimeConfig
                                                      .accountDeletionUrl,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              FilledButton.icon(
                                                icon: const Icon(
                                                  Icons.tune_rounded,
                                                ),
                                                label: const Text(
                                                  'Manage Ad Privacy Choices',
                                                ),
                                                style: FilledButton.styleFrom(
                                                  minimumSize:
                                                      const Size.fromHeight(48),
                                                  backgroundColor:
                                                      AppPalette.accentPurple,
                                                  foregroundColor: Colors.black,
                                                  textStyle: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                onPressed: () async {
                                                  final shown =
                                                      await ConsentService
                                                          .instance
                                                          .showPrivacyOptions();
                                                  if (!context.mounted) {
                                                    return;
                                                  }
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        shown
                                                            ? 'Ad privacy options updated.'
                                                            : 'Ad privacy options are unavailable right now.',
                                                      ),
                                                      behavior: SnackBarBehavior
                                                          .floating,
                                                      backgroundColor: shown
                                                          ? AppPalette
                                                                .surfaceAlt
                                                          : AppPalette.danger,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        _SettingsSectionCard(
                                          title: 'Account',
                                          subtitle:
                                              'Sign out or request account and cloud data deletion.',
                                          accent: AppPalette.danger,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              FilledButton.icon(
                                                icon: const Icon(Icons.logout),
                                                label: const Text('Sign Out'),
                                                style: FilledButton.styleFrom(
                                                  minimumSize:
                                                      const Size.fromHeight(48),
                                                  backgroundColor:
                                                      AppPalette.danger,
                                                  foregroundColor: Colors.black,
                                                  textStyle: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                onPressed: isDeletingAccount
                                                    ? null
                                                    : () async {
                                                        Navigator.of(
                                                          context,
                                                        ).pop();
                                                        await _flow.signOut();
                                                      },
                                              ),
                                              const SizedBox(height: 8),
                                              OutlinedButton.icon(
                                                icon: isDeletingAccount
                                                    ? const SizedBox(
                                                        width: 18,
                                                        height: 18,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                            ),
                                                      )
                                                    : const Icon(
                                                        Icons.delete_forever,
                                                      ),
                                                label: Text(
                                                  isDeletingAccount
                                                      ? 'Requesting Deletion...'
                                                      : 'Delete Account & Data',
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  minimumSize:
                                                      const Size.fromHeight(48),
                                                  foregroundColor:
                                                      AppPalette.danger,
                                                  side: const BorderSide(
                                                    color: AppPalette.danger,
                                                  ),
                                                  textStyle: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                onPressed: isDeletingAccount
                                                    ? null
                                                    : () async {
                                                        final confirmed =
                                                            await _confirmAccountDeletion(
                                                              context,
                                                            );
                                                        if (!confirmed ||
                                                            !context.mounted) {
                                                          return;
                                                        }

                                                        setLocalState(() {
                                                          isDeletingAccount =
                                                              true;
                                                        });
                                                        final result = await _flow
                                                            .requestAccountDeletion();
                                                        if (!context.mounted) {
                                                          return;
                                                        }

                                                        final failed =
                                                            result.status ==
                                                            AccountDeletionStatus
                                                                .failed;
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              result.message,
                                                            ),
                                                            behavior:
                                                                SnackBarBehavior
                                                                    .floating,
                                                            backgroundColor:
                                                                failed
                                                                ? AppPalette
                                                                      .danger
                                                                : AppPalette
                                                                      .surfaceAlt,
                                                          ),
                                                        );
                                                        setLocalState(() {
                                                          isDeletingAccount =
                                                              false;
                                                        });
                                                        if (result
                                                            .shouldReturnToAuthGate) {
                                                          Navigator.of(
                                                            context,
                                                          ).pop();
                                                        }
                                                      },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size.fromHeight(
                                            46,
                                          ),
                                          side: const BorderSide(
                                            color: AppPalette.borderSoft,
                                          ),
                                          foregroundColor:
                                              AppPalette.textPrimary,
                                        ),
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size.fromHeight(
                                            46,
                                          ),
                                          backgroundColor:
                                              AppPalette.accentPink,
                                          foregroundColor: Colors.black,
                                        ),
                                        child: const Text(
                                          'Done',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openLeaderboardDialog(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            _LeaderboardScreen(service: _flow.game.leaderboardService),
      ),
    );
  }

  Future<void> _openRemoveAdsDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppPalette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppPalette.borderSoft),
          ),
          title: const Text(
            'Remove Ads',
            style: TextStyle(
              color: AppPalette.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Purchase flow can be connected here to permanently remove ads from gameplay.',
            style: TextStyle(color: AppPalette.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: AppPalette.accentPink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openPrivacyPolicyDashbar(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final height = MediaQuery.sizeOf(sheetContext).height;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: (height * 0.82).clamp(420.0, 840.0).toDouble(),
              ),
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppPalette.accentPurple),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppPalette.borderSoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.privacy_tip_rounded,
                          color: AppPalette.neonGreen,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Privacy Policy Dashbar',
                            style: TextStyle(
                              color: AppPalette.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                          color: AppPalette.textPrimary,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppPalette.borderSoft),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hosted URL: ${AppRuntimeConfig.privacyPolicyUrl}',
                            style: const TextStyle(
                              color: AppPalette.textMuted,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const SelectableText(
                            _privacyPolicyDashbarText,
                            style: TextStyle(
                              color: AppPalette.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: () => _copyUrl(
                              sheetContext,
                              'Privacy Policy',
                              AppRuntimeConfig.privacyPolicyUrl,
                            ),
                            icon: const Icon(Icons.copy_rounded),
                            label: const Text('Copy Privacy Policy URL'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              foregroundColor: AppPalette.textPrimary,
                              side: const BorderSide(
                                color: AppPalette.borderSoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    final sessionDatabase = LocalSessionDatabase();
    _flow = AppFlowProvider(
      sessionDatabase: sessionDatabase,
      startSurvivalUseCase: StartSurvivalUseCase(
        sessionDatabase: sessionDatabase,
      ),
    );
    unawaited(_restartAdsService.preload());
  }

  @override
  void dispose() {
    _restartAdsService.dispose();
    _flow.dispose();
    super.dispose();
  }

  Future<bool> _showRestartAd() async {
    await _restartAdsService.showInterstitialAfterGameOver();
    return true;
  }

  Future<bool> _showReviveAd() async {
    final rewarded = await _restartAdsService.showRewardedForRevive();
    if (rewarded) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AnimatedBuilder(
        animation: _flow,
        builder: (context, _) {
          return Scaffold(
            backgroundColor: AppPalette.backgroundDark,
            body: Stack(
              fit: StackFit.expand,
              children: [
                Offstage(
                  offstage: _flow.showAuthGate || _flow.showLanding,
                  child: GameScreen(
                    joystickSize: _flow.joystickSize,
                    useArrowController: _flow.useArrowController,
                    selectedCharacterIndex: _flow.selectedCharacterIndex,
                    totalTrophies: _flow.totalTrophies,
                    isActive: !_flow.showAuthGate && !_flow.showLanding,
                    onExitToDashboard: _flow.returnToDashboard,
                    onStageCleared: _flow.onStageCleared,
                    onRestartWithAd: _showRestartAd,
                    onReviveWithAd: _showReviveAd,
                  ),
                ),
                if (_flow.showAuthGate)
                  AuthGateScreen(
                    isAuthenticating: _flow.isAuthenticating,
                    errorMessage: _flow.authError,
                    onGoogleSignIn: _flow.signInWithGoogle,
                    onGuestPlay: _flow.playAsGuest,
                  )
                else if (_flow.showLanding)
                  LandingScreen(
                    isStarting: _flow.isStarting,
                    onPlay: _flow.startSurvival,
                    onChooseCharacter: () => _openCharacterDialog(context),
                    onSettings: () => _openSettingsDialog(context),
                    onLeaderboard: () => _openLeaderboardDialog(context),
                    onRemoveAds: () => _openRemoveAdsDialog(context),
                    onPrivacyPolicy: () => _openPrivacyPolicyDashbar(context),
                    playerName: _flow.playerName,
                    totalTrophies: _flow.totalTrophies,
                    globalPanicRank: _flow.globalPanicRank,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LeaderboardScreen extends StatefulWidget {
  const _LeaderboardScreen({required this.service});

  final LeaderboardService service;

  @override
  State<_LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<_LeaderboardScreen> {
  late Future<LeaderboardSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<LeaderboardSnapshot> _load() {
    return widget.service.getGlobalPanicLeaderboard(limit: 20);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  String _formatClock(DateTime value) {
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Material(
                    color: AppPalette.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppPalette.borderSoft),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppPalette.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GLOBAL PANIC',
                          style: TextStyle(
                            color: AppPalette.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.9,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Solid Leaderboard',
                          style: TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () {
                      unawaited(_refresh());
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      maximumSize: const Size(44, 44),
                      padding: EdgeInsets.zero,
                      backgroundColor: AppPalette.accentPink,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppPalette.borderSoft),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard style ranking with solid cards and strong contrast.',
                      style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Pull down to refresh live standings.',
                      style: TextStyle(
                        color: AppPalette.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<LeaderboardSnapshot>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _LeaderboardStateCard(
                        icon: Icons.bolt,
                        title: 'Loading Leaderboard',
                        message: 'Syncing global panic standings...',
                        showLoader: true,
                        accent: AppPalette.accentPurple,
                      );
                    }

                    if (snapshot.hasError) {
                      return _LeaderboardStateCard(
                        icon: Icons.wifi_off_rounded,
                        title: 'Connection Interrupted',
                        message:
                            'Unable to load leaderboard right now. Try refreshing.',
                        accent: AppPalette.danger,
                        action: FilledButton.icon(
                          onPressed: () {
                            unawaited(_refresh());
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppPalette.accentPink,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      );
                    }

                    final data = snapshot.data;
                    if (data == null || data.entries.isEmpty) {
                      return _LeaderboardStateCard(
                        icon: Icons.flag_circle_outlined,
                        title: 'No Leaders Yet',
                        message:
                            'Play and clear stages to become the first ranked player.',
                        accent: AppPalette.neonGreen,
                        action: FilledButton.icon(
                          onPressed: () {
                            unawaited(_refresh());
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Refresh'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppPalette.neonGreen,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      color: AppPalette.neonGreen,
                      backgroundColor: AppPalette.surfaceAlt,
                      onRefresh: _refresh,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 22),
                        itemCount: data.entries.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            final myRankLabel = data.myRank == null
                                ? 'N/A'
                                : '#${data.myRank}';
                            final myStageLabel = (data.myMaxStage ?? 0)
                                .toString();
                            final myTrophyLabel = (data.myTotalTrophies ?? 0)
                                .toString();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppPalette.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppPalette.neonGreen),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _LeaderboardMetricTile(
                                          title: 'PLAYERS',
                                          value: '${data.totalPlayers}',
                                          color: AppPalette.neonGreen,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _LeaderboardMetricTile(
                                          title: 'YOUR RANK',
                                          value: myRankLabel,
                                          color: AppPalette.accentPurple,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _LeaderboardMetricTile(
                                          title: 'STAGE',
                                          value: myStageLabel,
                                          color: AppPalette.accentPink,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _LeaderboardMetricTile(
                                          title: 'TROPHIES',
                                          value: myTrophyLabel,
                                          color: const Color(0xFFFFD54F),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Updated ${_formatClock(data.fetchedAt)}',
                                        style: const TextStyle(
                                          color: AppPalette.textMuted,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }

                          final entry = data.entries[index - 1];
                          final isCurrentUser =
                              data.myRank != null && entry.rank == data.myRank;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _LeaderboardEntryCard(
                              entry: entry,
                              isCurrentUser: isCurrentUser,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardMetricTile extends StatelessWidget {
  const _LeaderboardMetricTile({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final darkText = color.computeLuminance() > 0.45;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: darkText ? Colors.black.withAlpha(170) : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: darkText ? Colors.black : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 17,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardStateCard extends StatelessWidget {
  const _LeaderboardStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.showLoader = false,
    this.accent = AppPalette.accentPurple,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool showLoader;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent, width: 1.4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showLoader)
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: accent,
                ),
              )
            else
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: Colors.black, size: 22),
              ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppPalette.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppPalette.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    );
  }
}

class _LeaderboardEntryCard extends StatelessWidget {
  const _LeaderboardEntryCard({
    required this.entry,
    required this.isCurrentUser,
  });

  final LeaderboardEntry entry;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final rankColor = _rankColor(entry.rank);
    final cardColor = _cardColor();
    final cardBorder = _cardBorderColor();
    final useDarkText = cardColor.computeLuminance() > 0.45;
    final primaryText = useDarkText ? Colors.black : AppPalette.textPrimary;
    final mutedText = useDarkText
        ? Colors.black.withAlpha(170)
        : AppPalette.textMuted;
    final trimmedName = (entry.displayName ?? 'Player').trim();
    final displayName = trimmedName.isEmpty ? 'Player' : trimmedName;

    final stageChipColor = useDarkText ? Colors.black : AppPalette.neonGreen;
    final trophyChipColor = useDarkText ? Colors.black : AppPalette.accentPink;
    final scoreChipColor = useDarkText ? Colors.black : AppPalette.accentPurple;
    final chipTextColor = useDarkText ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder, width: isCurrentUser ? 1.6 : 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: rankColor.withAlpha(24),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: rankColor.withAlpha(150)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_rankIcon(entry.rank), color: rankColor, size: 17),
                const SizedBox(height: 1),
                Text(
                  '#${entry.rank}',
                  style: TextStyle(
                    color: rankColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primaryText,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (isCurrentUser)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: useDarkText
                              ? Colors.black.withAlpha(28)
                              : AppPalette.neonGreen,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: useDarkText
                                ? Colors.black.withAlpha(120)
                                : AppPalette.neonGreen,
                          ),
                        ),
                        child: Text(
                          'YOU',
                          style: TextStyle(
                            color: useDarkText ? Colors.black : Colors.black,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Stage ${entry.maxStage ?? 1}  •  Trophies ${entry.totalTrophies ?? 0}',
                  style: TextStyle(
                    color: mutedText,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _StatChip(
                      label: 'Stage ${entry.maxStage ?? 1}',
                      color: stageChipColor,
                      textColor: chipTextColor,
                    ),
                    _StatChip(
                      label: 'Trophies ${entry.totalTrophies ?? 0}',
                      color: trophyChipColor,
                      textColor: chipTextColor,
                    ),
                    if (entry.scoreSeconds > 0)
                      _StatChip(
                        label: '${entry.scoreSeconds}s',
                        color: scoreChipColor,
                        textColor: chipTextColor,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _rankColor(int rank) {
    if (rank == 1) {
      return const Color(0xFFFFD54F);
    }
    if (rank == 2) {
      return const Color(0xFFE0E0E0);
    }
    if (rank == 3) {
      return const Color(0xFFFFAB91);
    }
    return AppPalette.accentPurple;
  }

  Color _cardColor() {
    if (isCurrentUser) {
      return AppPalette.neonGreen;
    }
    if (entry.rank == 1) {
      return const Color(0xFFFFD54F);
    }
    if (entry.rank == 2) {
      return const Color(0xFFE0E0E0);
    }
    if (entry.rank == 3) {
      return const Color(0xFFFFAB91);
    }
    return AppPalette.surfaceAlt;
  }

  Color _cardBorderColor() {
    if (isCurrentUser) {
      return Colors.white;
    }
    if (entry.rank <= 3) {
      return Colors.black.withAlpha(120);
    }
    return AppPalette.borderSoft;
  }

  IconData _rankIcon(int rank) {
    if (rank == 1) {
      return Icons.workspace_premium;
    }
    if (rank == 2) {
      return Icons.military_tech;
    }
    if (rank == 3) {
      return Icons.emoji_events;
    }
    return Icons.flash_on;
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    this.color = AppPalette.neonGreen,
    this.textColor,
  });

  final String label;
  final Color color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:
              textColor ??
              (color.computeLuminance() > 0.45 ? Colors.black : Colors.white),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
