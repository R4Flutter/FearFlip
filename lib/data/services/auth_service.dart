import '../../services/auth_service.dart' as infra;

class AuthDataService {
  AuthDataService({infra.AuthService? delegate})
    : _delegate = delegate ?? infra.AuthService();

  final infra.AuthService _delegate;

  Future<void> signInWithGoogle() => _delegate.signInWithGoogle();

  Future<void> signInAsGuest() => _delegate.signInAsGuest();

  Future<void> signOut() => _delegate.signOut();
}
