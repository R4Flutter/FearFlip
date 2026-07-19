/**
 * FearFlip — server-side game backend (Firebase Cloud Functions, gen 2).
 *
 * Callables:
 *   - submitScore                 leaderboard survival-time submit (rate limited)
 *   - upsertGlobalPanicProgress   server-authoritative stage/trophy write
 *   - verifyOneTimePurchase       validate a Remove-Ads purchase vs Play
 *   - checkOneTimePurchaseStatus  re-verify cached entitlement on launch
 *
 * Triggers:
 *   - onAccountDeletionRequested  wipes all data for a uid on deletion request
 *
 * All callables require Firebase Auth. App Check enforcement is left OFF; flip
 * `enforceAppCheck: true` in each onCall's options once App Check is registered
 * in the Firebase console (Play Integrity provider) and wired in the app.
 */

import {setGlobalOptions} from "firebase-functions/v2";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import {google} from "googleapis";

// ─── Initialisation ──────────────────────────────────────────────────────────

admin.initializeApp();
const db = admin.firestore();

// Cost guards. No region set → default us-central1, which matches the Flutter
// client's default FirebaseFunctions.instance region. Do not change region
// without also pinning it on the client, or callables will 404.
setGlobalOptions({maxInstances: 10, timeoutSeconds: 30, memory: "256MiB"});

const PACKAGE_NAME = process.env.FEARFLIP_PACKAGE_NAME ?? "com.rajnaik.fearflip";

/** Minimum gap between leaderboard score submits per uid (anti-spam). */
const SCORE_MIN_INTERVAL_MS = 3000;

// ─── Helpers ─────────────────────────────────────────────────────────────────

function clampInt(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) {
    return min;
  }
  const rounded = Math.round(value);
  return Math.min(Math.max(rounded, min), max);
}

function sanitizeMode(mode: string): string {
  const normalized = mode.trim().toLowerCase();
  if (!normalized) {
    return "normal";
  }
  const safe = normalized.replace(/[^a-z0-9_-]/g, "_");
  return safe.length > 0 ? safe : "normal";
}

function sanitizeDisplayName(displayName: unknown, uid: string): string {
  if (typeof displayName === "string") {
    const trimmed = displayName.trim();
    if (trimmed.length > 0) {
      return trimmed.substring(0, 32);
    }
  }
  const suffix = uid.length > 6 ? uid.substring(uid.length - 6) : uid;
  return suffix ? `Player-${suffix}` : "Player";
}

// ─── Google Play Developer API client ────────────────────────────────────────

const PLAY_SCOPES = ["https://www.googleapis.com/auth/androidpublisher"];

async function getPlayClient() {
  let auth: InstanceType<typeof google.auth.GoogleAuth>;

  // Preferred: inline JSON from a Firebase secret / env var, so the service
  // account is never committed to the repo.
  //   firebase functions:secrets:set PLAY_SERVICE_ACCOUNT_JSON
  const inlineJson = process.env.PLAY_SERVICE_ACCOUNT_JSON;
  if (inlineJson && inlineJson.trim().length > 0) {
    auth = new google.auth.GoogleAuth({
      credentials: JSON.parse(inlineJson),
      scopes: PLAY_SCOPES,
    });
    return google.androidpublisher({version: "v3", auth: auth as any});
  }

  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const key = require("../service-account.json");
    auth = new google.auth.GoogleAuth({credentials: key, scopes: PLAY_SCOPES});
  } catch {
    // No credential found. ADC uses the runtime service account, which does
    // NOT have Play Developer API access unless it was linked in the Play
    // Console. Loud warning: without this, every receipt validation fails and
    // no entitlement record is written. See docs/ads-and-iap.md.
    logger.warn(
      "[getPlayClient] No PLAY_SERVICE_ACCOUNT_JSON secret and no " +
        "../service-account.json — falling back to ADC. Play Developer API " +
        "calls will fail unless the runtime SA is linked in Play Console. " +
        "Receipt validation is effectively DISABLED."
    );
    auth = new google.auth.GoogleAuth({scopes: PLAY_SCOPES});
  }

  return google.androidpublisher({version: "v3", auth: auth as any});
}

/** Maps a Play purchaseState (0=purchased,1=cancelled,2=pending) to a reason
 * code the client uses to decide whether it may revoke a cached entitlement.
 * ONLY "play_revoked" (an explicit store cancel/refund) authorises a revoke. */
function reasonForPurchaseState(purchaseState: number): string {
  if (purchaseState === 0) return "active";
  if (purchaseState === 1) return "play_revoked";
  return "pending";
}

// ─── Firestore helpers ───────────────────────────────────────────────────────

interface EntitlementRecord {
  isValid: boolean;
  productId: string;
  purchaseToken: string;
  lastVerifiedAt: string;
  /** 0 = purchased, 1 = cancelled, 2 = pending */
  purchaseState: number;
  /** Server record that Play acknowledgement is honoured (avoids 3-day refund). */
  acknowledged: boolean;
}

