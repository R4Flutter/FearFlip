import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fearflipgame/services/account_deletion_service.dart';

class _FakeDeletionGateway implements AccountDeletionGateway {
  _FakeDeletionGateway({
    this.identity = const AccountDeletionIdentity(
      uid: 'user-1',
      isAnonymous: false,
      email: 'player@example.com',
      displayName: 'Player',
    ),
    this.queueFails = false,
    this.deleteError,
  });

  final AccountDeletionIdentity? identity;
  final bool queueFails;
  final Object? deleteError;

  var queued = false;
  var deleted = false;
  var signedOut = false;

  @override
  Future<AccountDeletionIdentity?> currentIdentity() async => identity;

  @override
  Future<void> queueDeletionRequest(AccountDeletionIdentity identity) async {
    if (queueFails) {
      throw StateError('queue failed');
    }
    queued = true;
  }

  @override
  Future<void> deleteCurrentAccount() async {
    final error = deleteError;
    if (error != null) {
      throw error;
    }
    deleted = true;
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

void main() {
  test('returns noSignedInUser when no account is active', () async {
    final gateway = _FakeDeletionGateway(identity: null);
    final service = AccountDeletionService(gateway: gateway);

    final result = await service.requestDeletion();

    expect(result.status, AccountDeletionStatus.noSignedInUser);
    expect(result.shouldReturnToAuthGate, isTrue);
    expect(gateway.queued, isFalse);
  });

  test('queues request and deletes current account', () async {
    final gateway = _FakeDeletionGateway();
    final service = AccountDeletionService(gateway: gateway);

    final result = await service.requestDeletion();

    expect(result.status, AccountDeletionStatus.deleted);
    expect(gateway.queued, isTrue);
    expect(gateway.deleted, isTrue);
    expect(gateway.signedOut, isFalse);
  });

  test('queues support request when recent login is required', () async {
    final gateway = _FakeDeletionGateway(
      deleteError: FirebaseAuthException(code: 'requires-recent-login'),
    );
    final service = AccountDeletionService(gateway: gateway);

    final result = await service.requestDeletion();

    expect(result.status, AccountDeletionStatus.queuedForSupport);
    expect(result.shouldReturnToAuthGate, isTrue);
    expect(gateway.queued, isTrue);
    expect(gateway.signedOut, isTrue);
  });

  test('fails safely when request and deletion both fail', () async {
    final gateway = _FakeDeletionGateway(
      queueFails: true,
      deleteError: StateError('delete failed'),
    );
    final service = AccountDeletionService(gateway: gateway);

    final result = await service.requestDeletion();

    expect(result.status, AccountDeletionStatus.failed);
    expect(result.shouldReturnToAuthGate, isFalse);
    expect(gateway.signedOut, isFalse);
  });
}
