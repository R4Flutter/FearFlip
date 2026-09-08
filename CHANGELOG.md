# Changelog

## [Unreleased]

### Fixed
- **Premium was revoked on the launch after purchase.** `_serverCheckOnLaunch`
  revoked a cached entitlement on any non-`true` server response. When Play
  receipt validation could not run (no service-account credential), the server
  wrote no entitlement record, `checkOneTimePurchaseStatus` returned
  `isValid:false`, and every payer lost Remove-Ads on next app open. The client
  now revokes only on an authoritative `reason: "play_revoked"` (genuine
  refund/cancel); `no_record` and `unreachable` keep the cached premium.
- **Restore did nothing after reinstall while the server was unreachable.** The
  Mode-B client fallback only rescued `purchased`, never `restored`. Restore now
  gets the same store-trusted unlock as purchase.
- **Idempotency short-circuit could leave a payer locked out.** A re-delivered,
  already-processed owned purchase now re-applies the entitlement instead of
  no-op'ing when the local flag was false.

### Changed
- Cloud Functions `verifyOneTimePurchase` and `checkOneTimePurchaseStatus` now
  return a `reason` code (`active` / `play_revoked` / `pending` / `no_record` /
  `unreachable`) so the client can distinguish a real refund from a server that
  simply could not reach Play.
- `getPlayClient` reads the Play credential from the `PLAY_SERVICE_ACCOUNT_JSON`
  secret first (so it need never be committed), then `service-account.json`,
  then ADC — and logs a loud warning when falling back to ADC.

### Added
- `docs/ads-and-iap.md` — operator runbook: premium unlock flow, the required
  Play Developer API credential setup, reason-code table, and troubleshooting.
- Regression tests in `test/services/purchase_service_test.dart` covering the
  launch re-check revoke rules and Mode-B restore parity.

### Not done (needs external credentials/accounts)
- AppLovin MAX + StartApp mediation, iOS App Store Server API validation, and a
  recurring Remove-Ads subscription tier remain deferred.
