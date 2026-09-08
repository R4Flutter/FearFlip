// Proves every character + devil animation frame is declared in pubspec and
// loadable through the SAME API the game uses (`rootBundle.load`). If this
// passes but the game still shows the green fallback, the cause is a stale
// build/install, not the assets or the code.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const prefixes = <String>['sentinel', 'phantom', 'void_ripper', 'devil'];
  const frameCount = 7; // must match _animationFrameCount in game_screen.dart

  for (final prefix in prefixes) {
    group('$prefix frames', () {
      for (var i = 1; i <= frameCount; i++) {
        final path = 'assets/images/${prefix}_frames/$prefix$i.png';
        test('loads $path', () async {
          final data = await rootBundle.load(path);
          expect(
            data.lengthInBytes,
            greaterThan(0),
            reason: '$path is empty or missing from the asset bundle',
          );
        });
      }
    });
  }
}
