import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/fear_flip_app.dart';
import 'config/app_runtime_config.dart';
import 'firebase_options.dart';
import 'services/consent_service.dart';
import 'services/purchase_service.dart';

export 'app/fear_flip_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppRuntimeConfig.assertProductionReady();

  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (_) {
    firebaseReady = false;
  }

  if (firebaseReady && !kIsWeb) {
    FlutterError.onError = (details) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
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

  if (!kIsWeb) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  runApp(const FearFlipApp());
}
