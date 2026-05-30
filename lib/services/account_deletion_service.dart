import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'error_reporter.dart';

class AccountDeletionIdentity {
  const AccountDeletionIdentity({
    required this.uid,
    required this.isAnonymous,
    this.email,
    this.displayName,
  });

  final String uid;
  final bool isAnonymous;
  final String? email;
  final String? displayName;
}

enum AccountDeletionStatus { deleted, queuedForSupport, noSignedInUser, failed }

class AccountDeletionResult {
  const AccountDeletionResult({required this.status, required this.message});

  final AccountDeletionStatus status;
  final String message;

  bool get shouldReturnToAuthGate =>
      status == AccountDeletionStatus.deleted ||
      status == AccountDeletionStatus.queuedForSupport ||
      status == AccountDeletionStatus.noSignedInUser;
}

abstract class AccountDeletionGateway {
  Future<AccountDeletionIdentity?> currentIdentity();
  Future<void> queueDeletionRequest(AccountDeletionIdentity identity);
  Future<void> deleteCurrentAccount();
  Future<void> signOut();
}

class FirebaseAccountDeletionGateway implements AccountDeletionGateway {
  FirebaseAccountDeletionGateway({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Future<AccountDeletionIdentity?> currentIdentity() async {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }

    return AccountDeletionIdentity(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      isAnonymous: user.isAnonymous,
    );
  }

  @override
  Future<void> queueDeletionRequest(AccountDeletionIdentity identity) {
    return _firestore
        .collection('accountDeletionRequests')
        .doc(identity.uid)
        .set(<String, Object?>{
          'uid': identity.uid,
          'email': identity.email,
          'displayName': identity.displayName,
          'isAnonymous': identity.isAnonymous,
          'status': 'requested',
          'source': 'in_app',
          'requestedAt': FieldValue.serverTimestamp(),
          'clientTimestampMs': DateTime.now().millisecondsSinceEpoch,
        });
  }

  @override
  Future<void> deleteCurrentAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }
    await user.delete();
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

class AccountDeletionService {
  AccountDeletionService({AccountDeletionGateway? gateway})
    : _gateway = gateway ?? FirebaseAccountDeletionGateway();

  final AccountDeletionGateway _gateway;

  Future<AccountDeletionResult> requestDeletion() async {
    final identity = await _gateway.currentIdentity();
    if (identity == null) {
      return const AccountDeletionResult(
        status: AccountDeletionStatus.noSignedInUser,
        message: 'No signed-in account is active on this device.',
      );
    }

    var deletionRequestQueued = false;
    try {
      await _gateway.queueDeletionRequest(identity);
      deletionRequestQueued = true;
    } catch (error, stackTrace) {
      deletionRequestQueued = false;
      ErrorReporter.report(
        reason: 'account_deletion_queue_failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'uid': identity.uid},
      );
    }

    try {
      await _gateway.deleteCurrentAccount();
      return const AccountDeletionResult(
        status: AccountDeletionStatus.deleted,
        message: 'Account deletion completed on this device.',
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == 'requires-recent-login' && deletionRequestQueued) {
        await _gateway.signOut();
        return const AccountDeletionResult(
          status: AccountDeletionStatus.queuedForSupport,
          message:
              'Deletion request queued. Sign in again if support asks you to confirm ownership.',
        );
      }

      if (deletionRequestQueued) {
        await _gateway.signOut();
        return AccountDeletionResult(
          status: AccountDeletionStatus.queuedForSupport,
          message:
              'Deletion request queued, but immediate account removal needs support review (${error.code}).',
        );
      }

      return AccountDeletionResult(
        status: AccountDeletionStatus.failed,
        message: error.message ?? 'Account deletion failed. Please try again.',
      );
    } catch (error, stackTrace) {
      ErrorReporter.report(
        reason: 'account_deletion_failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'uid': identity.uid,
          'queued': deletionRequestQueued,
        },
      );
      if (deletionRequestQueued) {
        await _gateway.signOut();
        return const AccountDeletionResult(
          status: AccountDeletionStatus.queuedForSupport,
          message:
              'Deletion request queued. Support will complete backend cleanup if needed.',
        );
      }

      return const AccountDeletionResult(
        status: AccountDeletionStatus.failed,
        message:
            'Account deletion could not be requested. Check your connection and try again.',
      );
    }
  }
}
