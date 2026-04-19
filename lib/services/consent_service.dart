import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class ConsentService {
  ConsentService._();

  static final ConsentService instance = ConsentService._();

  bool _consentFlowCompleted = false;
  bool _canRequestAds = false;

  bool get consentFlowCompleted => _consentFlowCompleted;
  bool get canRequestAds => _canRequestAds;

  Future<void> gatherConsentAndInitializeAds() async {
    await gatherConsent();

    if (!_canRequestAds) {
      debugPrint('[Consent] Ads disabled: canRequestAds=false');
      return;
    }

    try {
      await MobileAds.instance.initialize();
      debugPrint('[Consent] MobileAds initialized');
    } catch (error, stackTrace) {
      debugPrint('[Consent][ERROR] MobileAds initialization failed: $error');
      if (kDebugMode) {
        debugPrint(stackTrace.toString());
      }
    }
  }

  Future<void> gatherConsent() async {
    if (_consentFlowCompleted) {
      return;
    }

    final complete = Completer<void>();

    try {
      final params = ConsentRequestParameters();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          try {
            final isFormAvailable = await ConsentInformation.instance
                .isConsentFormAvailable();
            if (isFormAvailable) {
              await ConsentForm.loadAndShowConsentFormIfRequired((formError) {
                if (formError != null) {
                  debugPrint(
                    '[Consent][ERROR] Consent form dismissed with error: ${formError.message}',
                  );
                }
              });
            }

            _canRequestAds = await ConsentInformation.instance.canRequestAds();
            debugPrint('[Consent] canRequestAds=$_canRequestAds');
          } catch (error, stackTrace) {
            _canRequestAds = false;
            debugPrint('[Consent][ERROR] Consent flow failed: $error');
            if (kDebugMode) {
              debugPrint(stackTrace.toString());
            }
          } finally {
            _consentFlowCompleted = true;
            if (!complete.isCompleted) {
              complete.complete();
            }
          }
        },
        (formError) {
          _canRequestAds = false;
          _consentFlowCompleted = true;
          debugPrint(
            '[Consent][ERROR] requestConsentInfoUpdate failed: ${formError.message}',
          );
          if (!complete.isCompleted) {
            complete.complete();
          }
        },
      );

      await complete.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          _canRequestAds = false;
          _consentFlowCompleted = true;
          debugPrint('[Consent][WARN] Consent flow timeout; ads disabled');
        },
      );
    } catch (error, stackTrace) {
      _canRequestAds = false;
      _consentFlowCompleted = true;
      debugPrint('[Consent][ERROR] Unexpected consent failure: $error');
      if (kDebugMode) {
        debugPrint(stackTrace.toString());
      }
    }
  }
}
