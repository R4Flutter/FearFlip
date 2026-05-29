"use strict";
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
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkOneTimePurchaseStatus = exports.verifyOneTimePurchase = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const googleapis_1 = require("googleapis");
// ─── Initialisation ──────────────────────────────────────────────────────────
admin.initializeApp();
const db = admin.firestore();
const PACKAGE_NAME = process.env.FEARFLIP_PACKAGE_NAME ?? "com.rajnaik.fearflip";
// ─── Google Play Developer API client ────────────────────────────────────────
async function getPlayClient() {
    let auth;
    try {
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const key = require("../service-account.json");
        auth = new googleapis_1.google.auth.GoogleAuth({
            credentials: key,
            scopes: ["https://www.googleapis.com/auth/androidpublisher"],
        });
    }
    catch {
        auth = new googleapis_1.google.auth.GoogleAuth({
            scopes: ["https://www.googleapis.com/auth/androidpublisher"],
        });
    }
    return googleapis_1.google.androidpublisher({ version: "v3", auth: auth });
}
async function writeEntitlement(uid, record) {
    await db
        .collection("entitlements")
        .doc(uid)
        .set(record, { merge: true });
}
async function getEntitlement(uid) {
    const doc = await db.collection("entitlements").doc(uid).get();
    if (!doc.exists)
        return null;
    return doc.data();
}
// ─── Core verification logic ─────────────────────────────────────────────────
async function verifyProductWithPlay(productId, purchaseToken) {
    const play = await getPlayClient();
    const response = await play.purchases.products.get({
        packageName: PACKAGE_NAME,
        productId: productId,
        token: purchaseToken,
    });
    const purchaseState = response.data.purchaseState ?? 1;
    // 0 = Purchased, 1 = Cancelled, 2 = Pending
    const isValid = purchaseState === 0;
    return { isValid, purchaseState };
}
// ─── Cloud Function: verifyOneTimePurchase ───────────────────────────────────
exports.verifyOneTimePurchase = functions.https.onCall(async (request) => {
    if (!request.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Sign-in required.");
    }
    const uid = request.auth.uid;
    const purchaseToken = request.data?.purchaseToken;
    const productId = request.data?.productId;
    if (!purchaseToken || !productId) {
        throw new functions.https.HttpsError("invalid-argument", "purchaseToken and productId are required.");
    }
    try {
        const result = await verifyProductWithPlay(productId, purchaseToken);
        const record = {
            isValid: result.isValid,
            productId,
            purchaseToken,
            lastVerifiedAt: new Date().toISOString(),
            purchaseState: result.purchaseState,
        };
        await writeEntitlement(uid, record);
        return { isValid: result.isValid };
    }
    catch (err) {
        functions.logger.error(`[verifyOneTimePurchase] Error for uid=${uid}:`, err);
        throw new functions.https.HttpsError("internal", "Failed to verify purchase.");
    }
});
// ─── Cloud Function: checkOneTimePurchaseStatus ─────────────────────────────
exports.checkOneTimePurchaseStatus = functions.https.onCall(async (request) => {
    if (!request.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Sign-in required.");
    }
    const uid = request.auth.uid;
    const productId = request.data?.productId;
    const existing = await getEntitlement(uid);
    if (!existing || !existing.purchaseToken) {
        return { isValid: false };
    }
    // Use specific productId from request if provided, else use the one from Firestore
    const targetProductId = productId ?? existing.productId;
    try {
        const result = await verifyProductWithPlay(targetProductId, existing.purchaseToken);
        const record = {
            isValid: result.isValid,
            productId: targetProductId,
            purchaseToken: existing.purchaseToken,
            lastVerifiedAt: new Date().toISOString(),
            purchaseState: result.purchaseState,
        };
        await writeEntitlement(uid, record);
        return { isValid: result.isValid };
    }
    catch (err) {
        functions.logger.error(`[checkOneTimePurchaseStatus] Error for uid=${uid}:`, err);
        // Fallback: trust Firestore cache if Play API is unreachable
        return { isValid: existing.isValid, cached: true };
    }
});
//# sourceMappingURL=index.js.map