import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_runtime_config.dart';

class AuthCancelledException implements Exception {}

class AuthConfigurationException implements Exception {
  AuthConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthSignInFailedException implements Exception {
  AuthSignInFailedException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  bool _googleSignInInitialized = false;

  User? get currentUser => _firebaseAuth.currentUser;
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) {
      return;
    }

    try {
      final configuredServerClientId = AppRuntimeConfig.googleServerClientId;
      if (configuredServerClientId.isEmpty) {
        await _googleSignIn.initialize();
      } else {
        await _googleSignIn.initialize(
          serverClientId: configuredServerClientId,
        );
      }
    } on PlatformException catch (error) {
      throw _mapPlatformException(error);
    } on GoogleSignInException catch (error) {
      throw _mapGoogleSignInException(error);
    }

    _googleSignInInitialized = true;
  }

  Exception _mapGoogleSignInException(GoogleSignInException error) {
    final code = error.code.toString().toLowerCase();

    if (code.contains('canceled')) {
      return AuthCancelledException();
    }

    if (code.contains('clientconfiguration') ||
        code.contains('configuration') ||
        code.contains('developererror') ||
        code.contains('sign_in_failed')) {
      return AuthConfigurationException(
        'Google Sign-In configuration error. Verify Android SHA-1/SHA-256 in Firebase, '
        'download the latest google-services.json, then rebuild the app.',
      );
    }

    if (code.contains('network') || code.contains('timeout')) {
      return AuthSignInFailedException(
        'Google Sign-In needs an internet connection. Check your network and try again.',
      );
    }

    if (code.contains('play') || code.contains('services')) {
      return AuthSignInFailedException(
        'Google Play Services is unavailable or outdated on this device.',
      );
    }

    return AuthSignInFailedException(
      'Google Sign-In failed (${error.code}). Please try again.',
    );
  }

  Exception _mapPlatformException(PlatformException error) {
    final code = error.code.toLowerCase();
    final message = (error.message ?? '').toLowerCase();
    final details = '$code $message';

    if (details.contains('canceled') || details.contains('cancelled')) {
      return AuthCancelledException();
    }

    if (details.contains('network') || details.contains('timeout')) {
      return AuthSignInFailedException(
        'Google Sign-In needs an internet connection. Check your network and try again.',
      );
    }

    if (details.contains('developer_error') ||
        details.contains('configuration') ||
        details.contains('client') ||
        details.contains('sign_in_failed') ||
        details.contains('10')) {
      return AuthConfigurationException(
        'Google Sign-In configuration error. Verify package name, SHA-1/SHA-256, and OAuth client setup in Firebase, then download a fresh google-services.json and rebuild.',
      );
    }

    if (details.contains('play services') || details.contains('google_play')) {
      return AuthSignInFailedException(
        'Google Play Services is unavailable or outdated on this device.',
      );
    }

    return AuthSignInFailedException(
      'Google Sign-In failed (${error.code}). Please try again.',
    );
  }

  String? _readAccessTokenSafely(Object authentication) {
    try {
      final dynamic dynamicAuth = authentication;
      final rawAccessToken = dynamicAuth.accessToken;
      if (rawAccessToken is String) {
        final token = rawAccessToken.trim();
        if (token.isNotEmpty) {
          return token;
        }
      }
    } catch (_) {
      // accessToken is not available on all plugin versions/platforms.
    }
    return null;
  }

  Exception _mapFirebaseAuthException(FirebaseAuthException error) {
    final code = error.code.toLowerCase();

    if (code == 'operation-not-allowed') {
      return AuthConfigurationException(
        'Google provider is disabled in Firebase Auth. Enable Google sign-in in Firebase Console -> Authentication -> Sign-in method.',
      );
    }

    if (code == 'invalid-credential' ||
        code == 'invalid-idp-response' ||
        code == 'invalid-verification-code' ||
        code == 'missing-or-invalid-nonce') {
      return AuthConfigurationException(
        'Google credential was rejected. Verify package name, SHA-1, SHA-256, and OAuth client setup in Firebase, then download a fresh google-services.json and rebuild.',
      );
    }

    if (code == 'network-request-failed') {
      return AuthSignInFailedException(
        'Network error during Google sign-in. Check internet connection and try again.',
      );
    }

    if (code == 'too-many-requests') {
      return AuthSignInFailedException(
        'Too many sign-in attempts. Wait a moment and try again.',
      );
    }

    if (code == 'account-exists-with-different-credential') {
      return AuthSignInFailedException(
        'This email is already linked with another sign-in method. Use that method first, then link Google from account settings.',
      );
    }

    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) {
      return AuthSignInFailedException(message);
    }

    return AuthSignInFailedException(
      'Google Sign-In failed (${error.code}). Please try again.',
    );
  }

  Future<UserCredential> signInAsGuest() async {
    final credential = await _firebaseAuth.signInAnonymously();
    final user = credential.user;
    if (user == null) {
      return credential;
    }

    final existingName = user.displayName?.trim() ?? '';
    if (existingName.isNotEmpty) {
      return credential;
    }

    await user.updateDisplayName(_generateGuestId());
    await user.reload();
    return credential;
  }

  String _generateGuestId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final timePart = now.toRadixString(36).toUpperCase();
    final randomPart = Random.secure()
        .nextInt(0xFFFFFF)
        .toRadixString(36)
        .padLeft(4, '0')
        .toUpperCase();
    final shortTime = timePart.length > 4
        ? timePart.substring(timePart.length - 4)
        : timePart;
    return 'GUEST-$shortTime$randomPart';
  }

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      return _firebaseAuth.signInWithPopup(provider);
    }

    final existing = _firebaseAuth.currentUser;
    await _ensureGoogleSignInInitialized();

    // Clear cached provider session so users always get account picker.
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore sign-out failures and continue to explicit auth flow.
    }

    GoogleSignInAccount account;
    try {
      account = await _googleSignIn.authenticate();
    } on PlatformException catch (error) {
      throw _mapPlatformException(error);
    } on GoogleSignInException catch (error) {
      throw _mapGoogleSignInException(error);
    } catch (_) {
      throw AuthSignInFailedException(
        'Unable to sign in with Google right now. Please try again.',
      );
    }

    final authentication = (() {
      try {
        return account.authentication;
      } on PlatformException catch (error) {
        throw _mapPlatformException(error);
      } on GoogleSignInException catch (error) {
        throw _mapGoogleSignInException(error);
      }
    })();
    final idToken = authentication.idToken?.trim();
    final accessToken = _readAccessTokenSafely(authentication);
    final hasIdToken = idToken != null && idToken.isNotEmpty;
    final hasAccessToken = accessToken != null && accessToken.isNotEmpty;
    final isMobileNative =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    if (isMobileNative && !hasIdToken) {
      throw AuthConfigurationException(
        'Google Sign-In did not return an ID token. Configure Firebase Android/iOS OAuth with correct SHA-1/SHA-256 and provide the web client id in GOOGLE_SERVER_CLIENT_ID.',
      );
    }

    if (!hasIdToken && !hasAccessToken) {
      throw AuthConfigurationException(
        'Google Sign-In is not configured correctly for this build. '
        'Add SHA-1 and SHA-256 in Firebase Android app settings, then run '
        'FlutterFire configure again and rebuild. If needed, provide '
        '--dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.',
      );
    }

    final credential = GoogleAuthProvider.credential(
      idToken: hasIdToken ? idToken : null,
      accessToken: hasAccessToken ? accessToken : null,
    );

    if (existing != null && existing.isAnonymous) {
      try {
        return await existing.linkWithCredential(credential);
      } on FirebaseAuthException catch (error) {
        if (error.code != 'credential-already-in-use') {
          throw _mapFirebaseAuthException(error);
        }
      }
    }

    if (isMobileNative) {
      try {
        return await _firebaseAuth.signInWithCredential(credential);
      } on FirebaseAuthException catch (error) {
        throw _mapFirebaseAuthException(error);
      }
    }

    final provider = GoogleAuthProvider();
    try {
      return _firebaseAuth.signInWithProvider(provider);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'operation-not-supported-in-this-environment') {
        try {
          return await _firebaseAuth.signInWithCredential(credential);
        } on FirebaseAuthException catch (fallbackError) {
          throw _mapFirebaseAuthException(fallbackError);
        }
      }
      throw _mapFirebaseAuthException(error);
    }
  }

  Future<void> signOut({bool keepGoogleSession = false}) async {
    if (!keepGoogleSession) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Ignore third-party sign out errors and always ensure Firebase sign out.
      }
    }

    await _firebaseAuth.signOut();
  }
}
