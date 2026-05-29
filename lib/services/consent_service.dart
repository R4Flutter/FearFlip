import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_runtime_config.dart';
import 'ads_diagnostics.dart';

class ConsentService {
  ConsentService._();

  static final ConsentService instance = ConsentService._();

  static bool get _supportsMobileAds => AppRuntimeConfig.supportsMobileAds;

  static const Duration _minConsentRetryInterval = Duration(minutes: 10);
  static const Duration _minInitInterval = Duration(seconds: 10);

  final ValueNotifier<bool> canRequestAdsNotifier = ValueNotifier(false);
  final ValueNotifier<bool> consentFlowCompletedNotifier = ValueNotifier(false);
  final ValueNotifier<bool> adsInitializedNotifier = ValueNotifier(false);

  bool _consentFlowCompleted = false;
  bool _canRequestAds = false;
  bool _adsInitialized = false;
  bool _initializingAds = false;
  Completer<void>? _adsInitCompleter;
  DateTime? _lastAdsInitAttempt;
  DateTime? _lastConsentAttempt;

  bool get consentFlowCompleted => _consentFlowCompleted;
  bool get canRequestAds => _canRequestAds;
  bool get adsInitialized => _adsInitialized;

  void _setConsentFlowCompleted(bool value) {
    _consentFlowCompleted = value;
    consentFlowCompletedNotifier.value = value;
  }

  void _setCanRequestAds(bool value) {
    _canRequestAds = value;
    canRequestAdsNotifier.value = value;
  }

  void _setAdsInitialized(bool value) {
    _adsInitialized = value;
    adsInitializedNotifier.value = value;
  }

