import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthCancelledException implements Exception {}

class AuthConfigurationException implements Exception {
  AuthConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  static const String _googleServerClientId =
      '158165984868-bvqagc5kubdo3cmpkr3ccrhufd2ksl6i.apps.googleusercontent.com';

  AuthService({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  User? get currentUser => _firebaseAuth.currentUser;
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

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

    await _googleSignIn.initialize(serverClientId: _googleServerClientId);
    // Force chooser so player can pick from available Google accounts.
    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    late final GoogleSignInAccount account;
    try {
      account = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw AuthCancelledException();
      }
      rethrow;
    }

    final authentication = account.authentication;
    if (authentication.idToken == null || authentication.idToken!.isEmpty) {
      throw AuthConfigurationException(
        'Google Sign-In is not fully configured for this app build. '
        'Add SHA-1 and SHA-256 in Firebase Android app settings, then run '
        'FlutterFire configure again and rebuild.',
      );
    }

    final credential = GoogleAuthProvider.credential(
      idToken: authentication.idToken,
    );

    if (existing != null && existing.isAnonymous) {
      try {
        return await existing.linkWithCredential(credential);
      } on FirebaseAuthException catch (error) {
        if (error.code != 'credential-already-in-use') {
          rethrow;
        }
      }
    }

    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return _firebaseAuth.signInWithCredential(credential);
    }

    final provider = GoogleAuthProvider();
    try {
      return _firebaseAuth.signInWithProvider(provider);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'operation-not-supported-in-this-environment') {
        return _firebaseAuth.signInWithCredential(credential);
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore third-party sign out errors and always ensure Firebase sign out.
    }
    await _firebaseAuth.signOut();
  }
}
