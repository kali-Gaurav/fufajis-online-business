# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase ProGuard Rules
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Razorpay ProGuard Rules
-keep class com.razorpay.** {*;}
-dontwarn com.razorpay.**
-keepattributes *Annotation*
-dontwarn com.google.android.gms.internal.measurement.**

# GMS/Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Multidex
-keep class androidx.multidex.** { *; }

# Serialization
-keepclassmembers class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Keep project-specific models if needed for serialization
-keep class com.fufajis.online.models.** { *; }
