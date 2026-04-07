import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/local_session_database.dart';
import '../../domain/usecases/start_survival_use_case.dart';
import '../../game/game.dart';
import '../../services/ads_service.dart';
import '../../services/auth_service.dart';
import '../../services/audio_service.dart';
import '../../services/leaderboard_service.dart';

class AppFlowProvider extends ChangeNotifier {
  static const String _joystickSizePrefKey = 'ui.joystick.size';
  static const String _selectedCharacterPrefKey = 'ui.character.index';
  static const double minJoystickSize = 90;
  static const double maxJoystickSize = 170;
  static const int characterCount = 3;
  static const int defaultCharacterIndex = 2;

  AppFlowProvider({
    required LocalSessionDatabase sessionDatabase,
    required StartSurvivalUseCase startSurvivalUseCase,
    AuthService? authService,
  }) : _sessionDatabase = sessionDatabase,
       _startSurvivalUseCase = startSurvivalUseCase,
       _authService = authService ?? AuthService() {
    _sessionDatabase.markAppLaunch();
    game = FearFlipGame(
      adsService: AdsService(),
      audioService: AudioService(),
      leaderboardService: StubLeaderboardService(),
    );
    _currentUser = _authService.currentUser;
    _authSubscription = _authService.authStateChanges.listen((user) {
      _currentUser = user;
      notifyListeners();
    });
    _loadUiSettings();
  }

  final LocalSessionDatabase _sessionDatabase;
  final StartSurvivalUseCase _startSurvivalUseCase;
  final AuthService _authService;
  StreamSubscription<User?>? _authSubscription;

  late final FearFlipGame game;

  User? _currentUser;
  bool _offlineGuestMode = false;
  String? _offlineGuestName;
  bool _isAuthenticating = false;
  String? _authError;
  bool _showLanding = true;
  bool _isStarting = false;
  double _joystickSize = 110;
  int _selectedCharacterIndex = defaultCharacterIndex;

  bool get showAuthGate => _currentUser == null && !_offlineGuestMode;
  bool get isAuthenticating => _isAuthenticating;
  String? get authError => _authError;
  String get playerName {
    if (_offlineGuestMode) {
      return _offlineGuestName ?? 'Guest';
    }
    final user = _currentUser;
    if (user == null) {
      return 'Guest';
    }
    final displayName = user.displayName?.trim() ?? '';
    if (displayName.isNotEmpty) {
      return displayName;
    }
    if (user.isAnonymous) {
      return 'Guest';
    }
    return user.email ?? 'Player';
  }

  bool get showLanding => _showLanding;
  bool get isStarting => _isStarting;
  double get joystickSize => _joystickSize;
  int get selectedCharacterIndex => _selectedCharacterIndex;

  Future<void> _loadUiSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJoystick = prefs.getDouble(_joystickSizePrefKey);
      final savedCharacter = prefs.getInt(_selectedCharacterPrefKey);

      var hasChanges = false;
      if (savedJoystick != null) {
        _joystickSize = savedJoystick.clamp(minJoystickSize, maxJoystickSize);
        hasChanges = true;
      }
      if (savedCharacter != null) {
        _selectedCharacterIndex = savedCharacter.clamp(0, characterCount - 1);
        hasChanges = true;
      }

      if (hasChanges) {
        notifyListeners();
      }
    } catch (_) {
      // Keep default size when local preferences are unavailable.
    }
  }

  Future<void> updateJoystickSize(double size) async {
    final normalized = size.clamp(minJoystickSize, maxJoystickSize);
    if ((_joystickSize - normalized).abs() < 0.01) {
      return;
    }

    _joystickSize = normalized;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_joystickSizePrefKey, _joystickSize);
    } catch (_) {
      // UI update stays applied for this session even if persistence fails.
    }
  }

  Future<void> updateSelectedCharacter(int index) async {
    final normalized = index.clamp(0, characterCount - 1);
    if (_selectedCharacterIndex == normalized) {
      return;
    }

    _selectedCharacterIndex = normalized;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_selectedCharacterPrefKey, _selectedCharacterIndex);
    } catch (_) {
      // Keep selected character for this session even if persistence fails.
    }
  }

  Future<void> signInWithGoogle() async {
    if (_isAuthenticating) {
      return;
    }
    _isAuthenticating = true;
    _authError = null;
    notifyListeners();

    try {
      await _authService.signInWithGoogle();
    } on AuthCancelledException {
      _authError = null;
    } on AuthConfigurationException catch (error) {
      _authError = error.message;
    } on FirebaseAuthException catch (error) {
      _authError = error.message ?? 'Google sign-in failed. Please try again.';
    } catch (_) {
      _authError = 'Unable to sign in with Google right now.';
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<void> playAsGuest() async {
    if (_isAuthenticating) {
      return;
    }
    _isAuthenticating = true;
    _authError = null;
    notifyListeners();

    try {
      await _authService.signInAsGuest();
      _offlineGuestMode = false;
      _offlineGuestName = null;
      _currentUser = _authService.currentUser;
      if (_currentUser != null) {
        await startSurvival();
      }
    } on FirebaseAuthException {
      // Launch-safe fallback: keep game playable even when Firebase guest auth
      // is unavailable (network, quota, or anonymous auth disabled).
      _offlineGuestMode = true;
      _offlineGuestName = _generateOfflineGuestName();
      _currentUser = null;
      _authError = null;
      await startSurvival();
    } catch (_) {
      _offlineGuestMode = true;
      _offlineGuestName = _generateOfflineGuestName();
      _currentUser = null;
      _authError = null;
      await startSurvival();
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  String _generateOfflineGuestName() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final shortTime = now.toRadixString(36).toUpperCase();
    final rand = Random.secure().nextInt(0xFFFF).toRadixString(36).toUpperCase();
    return 'GUEST-${shortTime.substring(max(0, shortTime.length - 4))}$rand';
  }

  Future<void> signOut() async {
    if (_isAuthenticating) {
      return;
    }

    _isAuthenticating = true;
    _authError = null;
    notifyListeners();

    try {
      await _authService.signOut();
      _offlineGuestMode = false;
      _offlineGuestName = null;
      _currentUser = null;
      _showLanding = true;
    } catch (_) {
      _authError = 'Sign out failed. Please try again.';
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<void> startSurvival() async {
    if (_isStarting || showAuthGate) {
      return;
    }

    _isStarting = true;
    notifyListeners();

    try {
      await _startSurvivalUseCase.call(game);
      _showLanding = false;
    } finally {
      _isStarting = false;
      notifyListeners();
    }
  }

  void returnToDashboard() {
    if (_showLanding) {
      return;
    }
    _showLanding = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
