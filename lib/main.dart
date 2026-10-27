import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'arcade/arcade_app.dart';
import 'firebase_options.dart';
import 'services/ads_facade.dart';
import 'services/consent_service.dart';
import 'services/error_reporter.dart';

export 'app/fear_flip_app.dart';

/// FearFlip opens straight on the dashboard: no sign-in and no consent wall.
///
/// On the web (CrazyGames) nothing else starts: no Firebase, no phone ad
/// networks; the CrazyGames SDK in web/index.html handles ads and saves.
/// On phones Firebase crash reports and the ad networks (with Google's own
/// consent form where the law requires it) start in the background.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (details) {
    return const Material(
      color: Color(0xFF0A0A0F),
      child: Center(
        child: Text(
          'Something went wrong. Please reload the game.',
          style: TextStyle(color: Color(0xFFF0E6D2)),
          textAlign: TextAlign.center,
        ),
      ),
    );
  };

  if (!kIsWeb) {
    await _startMobileServices();
  }

  runZonedGuarded(
    () => runApp(const ArcadeApp()),
    (error, stackTrace) => ErrorReporter.report(
      reason: 'zone_uncaught',
      error: error,
      stackTrace: stackTrace,
      fatal: true,
    ),
  );
}

Future<void> _startMobileServices() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
    FlutterError.onError = (details) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        fatal: true,
        reason: 'platform_dispatcher_uncaught',
      );
      return true;
    };
  } catch (error, stackTrace) {
    ErrorReporter.report(
      reason: 'firebase_init_failed',
      error: error,
      stackTrace: stackTrace,
    );
  }

  // Ads start in the background; nothing shows until consent is settled.
  unawaited(() async {
    try {
      await ConsentService.instance.gatherConsentAndInitializeAds().timeout(
        const Duration(seconds: 20),
      );
      await AdsFacade.instance.start();
    } catch (error) {
      debugPrint('[Startup][WARN] Consent/ads init failed: $error');
    }
  }());

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}
