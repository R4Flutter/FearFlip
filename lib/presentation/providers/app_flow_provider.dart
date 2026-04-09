import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/local_session_database.dart';
import '../../domain/usecases/start_survival_use_case.dart';
import '../../game/game.dart';
import '../controllers/game_controller.dart';
import '../../services/ads_service.dart';
import '../../services/auth_service.dart';
import '../../services/audio_service.dart';
import '../../services/leaderboard_service.dart';

class AppFlowProvider extends ChangeNotifier {
  static const String _joystickSizePrefKey = 'ui.joystick.size';
  static const String _selectedCharacterPrefKey = 'ui.character.index';
  static const String _arrowControllerPrefKey = 'ui.controller.arrow';
  static const String _totalTrophiesPrefKey = 'progress.total_trophies';
  static const String _maxStageReachedPrefKey = 'progress.max_stage_reached';
  static const double minJoystickSize = 90;
  static const double maxJoystickSize = 170;
  static const int characterCount = 2;
  static const int defaultCharacterIndex = 0;

  AppFlowProvider({
    required LocalSessionDatabase sessionDatabase,
    required StartSurvivalUseCase startSurvivalUseCase,
    AuthService? authService,
    bool enableAuthBootstrap = true,
    LeaderboardService? leaderboardService,
  }) : _sessionDatabase = sessionDatabase,
       _startSurvivalUseCase = startSurvivalUseCase,
       _authService =
           authService ?? (enableAuthBootstrap ? AuthService() : null) {
    _sessionDatabase.markAppLaunch();
    game = FearFlipGame(
      adsService: AdsService(),
      audioService: AudioService(),
      leaderboardService:
          leaderboardService ??
          (enableAuthBootstrap
              ? FirestoreLeaderboardService()
              : StubLeaderboardService()),
    );
    gameController = GameController();
    _currentUser = _authService?.currentUser;
    final authService = _authService;
    if (authService != null) {
      _authSubscription = authService.authStateChanges.listen((user) {
        _currentUser = user;
        if (user == null) {
          _globalPanicRank = null;
        } else {
          unawaited(_syncGlobalPanicProgress());
        }
        notifyListeners();
      });
    }
    _loadUiSettings();
  }

  final LocalSessionDatabase _sessionDatabase;
  final StartSurvivalUseCase _startSurvivalUseCase;
  final AuthService? _authService;
  StreamSubscription<User?>? _authSubscription;

  late final FearFlipGame game;
  late final GameController gameController;

  User? _currentUser;
  bool _offlineGuestMode = false;
  String? _offlineGuestName;
  bool _isAuthenticating = false;
  String? _authError;
  bool _showLanding = true;
  bool _isStarting = false;
  double _joystickSize = 110;
  int _selectedCharacterIndex = defaultCharacterIndex;
  bool _useArrowController = false;
  int _totalTrophies = 0;
  int _maxStageReached = 1;
  int? _globalPanicRank;

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
  bool get useArrowController => _useArrowController;
  int get totalTrophies => _totalTrophies;
  int get maxStageReached => _maxStageReached;
  int? get globalPanicRank => _globalPanicRank;

  Future<void> _loadUiSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJoystick = prefs.getDouble(_joystickSizePrefKey);
      final savedCharacter = prefs.getInt(_selectedCharacterPrefKey);
      final savedArrowController = prefs.getBool(_arrowControllerPrefKey);
      final savedTrophies = prefs.getInt(_totalTrophiesPrefKey);
      final savedMaxStage = prefs.getInt(_maxStageReachedPrefKey);

      var hasChanges = false;
      if (savedJoystick != null) {
        _joystickSize = savedJoystick.clamp(minJoystickSize, maxJoystickSize);
        hasChanges = true;
      }
      if (savedCharacter != null) {
        _selectedCharacterIndex = savedCharacter.clamp(0, characterCount - 1);
        hasChanges = true;
      }
      if (savedArrowController != null) {
        _useArrowController = savedArrowController;
        hasChanges = true;
      }
      if (savedTrophies != null) {
        _totalTrophies = savedTrophies.clamp(0, 9999999);
        hasChanges = true;
      }
      if (savedMaxStage != null) {
        _maxStageReached = savedMaxStage.clamp(1, 9999);
        hasChanges = true;
      }

      if (hasChanges) {
        notifyListeners();
      }

      unawaited(_syncGlobalPanicProgress());
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

  Future<void> updateUseArrowController(bool useArrowController) async {
    if (_useArrowController == useArrowController) {
      return;
    }

    _useArrowController = useArrowController;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_arrowControllerPrefKey, _useArrowController);
    } catch (_) {
      // Keep selected control mode for this session even if persistence fails.
    }
  }

  Future<void> signInWithGoogle() async {
    final authService = _authService;
    if (authService == null) {
      _authError = 'Authentication is unavailable in this environment.';
      notifyListeners();
      return;
    }
    if (_isAuthenticating) {
      return;
    }
    _isAuthenticating = true;
    _authError = null;
    notifyListeners();

    try {
      await authService.signInWithGoogle();
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
    final authService = _authService;
    if (authService == null) {
      _offlineGuestMode = true;
      _offlineGuestName = _generateOfflineGuestName();
      _currentUser = null;
      _authError = null;
      await startSurvival();
      notifyListeners();
      return;
    }
    if (_isAuthenticating) {
      return;
    }
    _isAuthenticating = true;
    _authError = null;
    notifyListeners();

    try {
      await authService.signInAsGuest();
      _offlineGuestMode = false;
      _offlineGuestName = null;
      _currentUser = authService.currentUser;
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
    final rand = Random.secure()
        .nextInt(0xFFFF)
        .toRadixString(36)
        .toUpperCase();
    return 'GUEST-${shortTime.substring(max(0, shortTime.length - 4))}$rand';
  }

  Future<void> signOut() async {
    final authService = _authService;
    if (authService == null) {
      _offlineGuestMode = false;
      _offlineGuestName = null;
      _currentUser = null;
      _showLanding = true;
      notifyListeners();
      return;
    }
    if (_isAuthenticating) {
      return;
    }

    _isAuthenticating = true;
    _authError = null;
    notifyListeners();

    try {
      await authService.signOut();
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

  Future<void> onStageCleared(int clearedStage) async {
    final reward = _trophiesForClearedStage(clearedStage);
    if (reward > 0) {
      _totalTrophies += reward;
    }
    if (clearedStage > _maxStageReached) {
      _maxStageReached = clearedStage;
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_totalTrophiesPrefKey, _totalTrophies);
      await prefs.setInt(_maxStageReachedPrefKey, _maxStageReached);
    } catch (_) {
      // Trophy update remains in-memory for this session if persistence fails.
    }

    await _syncGlobalPanicProgress();
  }

  Future<void> _syncGlobalPanicProgress() async {
    try {
      await game.leaderboardService.upsertGlobalPanicProgress(
        maxStage: _maxStageReached,
        totalTrophies: _totalTrophies,
      );

      final rank = await game.leaderboardService.getGlobalPanicRank();
      if (_globalPanicRank != rank) {
        _globalPanicRank = rank;
        notifyListeners();
      }
    } catch (_) {
      // Keep UI responsive if leaderboard sync fails.
    }
  }

  int _trophiesForClearedStage(int stage) {
    if (stage <= 0) {
      return 0;
    }
    return ((stage - 1) ~/ 10) + 1;
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
    gameController.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }
}
