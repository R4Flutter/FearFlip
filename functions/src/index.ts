/**
 * FearFlip — Server-side subscription verification via Firebase Cloud Functions.
 *
 * Exposes two HTTPS callable functions:
 *
 *   1. `verifySubscription`  — called after a new purchase or restore to validate
 *      the purchase token against the Google Play Developer API and return the
 *      canonical subscription status.
 *
 *   2. `checkSubscriptionStatus` — called on every app launch to re-verify
 *      whether a cached subscription is still active (handles expiry, refunds,
 *      cancellations).
 *
 * Both functions require the caller to be authenticated via Firebase Auth.
 *
 * ── Security Model ────────────────────────────────────────────────────────────
 *
 *   • Only authenticated users can call these functions (uid checked).
 *   • The purchase token is validated server-side against the Play Developer API.
 *   • Subscription state is persisted in Firestore under
 *     `subscriptions/{uid}` — the Flutter client never writes this document.
 *   • Replay attacks are mitigated: re-submitting the same token within
 *     5 minutes returns the cached result; after 5 minutes Play is re-queried.
 *
 * ── Prerequisites ─────────────────────────────────────────────────────────────
 *
 *   1. A Google Cloud service account with the `androidpublisher` scope.
 *      Place the JSON key at `functions/service-account.json` (gitignored) OR
 *      set GOOGLE_APPLICATION_CREDENTIALS when deploying.
 *
 *   2. Grant the service account "View financial data" permissions in
 *      Google Play Console → Setup → API access.
 *
 *   3. Set the package name via environment variable:
 *        firebase functions:secrets:set FEARFLIP_PACKAGE_NAME
 *      OR pass it as a runtime env var in firebase.json / GCP console.
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {google} from "googleapis";

// ─── Initialisation ──────────────────────────────────────────────────────────

admin.initializeApp();
const db = admin.firestore();

// Android package name resolved from environment (preferred) then hardcoded
// fallback so local emulator runs still work.
const PACKAGE_NAME =
  process.env.FEARFLIP_PACKAGE_NAME ?? "dev.fearflip.game";

const SUBSCRIPTION_ID = "remove_ads_monthly";

// ─── Google Play Developer API client ────────────────────────────────────────

/**
 * Returns an authorised `androidpublisher` client.
 *
 * Auth is resolved in order:
 *   1. `functions/service-account.json` (local dev / CI)
 *   2. Application Default Credentials (Cloud Functions runtime on GCP)
 */
async function getPlayClient() {
  let auth: InstanceType<typeof google.auth.GoogleAuth>;

  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const key = require("../service-account.json");
    auth = new google.auth.GoogleAuth({
      credentials: key,
      scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });
  } catch {
    auth = new google.auth.GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });
  }

  return google.androidpublisher({version: "v3", auth});
}

// ─── Firestore helpers ───────────────────────────────────────────────────────

interface SubscriptionRecord {
  isActive: boolean;
  productId: string;
  purchaseToken: string;
  expiryTimeMillis: number;
  autoRenewing: boolean;
  /** ISO timestamp of the last successful server verification. */
  lastVerifiedAt: string;
  /** Payment state from Play (0=pending, 1=received, 2=free trial, 3=deferred). */
  paymentState: number;
  /** Cancellation reason if cancelled (0=user, 1=system, 2=replaced, 3=developer). */
  cancelReason: number | null;
}

async function writeSubscriptionRecord(
  uid: string,
  record: SubscriptionRecord
): Promise<void> {
  await db
    .collection("subscriptions")
    .doc(uid)
    .set(record, {merge: true});
}

async function getSubscriptionRecord(
  uid: string
): Promise<SubscriptionRecord | null> {
  const doc = await db.collection("subscriptions").doc(uid).get();
  if (!doc.exists) return null;
  return doc.data() as SubscriptionRecord;
}

// ─── Core verification logic ─────────────────────────────────────────────────