  Future<bool> showPrivacyOptions() async {
    if (!_supportsMobileAds) {
      AdsDiagnostics.log('Privacy options unavailable on web');
      return false;
    }

    try {
      final complete = Completer<bool>();
      await ConsentForm.showPrivacyOptionsForm((formError) {
        if (formError != null) {
          AdsDiagnostics.error('Privacy options failed', formError);
          if (!complete.isCompleted) {
            complete.complete(false);
          }
          return;
        }

        if (!complete.isCompleted) {
          complete.complete(true);
        }
      });

      final shown = await complete.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          AdsDiagnostics.log('Privacy options timeout');
          return false;
        },
      );
      if (shown) {
        await refreshConsentStatus();
      }
      return shown;
    } catch (error, stackTrace) {
      AdsDiagnostics.error(
        'Privacy options unavailable',
        error,
        stackTrace: stackTrace,
      );
      if (kDebugMode) {
        debugPrint(stackTrace.toString());
      }
      return false;
    }
  }

  Future<bool> tryRefreshConsent({bool initializeAds = true}) async {
    if (!_supportsMobileAds) {
      _setConsentFlowCompleted(true);
      _setCanRequestAds(false);
      return false;
    }

    final now = DateTime.now();
    if (_lastConsentAttempt != null &&
        now.difference(_lastConsentAttempt!) < _minConsentRetryInterval) {
      if (_canRequestAds && !_adsInitialized) {
        await _ensureAdsInitialized();
      }
      return _canRequestAds;
    }
    _lastConsentAttempt = now;
    return refreshConsentStatus(initializeAds: initializeAds);
  }

  Future<bool> refreshConsentStatus({bool initializeAds = true}) async {
    if (!_supportsMobileAds) {
      _setConsentFlowCompleted(true);
      _setCanRequestAds(false);
      return false;
    }

    try {
      _setCanRequestAds(await ConsentInformation.instance.canRequestAds());
      _setConsentFlowCompleted(true);
      AdsDiagnostics.log(
        'Consent refresh completed',
        data: {'canRequestAds': _canRequestAds},
      );
      AdsDiagnostics.event(
        'ad_consent',
        params: {'canRequestAds': _canRequestAds ? 1 : 0, 'source': 'refresh'},
      );

      if (_canRequestAds && initializeAds) {
        await _ensureAdsInitialized();
      }
      return _canRequestAds;
    } catch (error, stackTrace) {
      _setCanRequestAds(false);
      _setConsentFlowCompleted(true);
      AdsDiagnostics.error(
        'Consent refresh failed',
        error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> gatherConsentAndInitializeAds({bool force = false}) async {
    if (!_supportsMobileAds) {
      _setConsentFlowCompleted(true);
      _setCanRequestAds(false);
      AdsDiagnostics.log('Mobile ads unsupported on web; skipping init');
      return false;
    }

    await gatherConsent(force: force);

    if (!_canRequestAds) {
      AdsDiagnostics.log('Ads disabled: canRequestAds=false');
      return false;
    }

    try {
      await _ensureAdsInitialized();
    } catch (error, stackTrace) {
      AdsDiagnostics.error(
        'MobileAds initialization failed',
        error,
        stackTrace: stackTrace,
      );
    }
    return _canRequestAds;
  }

  Future<bool> gatherConsent({bool force = false}) async {
    if (!_supportsMobileAds) {
      _setConsentFlowCompleted(true);
      _setCanRequestAds(false);
      return false;
    }

    if (_consentFlowCompleted && !force) {
      return _canRequestAds;
    }

    if (force) {
      _setConsentFlowCompleted(false);
    }

    final complete = Completer<void>();

    try {
      final params = _buildConsentRequestParameters();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          try {
            final isFormAvailable = await ConsentInformation.instance
                .isConsentFormAvailable();
            if (isFormAvailable) {
              await ConsentForm.loadAndShowConsentFormIfRequired((formError) {
                if (formError != null) {
                  AdsDiagnostics.error(
                    'Consent form dismissed with error',
                    formError,
                  );
                }
              });
            }

            _setCanRequestAds(
              await ConsentInformation.instance.canRequestAds(),
            );
            AdsDiagnostics.log(
              'Consent flow completed',
              data: {'canRequestAds': _canRequestAds},
            );
            AdsDiagnostics.event(
              'ad_consent',
              params: {
                'canRequestAds': _canRequestAds ? 1 : 0,
                'source': 'flow',
              },
            );
          } catch (error, stackTrace) {
            _setCanRequestAds(false);
            AdsDiagnostics.error(
              'Consent flow failed',
              error,
              stackTrace: stackTrace,
            );
          } finally {
            _setConsentFlowCompleted(true);
            if (!complete.isCompleted) {
              complete.complete();
            }
          }
        },
        (formError) {
          unawaited(_handleConsentInfoUpdateFailure(formError, complete));
        },
      );

      await complete.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          _setCanRequestAds(false);
          _setConsentFlowCompleted(true);
          AdsDiagnostics.log('Consent flow timeout; ads disabled');
        },
      );
    } catch (error, stackTrace) {
      _setCanRequestAds(false);
      _setConsentFlowCompleted(true);
      AdsDiagnostics.error(
        'Unexpected consent failure',
        error,
        stackTrace: stackTrace,
      );
    }
    return _canRequestAds;
  }

  Future<void> _ensureAdsInitialized() async {
    if (!_supportsMobileAds) {
      return;
    }

    if (_adsInitialized) {
      return;
    }

    final pendingInit = _adsInitCompleter;
    if (_initializingAds && pendingInit != null) {
      await pendingInit.future;
      return;
    }

    final now = DateTime.now();
    if (_lastAdsInitAttempt != null &&
        now.difference(_lastAdsInitAttempt!) < _minInitInterval) {
      return;
    }

    _initializingAds = true;
    final initCompleter = Completer<void>();
    _adsInitCompleter = initCompleter;
    _lastAdsInitAttempt = now;
    try {
      final status = await MobileAds.instance.initialize();
      _setAdsInitialized(true);
      AdsDiagnostics.log('MobileAds initialized');
      _logAdapterStatus(status);
    } catch (error, stackTrace) {
      AdsDiagnostics.error(
        'MobileAds initialization failed',
        error,
        stackTrace: stackTrace,
      );
      _setAdsInitialized(false);
    } finally {
      _initializingAds = false;
      _adsInitCompleter = null;
      if (!initCompleter.isCompleted) {
        initCompleter.complete();
      }
    }
  }

  ConsentRequestParameters _buildConsentRequestParameters() {
    return ConsentRequestParameters(
      tagForUnderAgeOfConsent:
          AppRuntimeConfig.adsConsentTagForUnderAgeOfConsent,
      consentDebugSettings: _buildConsentDebugSettings(),
    );
  }

  ConsentDebugSettings? _buildConsentDebugSettings() {
    if (kReleaseMode) {
      return null;
    }

    final testDeviceIds = AppRuntimeConfig.adTestDeviceIds;
    final debugGeography = _debugGeographyFromConfig(
      AppRuntimeConfig.adsConsentDebugGeography,
    );
    if (testDeviceIds.isEmpty && debugGeography == null) {
      return null;
    }

    return ConsentDebugSettings(
      testIdentifiers: testDeviceIds.isEmpty ? null : testDeviceIds,
      debugGeography: debugGeography,
    );
  }

  DebugGeography? _debugGeographyFromConfig(String value) {
    switch (value) {
      case '':
      case 'disabled':
      case 'none':
        return null;
      case 'eea':
        return DebugGeography.debugGeographyEea;
      case 'regulated_us_state':
      case 'us':
        return DebugGeography.debugGeographyRegulatedUsState;
      case 'other':
        return DebugGeography.debugGeographyOther;
    }
    return null;
  }

  Future<void> _handleConsentInfoUpdateFailure(
    FormError formError,
    Completer<void> complete,
  ) async {
    final canRequestFromPreviousSession = await _readCanRequestAdsSafely();
    _setCanRequestAds(canRequestFromPreviousSession);
    _setConsentFlowCompleted(true);
    AdsDiagnostics.error('requestConsentInfoUpdate failed', formError);
    if (_canRequestAds) {
      await _ensureAdsInitialized();
    }
    if (!complete.isCompleted) {
      complete.complete();
    }
  }

  Future<bool> _readCanRequestAdsSafely() async {
    try {
      return ConsentInformation.instance.canRequestAds();
    } catch (_) {
      return false;
    }
  }

  void _logAdapterStatus(InitializationStatus status) {
    final adapters = status.adapterStatuses;
    if (adapters.isEmpty) {
      return;
    }
    for (final entry in adapters.entries) {
      final name = entry.key;
      final adapterStatus = entry.value;
      AdsDiagnostics.log(
        'Adapter status',
        data: {
          'adapter': name,
          'state': adapterStatus.state.name,
          'latencyMs': adapterStatus.latency,
          'desc': adapterStatus.description,
        },
      );
    }
  }
}
