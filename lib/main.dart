import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app/fear_flip_app.dart';
import 'firebase_options.dart';

export 'app/fear_flip_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (_) {
    firebaseReady = false;
  }

  if (firebaseReady) {
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

  try {
    await MobileAds.instance.initialize();
  } catch (_) {
    // Keep app playable when ads SDK is unavailable.
  }
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const FearFlipApp());
}
