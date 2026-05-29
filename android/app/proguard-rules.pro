# ── Google Mobile Ads / AdMob ──────────────────────────────────────────────
-keep public class com.google.android.gms.ads.** { public *; }
-keep public class com.google.android.gms.internal.** { public *; }
-keep class com.google.android.gms.ads.internal.webview.* { *; }
-dontwarn com.google.android.gms.ads.**

# ── Unity Ads ─────────────────────────────────────────────────────────────
-keep class com.unity3d.** { *; }
-keep class com.unity3d.ads.** { *; }
-keep class com.unity3d.services.** { *; }
-dontwarn com.unity3d.**

# ── Firebase SDK ──────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.firebase.crashlytics.** { *; }
-keep class com.google.firebase.analytics.** { *; }
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.firebase.functions.** { *; }
-dontwarn com.google.firebase.**

# ── Google Sign-In ────────────────────────────────────────────────────────
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.auth.**

# ── Billing / In-App Purchase ─────────────────────────────────────────────
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# ── Connectivity Plus ─────────────────────────────────────────────────────
-keep class com.baseflow.connectivity.** { *; }
-dontwarn com.baseflow.connectivity.**

# ── Shared Preferences / Path Provider ────────────────────────────────────
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-dontwarn io.flutter.plugins.sharedpreferences.**

# ── Flutter engine ────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class * extends java.lang.reflect.** { *; }

# ── General safety for reflection-based SDKs ──────────────────────────────
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep class * implements java.io.Serializable { *; }

# Remove all logging in release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