async function writeEntitlement(
  uid: string,
  record: EntitlementRecord
): Promise<void> {
  await db.collection("entitlements").doc(uid).set(record, {merge: true});
}

async function getEntitlement(uid: string): Promise<EntitlementRecord | null> {
  const doc = await db.collection("entitlements").doc(uid).get();
  if (!doc.exists) return null;
  return doc.data() as EntitlementRecord;
}

async function verifyProductWithPlay(
  productId: string,
  purchaseToken: string
): Promise<{isValid: boolean; purchaseState: number}> {
  const play = await getPlayClient();

  const response = await play.purchases.products.get({
    packageName: PACKAGE_NAME,
    productId: productId,
    token: purchaseToken,
  });

  const purchaseState = response.data.purchaseState ?? 1;
  // 0 = Purchased, 1 = Cancelled, 2 = Pending
  const isValid = purchaseState === 0;

  return {isValid, purchaseState};
}

// ─── Cloud Function: submitScore (survival leaderboard) ─────────────────────

export const submitScore = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign-in required.");
  }

  const uid = request.auth.uid;
  const rawScore = request.data?.scoreSeconds as number | undefined;
  const rawMode = request.data?.mode as string | undefined;
  const rawDisplayName = request.data?.displayName as string | undefined;
  const rawClientTimestampMs = request.data?.clientTimestampMs as
    | number
    | undefined;

  if (typeof rawScore !== "number" || typeof rawMode !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "scoreSeconds and mode are required."
    );
  }

  // ── Per-uid rate limit ─────────────────────────────────────────────────
  // ponytail: naive last-write check (small race window), fine for anti-spam;
  // move to a transaction only if abuse is observed.
  const metaRef = db.collection("submitMeta").doc(uid);
  const nowMs = Date.now();
  const lastMs =
    ((await metaRef.get()).data()?.lastScoreSubmitMs as number | undefined) ??
    0;
  if (nowMs - lastMs < SCORE_MIN_INTERVAL_MS) {
    throw new HttpsError("resource-exhausted", "Slow down.");
  }
  await metaRef.set({lastScoreSubmitMs: nowMs}, {merge: true});

  // scoreSeconds is clamped to a hard ceiling. True anti-cheat (score must be
  // plausible for the stage/inputs) needs a server-validated run model; not
  // built yet. See §backend-hardening.
  const scoreSeconds = clampInt(rawScore, 0, 60 * 60 * 24);
  const mode = sanitizeMode(rawMode);
  const displayName = sanitizeDisplayName(rawDisplayName, uid);
  const clientTimestampMs =
    typeof rawClientTimestampMs === "number"
      ? clampInt(rawClientTimestampMs, 0, Date.now() + 60_000)
      : Date.now();

  const now = admin.firestore.FieldValue.serverTimestamp();
  const leaderboardRef = db.collection("leaderboards").doc(mode);

  try {
    await leaderboardRef.collection("scores").add({
      uid,
      displayName,
      scoreSeconds,
      mode,
      createdAt: now,
    });

    const bestRef = leaderboardRef.collection("best").doc(uid);
    const existing = await bestRef.get();
    const previous = existing.data()?.scoreSeconds;
    const previousScore =
      typeof previous === "number" ? Math.floor(previous) : -1;
    if (!existing.exists || scoreSeconds > previousScore) {
      await bestRef.set(
        {uid, displayName, scoreSeconds, mode, updatedAt: now},
        {merge: true}
      );
    }

    await db.collection("runs").doc(uid).collection("sessions").add({
      scoreSeconds,
      mode,
      displayName,
      createdAt: now,
      clientTimestampMs,
    });

    return {ok: true, scoreSeconds, mode};
  } catch (err) {
    logger.error(`[submitScore] Error for uid=${uid}:`, err);
    throw new HttpsError("internal", "Failed to submit leaderboard score.");
  }
});

// ─── Cloud Function: upsertGlobalPanicProgress ──────────────────────────────
//
// Server-authoritative write for the Global Panic (stage + trophies) board.
// Clients no longer write leaderboards/global_panic/profiles/{uid} directly
// (firestore.rules denies it), so this is the single, rate-limited chokepoint.

export const upsertGlobalPanicProgress = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign-in required.");
  }
  const uid = request.auth.uid;

  const maxStage = clampInt(
    typeof request.data?.maxStage === "number" ? request.data.maxStage : 1,
    1,
    9999
  );
  const totalTrophies = clampInt(
    typeof request.data?.totalTrophies === "number" ?
      request.data.totalTrophies :
      0,
    0,
    9999999
  );
  const displayName = sanitizeDisplayName(request.data?.displayName, uid);
  const isGuest =
    request.auth.token?.firebase?.sign_in_provider === "anonymous";

  const ref = db
    .collection("leaderboards")
    .doc("global_panic")
    .collection("profiles")
    .doc(uid);

  try {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const prev = snap.data();
      const prevStage =
        typeof prev?.maxStage === "number" ? Math.floor(prev.maxStage) : 1;
      const prevTrophies =
        typeof prev?.totalTrophies === "number" ?
          Math.floor(prev.totalTrophies) :
          0;

      // Never regress on reinstall / restore.
      tx.set(
        ref,
        {
          uid,
          displayName,
          maxStage: Math.max(prevStage, maxStage),
          totalTrophies: Math.max(prevTrophies, totalTrophies),
          isGuest,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true}
      );
    });
    return {ok: true};
  } catch (err) {
    logger.error(`[upsertGlobalPanicProgress] Error for uid=${uid}:`, err);
    throw new HttpsError("internal", "Failed to update progress.");
  }
});

