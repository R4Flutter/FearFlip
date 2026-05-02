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
import '../../services/audio_manager.dart';
import '../../services/account_deletion_service.dart';
import '../../services/auth_service.dart';
import '../../services/game_audio_event.dart';
import '../../services/leaderboard_service.dart';

class AppFlowProvider extends ChangeNotifier {
  static const String _joystickSizePrefKey = 'ui.joystick.size';
  static const String _selectedCharacterPrefKey = 'ui.character.index';
  static const String _arrowControllerPrefKey = 'ui.controller.arrow';
  static const String _soundVolumePrefKey = 'audio.master.volume';
  static const String _soundMutedPrefKey = 'audio.master.muted';
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
    AccountDeletionService? accountDeletionService,
  }) : _sessionDatabase = sessionDatabase,
       _startSurvivalUseCase = startSurvivalUseCase,
       _authService =
           authService ?? (enableAuthBootstrap ? AuthService() : null),
       _accountDeletionService =
           accountDeletionService ??
           (enableAuthBootstrap ? AccountDeletionService() : null) {
    _sessionDatabase.markAppLaunch();
    game = FearFlipGame(
      adsService: AdsService.instance,
      audioManager: AudioManager.instance,
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
  final AccountDeletionService? _accountDeletionService;
  StreamSubscription<User?>? _authSubscription;

  late final FearFlipGame game;
  late final GameController gameController;

  User? _currentUser;
  bool _offlineGuestMode = false;
  String? _offlineGuestName;
  bool _isAuthenticating = false;
  bool _isDeletingAccount = false;
  String? _authError;
  String? _accountMessage;
  bool _showLanding = true;
  bool _isStarting = false;
  double _joystickSize = 110;
  double _soundVolume = 1.0;
  bool _isSoundMuted = false;
  int _selectedCharacterIndex = defaultCharacterIndex;
  bool _useArrowController = false;
  int _totalTrophies = 0;
  int _maxStageReached = 1;
  int? _globalPanicRank;

  bool get showAuthGate => _currentUser == null && !_offlineGuestMode;
  bool get isAuthenticating => _isAuthenticating;
  bool get isDeletingAccount => _isDeletingAccount;
  String? get authError => _authError;
  String? get accountMessage => _accountMessage;
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
  double get soundVolume => _soundVolume;
  bool get isSoundMuted => _isSoundMuted;
  int get selectedCharacterIndex => _selectedCharacterIndex;
  bool get useArrowController => _useArrowController;
  int get totalTrophies => _totalTrophies;
  int get maxStageReached => _maxStageReached;
  int? get globalPanicRank => _globalPanicRank;

  Future<void> _loadUiSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJoystick = prefs.getDouble(_joystickSizePrefKey);
      final savedSoundVolume = prefs.getDouble(_soundVolumePrefKey);
      final savedSoundMuted = prefs.getBool(_soundMutedPrefKey);
      final savedCharacter = prefs.getInt(_selectedCharacterPrefKey);
      final savedArrowController = prefs.getBool(_arrowControllerPrefKey);
      final savedTrophies = prefs.getInt(_totalTrophiesPrefKey);
      final savedMaxStage = prefs.getInt(_maxStageReachedPrefKey);

      var hasChanges = false;
      if (savedJoystick != null) {
        _joystickSize = savedJoystick.clamp(minJoystickSize, maxJoystickSize);
        hasChanges = true;
      }
      if (savedSoundVolume != null) {
        _soundVolume = savedSoundVolume.clamp(0.0, 1.0);
        hasChanges = true;
      }
      if (savedSoundMuted != null) {
        _isSoundMuted = savedSoundMuted;
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

    await AudioManager.configureGlobalAudio(
      volume: _soundVolume,
      muted: _isSoundMuted,
    );
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

  Future<void> updateSoundVolume(double volume) async {
    final normalized = volume.clamp(0.0, 1.0);
    if ((_soundVolume - normalized).abs() < 0.001) {
      return;
    }

    _soundVolume = normalized;
    notifyListeners();

    await AudioManager.configureGlobalAudio(volume: _soundVolume);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_soundVolumePrefKey, _soundVolume);
    } catch (_) {
      // Keep selected audio volume for this session even if persistence fails.
    }
  }

  Future<void> updateSoundMuted(bool muted) async {
    if (_isSoundMuted == muted) {
      return;
    }

    _isSoundMuted = muted;
    notifyListeners();

    await AudioManager.configureGlobalAudio(muted: _isSoundMuted);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_soundMutedPrefKey, _isSoundMuted);
    } catch (_) {
      // Keep selected mute state for this session even if persistence fails.
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
      final credential = await authService.signInWithGoogle().timeout(
        const Duration(seconds: 25),
      );
      var signedInUser = credential.user ?? authService.currentUser;
      if (signedInUser == null) {
        // Give Firebase auth-state propagation a brief chance to settle.
        await Future<void>.delayed(const Duration(milliseconds: 220));
        signedInUser = authService.currentUser;
      }
      if (signedInUser == null) {
        _authError =
            'Google sign-in completed but no user session was created.';
        return;
      }

      _offlineGuestMode = false;
      _offlineGuestName = null;
      _currentUser = signedInUser;
      _showLanding = true;
      _authError = null;
      unawaited(_syncGlobalPanicProgress());
    } on AuthCancelledException {
      _authError = null;
    } on AuthConfigurationException catch (error) {
      _authError = error.message;
    } on AuthSignInFailedException catch (error) {
      _authError = error.message;
    } on TimeoutException {
      _authError =
          'Google sign-in timed out. Please check your internet and try again.';
    } on FirebaseAuthException catch (error) {
      debugPrint(
        'Google sign-in FirebaseAuthException: code=${error.code}, message=${error.message}',
      );
      _authError = error.message ?? 'Google sign-in failed. Please try again.';
    } catch (error, stackTrace) {
      final details = error.toString().toLowerCase();
      debugPrint(
        'Google sign-in unexpected error (${error.runtimeType}): $error',
      );
      debugPrint('$stackTrace');

      if (details.contains('developer_error') ||
          details.contains('configuration') ||
          details.contains('invalid-credential') ||
          details.contains('sha-1') ||
          details.contains('sha-256')) {
        _authError =
            'Google Sign-In configuration error. Verify package name, SHA-1/SHA-256, OAuth clients, and google-services.json.';
      } else if (details.contains('network') || details.contains('timeout')) {
        _authError =
            'Google Sign-In needs an internet connection. Check your network and try again.';
      } else {
        _authError =
            'Unable to sign in with Google right now. Please try again.';
      }
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
      final credential = await authService.signInAsGuest().timeout(
        const Duration(seconds: 25),
      );
      final guestUser = credential.user ?? authService.currentUser;
      if (guestUser == null) {
        _offlineGuestMode = true;
        _offlineGuestName = _generateOfflineGuestName();
        _currentUser = null;
      } else {
        _offlineGuestMode = false;
        _offlineGuestName = null;
        _currentUser = guestUser;
      }
      _showLanding = true;
      _authError = null;
    } on TimeoutException {
      _offlineGuestMode = true;
      _offlineGuestName = _generateOfflineGuestName();
      _currentUser = null;
      _showLanding = true;
      _authError = 'Guest sign-in timed out. Continuing in offline guest mode.';
    } on FirebaseAuthException {
      // Launch-safe fallback: keep game playable even when Firebase guest auth
      // is unavailable (network, quota, or anonymous auth disabled).
      _offlineGuestMode = true;
      _offlineGuestName = _generateOfflineGuestName();
      _currentUser = null;
      _showLanding = true;
      _authError = null;
    } catch (_) {
      _offlineGuestMode = true;
      _offlineGuestName = _generateOfflineGuestName();
      _currentUser = null;
      _showLanding = true;
      _authError = null;
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

  Future<AccountDeletionResult> requestAccountDeletion() async {
    if (_isDeletingAccount || _isAuthenticating) {
      return const AccountDeletionResult(
        status: AccountDeletionStatus.failed,
        message: 'Another account action is already in progress.',
      );
    }

    final service = _accountDeletionService;
    if (service == null || _offlineGuestMode) {
      _offlineGuestMode = false;
      _offlineGuestName = null;
      _currentUser = null;
      _showLanding = true;
      _globalPanicRank = null;
      _accountMessage = 'Local guest profile cleared on this device.';
      notifyListeners();
      return AccountDeletionResult(
        status: AccountDeletionStatus.noSignedInUser,
        message: _accountMessage!,
      );
    }

    _isDeletingAccount = true;
    _authError = null;
    _accountMessage = null;
    notifyListeners();

    try {
      final result = await service.requestDeletion().timeout(
        const Duration(seconds: 25),
      );
      _accountMessage = result.message;
      if (result.shouldReturnToAuthGate) {
        _offlineGuestMode = false;
        _offlineGuestName = null;
        _currentUser = null;
        _showLanding = true;
        _globalPanicRank = null;
      }
      return result;
    } on TimeoutException {
      const result = AccountDeletionResult(
        status: AccountDeletionStatus.failed,
        message:
            'Account deletion timed out. Check your internet connection and try again.',
      );
      _accountMessage = result.message;
      return result;
    } catch (_) {
      const result = AccountDeletionResult(
        status: AccountDeletionStatus.failed,
        message:
            'Account deletion failed. Please try again or use the account deletion web form.',
      );
      _accountMessage = result.message;
      return result;
    } finally {
      _isDeletingAccount = false;
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

    // Show a stage-cleared interstitial on every Nth stage (default: 3).
    // Fire-and-forget so the ad overlay never blocks the GameScreen state
    // machine that is already waiting for this Future to resolve.
    unawaited(game.adsService.showInterstitialAfterStageCleared(clearedStage));
  }

  Future<void> _syncGlobalPanicProgress() async {
    try {
      await game.leaderboardService.upsertGlobalPanicProgress(
        maxStage: _maxStageReached,
        totalTrophies: _totalTrophies,
        // Pass the in-game display name so guests appear with their chosen
        // name (e.g. "SpeedRunner7") rather than the generic "Guest" fallback.
        playerName: playerName,
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
    unawaited(AudioManager.instance.handle(GameAudioEvent.matchExit));
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
