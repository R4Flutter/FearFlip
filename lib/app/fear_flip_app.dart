import 'dart:async';

import 'package:flutter/material.dart';

import '../data/database/local_session_database.dart';
import '../domain/usecases/start_survival_use_case.dart';
import '../presentation/gameplay/game_screen.dart';
import '../presentation/providers/app_flow_provider.dart';
import '../presentation/screens/auth_gate_screen.dart';
import '../presentation/screens/landing_screen.dart';
import '../presentation/theme/app_palette.dart';
import '../services/ads_service.dart';
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

  Future<void> _openCharacterDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        var selected = _flow.selectedCharacterIndex;
        return Dialog(
          backgroundColor: AppPalette.surface,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 22,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppPalette.borderSoft, width: 1.2),
          ),
          child: StatefulBuilder(
            builder: (context, setLocalState) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Choose Character',
                        style: TextStyle(
                          color: AppPalette.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Your choice is saved and used every time until you change it.',
                        style: TextStyle(
                          color: AppPalette.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (var i = 0; i < _characterOptions.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: i == _characterOptions.length - 1 ? 0 : 10,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setLocalState(() {
                                selected = i;
                              });
                              _flow.updateSelectedCharacter(i);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: selected == i
                                    ? AppPalette.surfaceAlt
                                    : AppPalette.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected == i
                                      ? AppPalette.accentPink
                                      : AppPalette.borderSoft,
                                  width: selected == i ? 1.4 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  _CharacterSpritePreview(
                                    rowIndex:
                                        _characterOptions[i].spriteRowIndex,
                                    accentColor: _characterOptions[i].color,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _characterOptions[i].title,
                                      style: const TextStyle(
                                        color: AppPalette.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  if (i ==
                                      AppFlowProvider.defaultCharacterIndex)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 10),
                                      child: Text(
                                        'DEFAULT',
                                        style: TextStyle(
                                          color: AppPalette.neonGreen,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  Icon(
                                    selected == i
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: selected == i
                                        ? AppPalette.accentPink
                                        : AppPalette.textMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Done',
                            style: TextStyle(
                              color: AppPalette.accentPink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openSettingsDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        var joystickSize = _flow.joystickSize;
        var useArrowController = _flow.useArrowController;
        return Dialog(
          backgroundColor: AppPalette.surface,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppPalette.borderSoft, width: 1.2),
          ),
          child: StatefulBuilder(
            builder: (context, setLocalState) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Settings',
                          style: TextStyle(
                            color: AppPalette.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Customize controls and account options.',
                          style: TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppPalette.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppPalette.borderSoft),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Controller Type',
                                style: TextStyle(
                                  color: AppPalette.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ChoiceChip(
                                    label: const Text('Joystick'),
                                    selected: !useArrowController,
                                    selectedColor: AppPalette.accentPink,
                                    labelStyle: TextStyle(
                                      color: !useArrowController
                                          ? Colors.black
                                          : AppPalette.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    onSelected: (_) {
                                      setLocalState(() {
                                        useArrowController = false;
                                      });
                                      _flow.updateUseArrowController(false);
                                    },
                                  ),
                                  ChoiceChip(
                                    label: const Text('Arrow Pad'),
                                    selected: useArrowController,
                                    selectedColor: AppPalette.accentPink,
                                    labelStyle: TextStyle(
                                      color: useArrowController
                                          ? Colors.black
                                          : AppPalette.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    onSelected: (_) {
                                      setLocalState(() {
                                        useArrowController = true;
                                      });
                                      _flow.updateUseArrowController(true);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppPalette.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppPalette.borderSoft),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                useArrowController
                                    ? 'Arrow Pad Size'
                                    : 'Joystick Size',
                                style: const TextStyle(
                                  color: AppPalette.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                useArrowController
                                    ? 'Adjust the Arrow Pad size used in gameplay.'
                                    : 'Adjust the Joystick size used in gameplay.',
                                style: const TextStyle(
                                  color: AppPalette.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${joystickSize.round()} px',
                                style: const TextStyle(
                                  color: AppPalette.accentPink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Slider(
                                min: AppFlowProvider.minJoystickSize,
                                max: AppFlowProvider.maxJoystickSize,
                                divisions: 16,
                                value: joystickSize,
                                activeColor: AppPalette.accentPink,
                                inactiveColor: AppPalette.surface,
                                label: '${joystickSize.round()} px',
                                onChanged: (value) {
                                  setLocalState(() {
                                    joystickSize = value;
                                  });
                                  _flow.updateJoystickSize(value);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppPalette.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppPalette.borderSoft),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Account',
                                style: TextStyle(
                                  color: AppPalette.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.logout),
                                label: const Text('Sign Out'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppPalette.accentPink,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  await _flow.signOut();
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              'Close',
                              style: TextStyle(
                                color: AppPalette.accentPink,
                                fontWeight: FontWeight.w600,
                              ),
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
    final rewarded = await _restartAdsService.showRewardedForRevive();
    if (rewarded) {
      return true;
    }
    await _restartAdsService.showInterstitialAfterGameOver();
    return true;
  }

  Future<bool> _showReviveAd() async {
    final rewarded = await _restartAdsService.showRewardedForRevive();
    if (rewarded) {
      return true;
    }
    await _restartAdsService.showInterstitialAfterGameOver();
    return true;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'GLOBAL PANIC LEADERBOARD',
          style: TextStyle(
            color: AppPalette.neonGreen,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF070707), Color(0xFF111111)],
          ),
        ),
        child: FutureBuilder<LeaderboardSnapshot>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Unable to load leaderboard right now.',
                  style: TextStyle(color: AppPalette.danger),
                ),
              );
            }

            final data = snapshot.data;
            if (data == null || data.entries.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'No leaderboard entries yet.',
                        style: TextStyle(
                          color: AppPalette.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Play and clear stages to appear here.',
                        style: TextStyle(color: AppPalette.textMuted),
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _future = _load();
                          });
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppPalette.neonGreen,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _future = _load();
                });
                await _future;
              },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                itemCount: data.entries.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151515),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppPalette.borderSoft),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Players: ${data.totalPlayers}',
                            style: const TextStyle(
                              color: AppPalette.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            data.myRank == null ||
                                    data.myMaxStage == null ||
                                    data.myTotalTrophies == null
                                ? 'Your rank: N/A'
                                : 'Your rank: #${data.myRank}  •  Stage ${data.myMaxStage}  •  Trophies ${data.myTotalTrophies}',
                            style: const TextStyle(
                              color: AppPalette.neonGreen,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final row = data.entries[index - 1];
                  final rank = row.rank;
                  final rankColor = rank == 1
                      ? const Color(0xFFFFD54F)
                      : rank == 2
                      ? const Color(0xFFE0E0E0)
                      : rank == 3
                      ? const Color(0xFFFFAB91)
                      : AppPalette.accentPurple;
                  final name = (row.displayName ?? 'Player').trim();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppPalette.borderSoft),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: rankColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: rankColor.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Text(
                            '#$rank',
                            style: TextStyle(
                              color: rankColor,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isEmpty ? 'Player' : name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppPalette.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _StatChip(
                                    label: 'Stage ${row.maxStage ?? 1}',
                                  ),
                                  _StatChip(
                                    label: 'Trophies ${row.totalTrophies ?? 0}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppPalette.borderSoft),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppPalette.neonGreen,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
