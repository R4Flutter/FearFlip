# Ads & IAP operator runbook

Scope: the "Remove Ads" one-time non-consumable purchase, its server-side
receipt validation, and the premium gate that suppresses ads. Ad *placement*
(interstitial cadence, rewarded revive) is unchanged — the stage-cleared
interstitial interval stays at **3** (stages 3, 6, 9, …).

## How premium unlock works (end to end)

1. User buys `remove_ads_prod_android` (or the iOS SKU). The `in_app_purchase`
   stream delivers a `purchased` / `restored` `PurchaseDetails`.
2. `PurchaseService._verifyAndComplete` extracts the purchase token and calls
   the `verifyOneTimePurchase` Cloud Function.
3. The function validates the token against the **Google Play Developer API**
   and writes an `entitlements/{uid}` record in Firestore.
4. Client outcome:
   - server `isValid: true`  → grant premium.
   - server `isValid: false` → do NOT grant (blocks tampering).
   - server **unreachable** (`null`) → **Mode B**: trust the store and grant,
     for both `purchased` and `restored`. A refund is reconciled on next launch.
5. `PurchaseService.isSubscribed` → `MonetizationService.isPremiumUnlocked` →
   `AdsFacade` short-circuits every ad request. Premium user = no ads.

On each launch, if the premium flag is cached, `_serverCheckOnLaunch` calls
`checkOneTimePurchaseStatus` to catch refunds.

## The one blocker: Play Developer API credential (required for real validation)

Server verification only works if the Cloud Function can authenticate to the
Google Play Developer API. **Without it, every validation fails**, no
entitlement record is written, and premium relies entirely on the client
Mode-B fallback (users still get what they paid for, but refunds are not
enforced and tampering is not blocked).

Set it up once:

1. In **Google Cloud Console**, create a service account and a JSON key.
2. In **Play Console → Users and permissions**, invite that service account and
   grant "View financial data" + "Manage orders and subscriptions".
3. Provide the key to the function as a secret (preferred — never commit it):
   ```bash
   cd functions
   firebase functions:secrets:set PLAY_SERVICE_ACCOUNT_JSON   # paste JSON
   ```
   Bind the secret in the function deploy if not auto-bound, then:
   ```bash
   npm run build && firebase deploy --only functions
   ```
   Fallback (local/dev only): drop the key at `functions/service-account.json`
   (git-ignore it). The function reads the secret first, then the file, then
   ADC (which logs a loud warning and will fail validation).

Verify: buy in a Play **sandbox** account, then check Cloud Functions logs — a
missing credential prints `[getPlayClient] No PLAY_SERVICE_ACCOUNT_JSON …`.

## Reason codes (why the client trusts or revokes)

`checkOneTimePurchaseStatus` / `verifyOneTimePurchase` return `{isValid, reason}`:

| reason        | meaning                                   | client action        |
|---------------|-------------------------------------------|----------------------|
| `active`      | Play says purchaseState 0 (owned)         | keep / grant premium |
| `play_revoked`| Play says cancelled/refunded              | **revoke premium**   |
| `pending`     | Play says pending                         | keep, do not revoke  |
| `no_record`   | no server entitlement doc (never verified)| keep cached premium  |
| `unreachable` | Play API errored                          | keep cached premium  |

The client revokes a paid entitlement **only** on `play_revoked`. This is the
fix for the bug where every payer lost premium on the launch after purchase.

## Common issues

- **"I paid but ads came back next launch."** The launch re-check used to revoke
  on any non-`true` response. Fixed — it now revokes only on `play_revoked`.
  If it still happens, check the function returns a `reason` field (redeploy).
- **"Restore does nothing after reinstall."** Restore now unlocks via Mode B
  when the server is unreachable. If it still fails, the store returned neither
  `purchased` nor `restored` — the account does not own the SKU.
- **Refund not taking effect.** Requires the Play credential above; without it
  the server can never see `play_revoked`.

## Not implemented (deferred from the hardening plan)

These need external accounts/keys and are out of scope until credentials exist:
AppLovin MAX + StartApp mediation, iOS App Store Server API validation,
subscription (recurring) Remove-Ads tier. Current stack: Unity Ads (primary) +
AdMob (fallback) via `AdsFacade`, one-time Remove-Ads IAP.