// ─── Cloud Function: verifyOneTimePurchase ───────────────────────────────────

export const verifyOneTimePurchase = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign-in required.");
  }
  const uid = request.auth.uid;
  const purchaseToken = request.data?.purchaseToken as string | undefined;
  const productId = request.data?.productId as string | undefined;

  if (!purchaseToken || !productId) {
    throw new HttpsError(
      "invalid-argument",
      "purchaseToken and productId are required."
    );
  }

  try {
    const result = await verifyProductWithPlay(productId, purchaseToken);

    const record: EntitlementRecord = {
      isValid: result.isValid,
      productId,
      purchaseToken,
      lastVerifiedAt: new Date().toISOString(),
      purchaseState: result.purchaseState,
      acknowledged: result.isValid,
    };

    await writeEntitlement(uid, record);

    return {
      isValid: result.isValid,
      reason: reasonForPurchaseState(result.purchaseState),
    };
  } catch (err) {
    logger.error(`[verifyOneTimePurchase] Error for uid=${uid}:`, err);
    throw new HttpsError("internal", "Failed to verify purchase.");
  }
});

// ─── Cloud Function: checkOneTimePurchaseStatus ─────────────────────────────

export const checkOneTimePurchaseStatus = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign-in required.");
  }
  const uid = request.auth.uid;
  const productId = request.data?.productId as string | undefined;

  const existing = await getEntitlement(uid);
  if (!existing || !existing.purchaseToken) {
    // No server record does NOT mean the purchase is invalid — it usually
    // means verification never reached Play (e.g. missing service account).
    // The client must keep its cached entitlement, not revoke it.
    return {isValid: false, reason: "no_record"};
  }

  // Use specific productId from request if provided, else the stored one.
  const targetProductId = productId ?? existing.productId;

  try {
    const result = await verifyProductWithPlay(
      targetProductId,
      existing.purchaseToken
    );

    const record: EntitlementRecord = {
      isValid: result.isValid,
      productId: targetProductId,
      purchaseToken: existing.purchaseToken,
      lastVerifiedAt: new Date().toISOString(),
      purchaseState: result.purchaseState,
      acknowledged: result.isValid,
    };

    await writeEntitlement(uid, record);

    return {
      isValid: result.isValid,
      reason: reasonForPurchaseState(result.purchaseState),
    };
  } catch (err) {
    logger.error(`[checkOneTimePurchaseStatus] Error for uid=${uid}:`, err);
    // Play API unreachable → trust the Firestore cache and tell the client NOT
    // to revoke (reason "unreachable", never "play_revoked").
    return {isValid: existing.isValid, reason: "unreachable", cached: true};
  }
});

// ─── Trigger: onAccountDeletionRequested ────────────────────────────────────
//
// Play policy requires deleting associated data, not just the auth account.
// Fires when the app writes accountDeletionRequests/{uid} and wipes every
// per-uid record: entitlements, submit meta, runs (recursive), and each
// leaderboard's profile/best/scores rows.
//
// NOTE: if `firebase deploy` reports a region mismatch for this trigger, add
// `{region: "<your-firestore-region>"}` as the first arg to onDocumentCreated.

export const onAccountDeletionRequested = onDocumentCreated(
  "accountDeletionRequests/{uid}",
  async (event) => {
    const uid = event.params.uid;
    logger.info(`[accountDeletion] wiping data for uid=${uid}`);

    const writer = db.bulkWriter();
    writer.delete(db.collection("entitlements").doc(uid));
    writer.delete(db.collection("submitMeta").doc(uid));

    const leaderboards = await db.collection("leaderboards").listDocuments();
    for (const modeRef of leaderboards) {
      writer.delete(modeRef.collection("profiles").doc(uid));
      writer.delete(modeRef.collection("best").doc(uid));
      const scores = await modeRef
        .collection("scores")
        .where("uid", "==", uid)
        .get();
      scores.docs.forEach((d) => writer.delete(d.ref));
    }
    await writer.close();

    // runs/{uid} owns a sessions subcollection — recursiveDelete clears both.
    await db.recursiveDelete(db.collection("runs").doc(uid));

    await event.data?.ref.set(
      {
        status: "completed",
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );
    logger.info(`[accountDeletion] done for uid=${uid}`);
  }
);
