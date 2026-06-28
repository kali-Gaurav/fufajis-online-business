# ================================================================
# Fufaji's Online — ProGuard / R8 Rules
# ================================================================

# ── Flutter core ─────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# ── Firebase ──────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ── Razorpay (REQUIRED — without this, Razorpay crashes on release) ──
-keep class com.razorpay.** { *; }
-keep interface com.razorpay.** { *; }
-dontwarn com.razorpay.**
-keepattributes *Annotation*
-keepclassmembers class ** {
    @com.razorpay.* <methods>;
}

# ── Sentry crash reporting ────────────────────────────────────────
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**
-keepattributes LineNumberTable,SourceFile

# ── AdMob / Google Mobile Ads ─────────────────────────────────────
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# ── ML Kit (barcode, text recognition, image labeling) ───────────
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class com.google.android.odml.** { *; }
-dontwarn com.google.android.odml.**

# ── Hive local database ───────────────────────────────────────────
-keep class hive.** { *; }
-keep class com.hivedb.** { *; }

# ── SQFlite ───────────────────────────────────────────────────────
-keep class com.tekartik.sqflite.** { *; }

# ── Blue Thermal Printer ─────────────────────────────────────────
-keep class id.kakzaki.blue_thermal_printer.** { *; }
-dontwarn id.kakzaki.blue_thermal_printer.**

# ── Geolocator / Google Maps ──────────────────────────────────────
-keep class com.baseflow.geolocator.** { *; }
-keep class com.google.maps.** { *; }
-dontwarn com.google.maps.**

# ── Shorebird OTA ────────────────────────────────────────────────
-keep class dev.shorebird.** { *; }
-dontwarn dev.shorebird.**

# ── Google Play Core (deferred components) ────────────────────────
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# ── Suppress common annotation warnings ──────────────────────────
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
-dontwarn org.codehaus.mojo.animal_sniffer.**

# ── Keep Fufaji app models for Firestore deserialization ──────────
-keep class com.fufajis.online.** { *; }

# ── Kotlin ──
-dontwarn kotlin.time.Instant$Companion
-dontwarn kotlin.time.Instant

# ── Keep source file names for crash reports ─────────────────────
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
