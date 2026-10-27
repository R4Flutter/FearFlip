import 'package:flutter/foundation.dart';

/// Whether the player has touched the screen anywhere in the app: the maze
/// then shows its touch pad (a phone, a tablet, a touch laptop).
abstract final class InputMode {
  static final ValueNotifier<bool> touchSeen = ValueNotifier<bool>(
    defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS,
  );
}