interface VerificationResult {
  isActive: boolean;
  expiryTimeMillis: number;
  autoRenewing: boolean;
  paymentState: number;
  cancelReason: number | null;
  startTimeMillis: number;
}

async function verifyTokenWithPlay(
  purchaseToken: string
): Promise<VerificationResult> {
  const play = await getPlayClient();

  const response = await play.purchases.subscriptions.get({
    packageName: PACKAGE_NAME,
    subscriptionId: SUBSCRIPTION_ID,
    token: purchaseToken,
  });

  const data = response.data;
  const expiryMillis = parseInt(data.expiryTimeMillis || "0", 10);
  const startMillis = parseInt(data.startTimeMillis || "0", 10);
  const paymentState = data.paymentState ?? 0;
  const autoRenewing = data.autoRenewing ?? false;
  const cancelReason = data.cancelReason ?? null;

  // A subscription is active if:
  //   1. It has not expired yet, AND
  //   2. Payment was received (paymentState 1) or it's a free trial (2).
  const now = Date.now();
  const isActive =
    expiryMillis > now && (paymentState === 1 || paymentState === 2);

  return {
    isActive,
    expiryTimeMillis: expiryMillis,
    autoRenewing,
    paymentState,
    cancelReason,
    startTimeMillis: startMillis,
  };
}

// ─── Cloud Function: verifySubscription ──────────────────────────────────────

/**
 * Called from the Flutter app after a new purchase or restore.
 *
 * Request payload:
 *   { purchaseToken: string, productId: string }
 *
 * Response payload:
 *   { isActive: boolean, expiryTimeMillis: number, autoRenewing: boolean }
 */
export const verifySubscription = functions.https.onCall(
  async (data, context) => {
    // ── Auth gate ──────────────────────────────────────────────────────────
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "You must be signed in to verify a subscription."
      );
    }
    const uid = context.auth.uid;

    // ── Input validation ──────────────────────────────────────────────────
    const purchaseToken = data?.purchaseToken as string | undefined;
    const productId = data?.productId as string | undefined;

    if (!purchaseToken || typeof purchaseToken !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "purchaseToken is required."
      );
    }

    if (productId && productId !== SUBSCRIPTION_ID) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `Unexpected productId: ${productId}`
      );
    }

    // ── Replay-attack mitigation ──────────────────────────────────────────
    // If we verified this exact token within the last 5 minutes AND it's
    // still before expiry, return the cached result to avoid hitting Play.
    const existing = await getSubscriptionRecord(uid);
    const now = Date.now();
    const fiveMinutes = 5 * 60 * 1000;

    if (existing && existing.purchaseToken === purchaseToken) {
      const lastVerified = new Date(existing.lastVerifiedAt).getTime();
      const recentlyVerified = now - lastVerified < fiveMinutes;
      const notExpired = existing.expiryTimeMillis > now;

      if (recentlyVerified && notExpired) {
        functions.logger.info(
          `[verifySubscription] Returning cached result for uid=${uid}`
        );
        return {
          isActive: existing.isActive,
          expiryTimeMillis: existing.expiryTimeMillis,
          autoRenewing: existing.autoRenewing,
          cached: true,
        };
      }
    }

    // ── Verify with Google Play ───────────────────────────────────────────
    try {
      const result = await verifyTokenWithPlay(purchaseToken);

      const record: SubscriptionRecord = {
        isActive: result.isActive,
        productId: SUBSCRIPTION_ID,
        purchaseToken,
        expiryTimeMillis: result.expiryTimeMillis,
        autoRenewing: result.autoRenewing,
        lastVerifiedAt: new Date().toISOString(),
        paymentState: result.paymentState,
        cancelReason: result.cancelReason,
      };

      await writeSubscriptionRecord(uid, record);

      functions.logger.info(
        `[verifySubscription] uid=${uid} active=${result.isActive} ` +
        `expiry=${result.expiryTimeMillis} autoRenew=${result.autoRenewing}`
      );

      return {
        isActive: result.isActive,
        expiryTimeMillis: result.expiryTimeMillis,
        autoRenewing: result.autoRenewing,
        cached: false,
      };
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      functions.logger.error(
        `[verifySubscription] Play API error for uid=${uid}: ${message}`
      );
      throw new functions.https.HttpsError(
        "internal",
        "Failed to verify subscription with Google Play. Please try again."
      );
    }
  }
);

