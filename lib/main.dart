import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/fear_flip_app.dart';
import 'config/app_runtime_config.dart';
import 'firebase_options.dart';
import 'services/ads_facade.dart';
import 'services/consent_service.dart';
import 'services/error_reporter.dart';
import 'services/purchase_service.dart';

export 'app/fear_flip_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Log production readiness warnings instead of crashing the app.
  final readinessIssues = AppRuntimeConfig.productionReadinessIssues();
  if (readinessIssues.isNotEmpty) {
    for (final issue in readinessIssues) {
      debugPrint('[ProductionReady][WARN] $issue');
    }
  }

  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (error, stackTrace) {
    firebaseReady = false;
    ErrorReporter.report(
      reason: 'firebase_init_failed',
      error: error,
      stackTrace: stackTrace,
    );
  }

  if (firebaseReady && !kIsWeb) {
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
  }

  ErrorWidget.builder = (details) {
    return const Material(
      color: Color(0xFF101010),
      child: Center(
        child: Text(
          'Something went wrong. Please restart the game.',
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  };

  // Initialise subscription service before ads – ensures paying users never
  // see ads on cold start (cached status is applied synchronously).
  try {
    await PurchaseService.instance.init();
  } catch (e) {
    debugPrint('[Startup][WARN] PurchaseService init failed: $e');
  }

  // Launch the app immediately — consent & ad initialisation continue in the
  // background so the user sees the UI without waiting for network SDKs.
  // AdsFacade/preload internally gates on consent, so nothing shows until
  // the consent flow completes and SDKs are ready.
  unawaited(
    (() async {
      try {
        await ConsentService.instance
            .gatherConsentAndInitializeAds()
            .timeout(const Duration(seconds: 20));
      } catch (error, stackTrace) {
        debugPrint('[Startup][WARN] Consent/ads init failed: $error');
        if (kDebugMode) {
          debugPrint(stackTrace.toString());
        }
      }

      try {
        await AdsFacade.instance.start();
      } catch (error, stackTrace) {
        debugPrint('[Startup][WARN] AdsFacade start failed: $error');
        if (kDebugMode) {
          debugPrint(stackTrace.toString());
        }
      }
    })(),
  );

  if (!kIsWeb) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  runZonedGuarded(
    () {
      runApp(const FearFlipApp());
    },
    (error, stackTrace) {
      ErrorReporter.report(
        reason: 'zone_uncaught',
        error: error,
        stackTrace: stackTrace,
        fatal: true,
      );
    },
  );
}
