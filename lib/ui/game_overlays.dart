import 'package:flame/game.dart';
import 'package:flame/widgets.dart';
import 'package:flutter/material.dart';

import '../game/character.dart';
import '../game/game.dart';

class MainMenuOverlay extends StatefulWidget {
  const MainMenuOverlay({required this.game, super.key});

  final FearFlipGame game;

  @override
  State<MainMenuOverlay> createState() => _MainMenuOverlayState();
}

class _MainMenuOverlayState extends State<MainMenuOverlay> {
  late FearFlipCharacter _selectedCharacter;

  @override
  void initState() {
    super.initState();
    _selectedCharacter = widget.game.selectedCharacter;
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final characters = game.availableCharacters;

    return Container(
      color: const Color(0xD8000000),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            color: const Color(0xFF111111),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'FearFlip',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF00E5FF),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Reach the goal before reality flips and the Devil catches you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choose Character',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 170,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: characters.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.02,
                          ),
                      itemBuilder: (context, index) {
                        final character = characters[index];
                        final sprite = game.spriteForCharacter(character);
                        final isSelected =
                            character.id == _selectedCharacter.id;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCharacter = character;
                            });
                          },
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF00E5FF)
                                    : const Color(0xFF343434),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: sprite != null
                                          ? SpriteWidget(sprite: sprite)
                                          : const Icon(
                                              Icons.person,
                                              size: 34,
                                              color: Color(0xFFB0BEC5),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    character.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (game.spriteForCharacter(_selectedCharacter) == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        'Add assets/images/characters.png to use your character sheet.',
                        style: TextStyle(
                          color: Color(0xFFFFAB91),
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    const SizedBox(height: 12),
                  _MenuButton(
                    label: 'Start Normal Mode',
                    color: const Color(0xFF00C853),
                    onTap: () => game.startNewGame(
                      FearFlipMode.normal,
                      character: _selectedCharacter,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _MenuButton(
                    label: 'Start Memory Mode',
                    color: const Color(0xFFFF6D00),
                    onTap: () => game.startNewGame(
                      FearFlipMode.memory,
                      character: _selectedCharacter,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HudOverlay extends StatelessWidget {
  const HudOverlay({required this.game, super.key});

  final FearFlipGame game;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLandscape = media.orientation == Orientation.landscape;
    final controlsRight = media.padding.right + 16;
    final controlsBottom = media.padding.bottom + 16;
    final controlsSize = isLandscape ? 156.0 : 140.0;

    return ValueListenableBuilder<HudState>(
      valueListenable: game.hud,
      builder: (context, hud, _) {
        final flipLabel = 'FLIP ${hud.secondsUntilFlip.toStringAsFixed(1)}s';
        return Stack(
          children: [
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x9A000000),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runSpacing: 8,
                    spacing: 10,
                    children: [
                      _HudPill(
                        label: 'TIME ${hud.secondsAlive}s',
                        color: const Color(0xFF00E5FF),
                      ),
                      _HudPill(
                        label: flipLabel,
                        color: hud.warningActive
                            ? const Color(0xFFFF5252)
                            : Colors.white,
                      ),
                      _HudModeChip(
                        label: 'NORMAL',
                        active: hud.mode == FearFlipMode.normal,
                      ),
                      _HudModeChip(
                        label: 'MEMORY',
                        active: hud.mode == FearFlipMode.memory,
                      ),
                      _HudPill(
                        label: hud.controlsInverted ? 'INVERTED' : 'NORMAL',
                        color: hud.controlsInverted
                            ? const Color(0xFFFF1744)
                            : const Color(0xFF00E5FF),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 76,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  hud.warningActive ? 'REALITY FLIP IMMINENT' : '',
                  style: const TextStyle(
                    color: Color(0xFFFF5252),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            if (isLandscape)
              Positioned(
                right: controlsRight,
                bottom: controlsBottom,
                child: _DPad(game: game, size: controlsSize),
              )
            else
              Positioned(
                bottom: controlsBottom,
                left: 0,
                right: 0,
                child: Center(
                  child: _DPad(game: game, size: controlsSize),
                ),
              ),
            if (hud.memoryHidden)
              const Positioned(
                bottom: 16,
                left: 16,
                child: _HudPill(label: 'MAZE HIDDEN', color: Color(0xFFFFAB40)),
              ),
          ],
        );
      },
    );
  }
}

class _HudPill extends StatelessWidget {
  const _HudPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x55000000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _HudModeChip extends StatelessWidget {
  const _HudModeChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final accent = active ? const Color(0xFF76FF03) : const Color(0xFF8D8D8D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0x66212300) : const Color(0x44000000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class GameResultOverlay extends StatelessWidget {
  const GameResultOverlay({required this.game, required this.win, super.key});

  final FearFlipGame game;
  final bool win;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HudState>(
      valueListenable: game.hud,
      builder: (context, hud, _) {
        return Container(
          color: const Color(0xCE000000),
          child: Center(
            child: Card(
              color: const Color(0xFF101010),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      win ? 'You Escaped' : 'Caught by the Devil',
                      style: TextStyle(
                        color: win
                            ? const Color(0xFF00E676)
                            : const Color(0xFFFF5252),
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Survival: ${hud.secondsAlive}s',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 14),
                    _MenuButton(
                      label: 'Restart',
                      color: const Color(0xFF00E5FF),
                      onTap: game.restartRound,
                    ),
                    if (!win) ...[
                      const SizedBox(height: 10),
                      _MenuButton(
                        label: hud.canRevive
                            ? 'Revive (Rewarded Ad)'
                            : 'Revive Used',
                        color: const Color(0xFFFFAB00),
                        onTap: hud.canRevive ? game.tryRevive : null,
                      ),
                    ],
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

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.35),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _DPad extends StatefulWidget {
  const _DPad({required this.game, required this.size});

  final FearFlipGame game;
  final double size;

  @override
  State<_DPad> createState() => _DPadState();
}

class _DPadState extends State<_DPad> {
  void _set(double x, double y) {
    widget.game.setInputDirection(Vector2(x, y));
  }

  @override
  Widget build(BuildContext context) {
    final buttonSize = widget.size * 0.32;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _PadButton(
            alignment: Alignment.topCenter,
            icon: Icons.keyboard_arrow_up,
            size: buttonSize,
            onDown: () => _set(0, -1),
            onUp: () => _set(0, 0),
          ),
          _PadButton(
            alignment: Alignment.bottomCenter,
            icon: Icons.keyboard_arrow_down,
            size: buttonSize,
            onDown: () => _set(0, 1),
            onUp: () => _set(0, 0),
          ),
          _PadButton(
            alignment: Alignment.centerLeft,
            icon: Icons.keyboard_arrow_left,
            size: buttonSize,
            onDown: () => _set(-1, 0),
            onUp: () => _set(0, 0),
          ),
          _PadButton(
            alignment: Alignment.centerRight,
            icon: Icons.keyboard_arrow_right,
            size: buttonSize,
            onDown: () => _set(1, 0),
            onUp: () => _set(0, 0),
          ),
        ],
      ),
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({
    required this.alignment,
    required this.icon,
    required this.size,
    required this.onDown,
    required this.onUp,
  });

  final Alignment alignment;
  final IconData icon;
  final double size;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTapDown: (_) => onDown(),
        onTapUp: (_) => onUp(),
        onTapCancel: onUp,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xAA0E0E0E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x6600E5FF)),
          ),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

Map<String, OverlayWidgetBuilder<FearFlipGame>> buildOverlayBuilders(
  FearFlipGame game,
) {
  return {
    'menu': (context, game) => MainMenuOverlay(game: game),
    'hud': (context, game) => const SizedBox.shrink(),
    'gameOver': (context, game) => GameResultOverlay(game: game, win: false),
    'win': (context, game) => GameResultOverlay(game: game, win: true),
  };
}