// ─── Cloud Function: checkSubscriptionStatus ─────────────────────────────────

/**
 * Called on every app launch to re-check whether a cached subscription is
 * still valid. Does NOT require a purchase token — it uses the token stored
 * in Firestore from the last successful verification.
 *
 * Request payload: (none)
 *
 * Response payload:
 *   { isActive: boolean, expiryTimeMillis: number, autoRenewing: boolean, cached?: boolean }
 */
export const checkSubscriptionStatus = functions.https.onCall(
  async (_data, context) => {
    // ── Auth gate ──────────────────────────────────────────────────────────
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "You must be signed in to check subscription status."
      );
    }
    const uid = context.auth.uid;

    // ── Check Firestore for existing record ───────────────────────────────
    const existing = await getSubscriptionRecord(uid);
    if (!existing || !existing.purchaseToken) {
      // No subscription record found — user never subscribed on this account.
      return {
        isActive: false,
        expiryTimeMillis: 0,
        autoRenewing: false,
        cached: false,
      };
    }

    const now = Date.now();

    // ── Quick expiry check — if already expired, no need to hit Play ──────
    if (existing.expiryTimeMillis <= now) {
      // Mark as inactive in Firestore so future checks skip Play too.
      if (existing.isActive) {
        await writeSubscriptionRecord(uid, {
          ...existing,
          isActive: false,
          lastVerifiedAt: new Date().toISOString(),
        });
      }
      return {
        isActive: false,
        expiryTimeMillis: existing.expiryTimeMillis,
        autoRenewing: existing.autoRenewing,
        cached: false,
      };
    }

    // ── Skip Play if verified within the last 5 minutes ───────────────────
    const lastVerified = new Date(existing.lastVerifiedAt).getTime();
    const fiveMinutes = 5 * 60 * 1000;

    if (now - lastVerified < fiveMinutes) {
      functions.logger.info(
        `[checkSubscriptionStatus] Recent verification cache hit for uid=${uid}`
      );
      return {
        isActive: existing.isActive,
        expiryTimeMillis: existing.expiryTimeMillis,
        autoRenewing: existing.autoRenewing,
        cached: true,
      };
    }

    // ── Re-verify with Google Play ────────────────────────────────────────
    try {
      const result = await verifyTokenWithPlay(existing.purchaseToken);

      const record: SubscriptionRecord = {
        isActive: result.isActive,
        productId: SUBSCRIPTION_ID,
        purchaseToken: existing.purchaseToken,
        expiryTimeMillis: result.expiryTimeMillis,
        autoRenewing: result.autoRenewing,
        lastVerifiedAt: new Date().toISOString(),
        paymentState: result.paymentState,
        cancelReason: result.cancelReason,
      };

      await writeSubscriptionRecord(uid, record);

      functions.logger.info(
        `[checkSubscriptionStatus] uid=${uid} active=${result.isActive} ` +
        `expiry=${result.expiryTimeMillis}`
      );

      return {
        isActive: result.isActive,
        expiryTimeMillis: result.expiryTimeMillis,
        autoRenewing: result.autoRenewing,
        cached: false,
      };
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      functions.logger.error(
        `[checkSubscriptionStatus] Play API error for uid=${uid}: ${message}`
      );

      // ── Graceful fallback ──────────────────────────────────────────────
      // If Play API is temporarily down, return cached status with indicator.
      // The Flutter client uses a grace period to decide whether to trust it.
      const cachedActive =
        existing.isActive && existing.expiryTimeMillis > now;
      return {
        isActive: cachedActive,
        expiryTimeMillis: existing.expiryTimeMillis,
        autoRenewing: existing.autoRenewing,
        cached: true,
      };
    }
  }
);
