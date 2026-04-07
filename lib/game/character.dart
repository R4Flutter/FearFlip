import 'package:flame/components.dart';

class FearFlipCharacter {
  const FearFlipCharacter({
    required this.id,
    required this.name,
    required this.sourcePosition,
    required this.sourceSize,
  });

  final String id;
  final String name;
  final Vector2 sourcePosition;
  final Vector2 sourceSize;

  static const String spriteSheetAsset = 'characters.png';

  static final List<FearFlipCharacter> catalog = <FearFlipCharacter>[
    FearFlipCharacter(
      id: 'blonde_guardian',
      name: 'Blonde Guardian',
      sourcePosition: Vector2(0, 0),
      sourceSize: Vector2(256, 256),
    ),
    FearFlipCharacter(
      id: 'turban_fighter',
      name: 'Turban Fighter',
      sourcePosition: Vector2(256, 0),
      sourceSize: Vector2(256, 256),
    ),
    FearFlipCharacter(
      id: 'spear_raider',
      name: 'Spear Raider',
      sourcePosition: Vector2(512, 0),
      sourceSize: Vector2(256, 256),
    ),
    FearFlipCharacter(
      id: 'sword_knight',
      name: 'Sword Knight',
      sourcePosition: Vector2(0, 256),
      sourceSize: Vector2(256, 256),
    ),
    FearFlipCharacter(
      id: 'pink_shadow',
      name: 'Pink Shadow',
      sourcePosition: Vector2(256, 256),
      sourceSize: Vector2(256, 256),
    ),
    FearFlipCharacter(
      id: 'ember_rogue',
      name: 'Ember Rogue',
      sourcePosition: Vector2(512, 256),
      sourceSize: Vector2(256, 256),
    ),
  ];
}
