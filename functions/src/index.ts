/**
 * FearFlip — Server-side one-time purchase verification via Firebase Cloud Functions.
 *
 * Exposes two HTTPS callable functions:
 *
 *   1. `verifyOneTimePurchase` — called after a new purchase or restore to validate
 *      the purchase token against the Google Play Developer API.
 *
 *   2. `checkOneTimePurchaseStatus` — called on app launch to re-verify
 *      cached entitlement (handles refunds / revocations).
 *
 * Both functions require the caller to be authenticated via Firebase Auth.
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {google} from "googleapis";

// ─── Initialisation ──────────────────────────────────────────────────────────

admin.initializeApp();
const db = admin.firestore();

const PACKAGE_NAME = process.env.FEARFLIP_PACKAGE_NAME ?? "com.rajnaik.fearflip";

// ─── Leaderboard helpers ───────────────────────────────────────────────────

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

function sanitizeDisplayName(
  displayName: unknown,
  uid: string
): string {
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

  return google.androidpublisher({version: "v3", auth: auth as any});
}

// ─── Firestore helpers ───────────────────────────────────────────────────────

interface EntitlementRecord {
  isValid: boolean;
  productId: string;
  purchaseToken: string;
  lastVerifiedAt: string;
  /** 0 = purchased, 1 = cancelled, 2 = pending */
  purchaseState: number;
}

async function writeEntitlement(
  uid: string,
  record: EntitlementRecord
): Promise<void> {
  await db
    .collection("entitlements")
    .doc(uid)
    .set(record, {merge: true});
}

async function getEntitlement(
  uid: string
): Promise<EntitlementRecord | null> {
  const doc = await db.collection("entitlements").doc(uid).get();
  if (!doc.exists) return null;
  return doc.data() as EntitlementRecord;
}

// ─── Core verification logic ─────────────────────────────────────────────────

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

// ─── Cloud Function: submitScore (leaderboards) ────────────────────────────

export const submitScore = functions.https.onCall(async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Sign-in required."
    );
  }

  const uid = request.auth.uid;
  const rawScore = request.data?.scoreSeconds as number | undefined;
  const rawMode = request.data?.mode as string | undefined;
  const rawDisplayName = request.data?.displayName as string | undefined;
  const rawClientTimestampMs = request.data?.clientTimestampMs as
    | number
    | undefined;

  if (typeof rawScore !== "number" || typeof rawMode !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "scoreSeconds and mode are required."
    );
  }

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
        {
          uid,
          displayName,
          scoreSeconds,
          mode,
          updatedAt: now,
        },
        {merge: true}
      );
    }

    await db
      .collection("runs")
      .doc(uid)
      .collection("sessions")
      .add({
        scoreSeconds,
        mode,
        displayName,
        createdAt: now,
        clientTimestampMs,
      });

    return {ok: true, scoreSeconds, mode};
  } catch (err) {
    functions.logger.error(`[submitScore] Error for uid=${uid}:`, err);
    throw new functions.https.HttpsError(
      "internal",
      "Failed to submit leaderboard score."
    );
  }
});

// ─── Cloud Function: verifyOneTimePurchase ───────────────────────────────────

export const verifyOneTimePurchase = functions.https.onCall(
  async (request) => {
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Sign-in required."
      );
    }
    const uid = request.auth.uid;
    const purchaseToken = request.data?.purchaseToken as string | undefined;
    const productId = request.data?.productId as string | undefined;

    if (!purchaseToken || !productId) {
      throw new functions.https.HttpsError(
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
      };

      await writeEntitlement(uid, record);

      return {isValid: result.isValid};
    } catch (err) {
      functions.logger.error(`[verifyOneTimePurchase] Error for uid=${uid}:`, err);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to verify purchase."
      );
    }
  }
);

// ─── Cloud Function: checkOneTimePurchaseStatus ─────────────────────────────

export const checkOneTimePurchaseStatus = functions.https.onCall(
  async (request) => {
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Sign-in required."
      );
    }
    const uid = request.auth.uid;
    const productId = request.data?.productId as string | undefined;

    const existing = await getEntitlement(uid);
    if (!existing || !existing.purchaseToken) {
      return {isValid: false};
    }

    // Use specific productId from request if provided, else use the one from Firestore
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
      };

      await writeEntitlement(uid, record);

      return {isValid: result.isValid};
    } catch (err) {
      functions.logger.error(`[checkOneTimePurchaseStatus] Error for uid=${uid}:`, err);
      // Fallback: trust Firestore cache if Play API is unreachable
      return {isValid: existing.isValid, cached: true};
    }
  }
);
