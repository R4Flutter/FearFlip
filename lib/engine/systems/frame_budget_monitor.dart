import 'dart:developer' as developer;

class FrameBudgetMonitor {
  const FrameBudgetMonitor({this.frameBudgetMs = 16});

  final int frameBudgetMs;

  void onFrame(Duration frameDuration) {
    if (frameDuration.inMilliseconds > frameBudgetMs) {
      developer.log(
        'Frame budget exceeded: ${frameDuration.inMilliseconds}ms > ${frameBudgetMs}ms',
        name: 'fearflip.performance',
      );
    }
  }
}
