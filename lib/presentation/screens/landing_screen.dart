import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../widgets/landing_ghost_button.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({
    required this.isStarting,
    required this.onPlay,
    required this.onChooseCharacter,
    required this.onSettings,
    required this.playerName,
    super.key,
  });

  final bool isStarting;
  final VoidCallback onPlay;
  final VoidCallback onChooseCharacter;
  final VoidCallback onSettings;
  final String playerName;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        final widthScale = (screenWidth / 390).clamp(0.84, 1.18).toDouble();
        final heightScale = (screenHeight / 844).clamp(0.82, 1.1).toDouble();

        final horizontalPadding =
            (24 * widthScale).clamp(16.0, 30.0).toDouble();
        final verticalPadding =
            (20 * heightScale).clamp(14.0, 26.0).toDouble();

        final actionGap = (14 * heightScale).clamp(10.0, 18.0).toDouble();
        final titleTopGap = (28 * heightScale).clamp(20.0, 34.0).toDouble();
        final gapBeforeActions =
            (130 * heightScale).clamp(62.0, 132.0).toDouble();

        final actionWidth = (screenWidth * 0.86).clamp(280.0, 430.0).toDouble();
        final titleSize = (58 * widthScale).clamp(44.0, 64.0).toDouble();
        final buttonFontSize = (22 * widthScale).clamp(18.0, 24.0).toDouble();
        final ghostFontSize = (20 * widthScale).clamp(16.0, 22.0).toDouble();
        final ghostIconSize = (34 * widthScale).clamp(28.0, 38.0).toDouble();
        final ghostVerticalPadding =
            (18 * heightScale).clamp(13.0, 20.0).toDouble();

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
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: screenHeight - (verticalPadding * 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Level-01',
                          style: TextStyle(
                            color: AppPalette.neonGreen,
                            fontWeight: FontWeight.w800,
                            fontSize: (22 * widthScale)
                                .clamp(16.0, 24.0)
                                .toDouble(),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              playerName.toUpperCase(),
                              style: TextStyle(
                                color: AppPalette.accentPurple,
                                fontWeight: FontWeight.w800,
                                fontSize: (14 * widthScale)
                                    .clamp(11.0, 16.0)
                                    .toDouble(),
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              'FLIP IN & ESCAPE',
                              style: TextStyle(
                                color: AppPalette.neonGreen,
                                fontWeight: FontWeight.w800,
                                fontSize: (16 * widthScale)
                                    .clamp(12.0, 18.0)
                                    .toDouble(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: titleTopGap),
                    Center(
                      child: Text(
                        'FEARFLIP',
                        style: TextStyle(
                          color: AppPalette.accentPurple,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          fontSize: titleSize,
                          shadows: const [
                            Shadow(
                              color: Color(0xFF39FF14),
                              offset: Offset(5, 0),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: gapBeforeActions),
                    Center(
                      child: SizedBox(
                        width: actionWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppPalette.accentPink,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(0),
                                ),
                                padding: EdgeInsets.symmetric(
                                  vertical: (20 * heightScale)
                                      .clamp(15.0, 24.0)
                                      .toDouble(),
                                ),
                              ),
                              onPressed: isStarting ? null : onPlay,
                              child: Text(
                                isStarting ? 'LOADING...' : 'START SURVIVAL',
                                style: TextStyle(
                                  fontSize: buttonFontSize,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            SizedBox(height: actionGap + 6),
                            LandingGhostButton(
                              label: '> CHOOSE CHARACTER',
                              icon: Icons.person,
                              onTap: onChooseCharacter,
                              fontSize: ghostFontSize,
                              iconSize: ghostIconSize,
                              verticalPadding: ghostVerticalPadding,
                            ),
                            SizedBox(height: actionGap),
                            LandingGhostButton(
                              label: '> SETTINGS',
                              icon: Icons.settings,
                              onTap: onSettings,
                              fontSize: ghostFontSize,
                              iconSize: ghostIconSize,
                              verticalPadding: ghostVerticalPadding,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      height: (28 * heightScale).clamp(22.0, 34.0).toDouble(),
                    ),
                    Text(
                      'GLOBAL PANIC LEADERBOARD',
                      style: TextStyle(
                        color: AppPalette.neonGreen,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        fontSize:
                            (14 * widthScale).clamp(12.0, 16.0).toDouble(),
                      ),
                    ),
                    SizedBox(
                      height: (10 * heightScale).clamp(8.0, 14.0).toDouble(),
                    ),
                    Text(
                      'Rank: #1402',
                      style: TextStyle(
                        color: AppPalette.accentPurple,
                        fontWeight: FontWeight.w900,
                        fontSize:
                            (44 * widthScale).clamp(32.0, 48.0).toDouble(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
