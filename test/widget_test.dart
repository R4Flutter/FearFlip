import 'package:flutter_test/flutter_test.dart';
import 'package:flame/game.dart';

import 'package:fearflipgame/main.dart';
import 'package:fearflipgame/game/game.dart';

void main() {
  testWidgets('FearFlip mounts game widget', (WidgetTester tester) async {
    await tester.pumpWidget(const FearFlipApp());
    await tester.pump();

    expect(find.byType(GameWidget<FearFlipGame>), findsOneWidget);
  });
}
