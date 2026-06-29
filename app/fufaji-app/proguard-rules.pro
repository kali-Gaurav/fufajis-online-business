# Proguard rules for Fufaji Store Android App
# Optimizes and obfuscates code for production

# ============================================================================
# GENERAL RULES
# ============================================================================

# Keep line numbers for debugging
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Keep annotations
-keepattributes *Annotation*,InnerClasses
-keepattributes Signature,Exception

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep view constructors for inflation
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}

# ============================================================================
# FIREBASE
# ============================================================================

# Firebase Auth
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.firebase.internal.** { *; }

# Firebase Firestore
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.firestore.** { *; }
-keepclassmembers class com.google.firebase.firestore.** {
    *** get*();
    void set*(***);
}

# Firebase Cloud Messaging
-keep class com.google.firebase.messaging.** { *; }

# Firebase Analytics
-keep class com.google.firebase.analytics.** { *; }

# Firebase Storage
-keep class com.google.firebase.storage.** { *; }

# Firebase Cloud Functions
-keep class com.google.firebase.functions.** { *; }

# Firebase Common
-keep class com.google.firebase.common.** { *; }

# ============================================================================
# RAZORPAY
# ============================================================================

-keep class com.razorpay.** { *; }
-keepclassmembers class com.razorpay.** { *; }

# ============================================================================
# MATERIAL DESIGN
# ============================================================================

-keep class com.google.android.material.** { *; }
-keep interface com.google.android.material.** { *; }

# ============================================================================
# ANDROIDX
# ============================================================================

-keep class androidx.** { *; }
-keep interface androidx.** { *; }

# AppCompat
-keep class android.support.v7.app.AppCompatActivity { *; }
-keep class androidx.appcompat.app.AppCompatActivity { *; }

# RecyclerView
-keepclassmembers class androidx.recyclerview.widget.RecyclerView {
    public void setAdapter(androidx.recyclerview.widget.RecyclerView$Adapter);
    public void setLayoutManager(androidx.recyclerview.widget.RecyclerView$LayoutManager);
}

# View Binding
-keepclasseswithmembernames class * {
    @android.view.BindView <fields>;
}

# Data Binding
-keep class **.databinding.** { *; }

# ============================================================================
# GLIDE & IMAGE LOADING
# ============================================================================

-keep public class * extends com.bumptech.glide.module.AppGlideModule
-keep class com.bumptech.glide.** { *; }
-keep public enum com.bumptech.glide.** { *; }
-keep public interface com.bumptech.glide.** { *; }

# ============================================================================
# RETROFIT & OKHTTP
# ============================================================================

-keep class com.squareup.okhttp3.** { *; }
-keep interface com.squareup.okhttp3.** { *; }
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

-keep class retrofit2.** { *; }
-keep interface retrofit2.** { *; }

# OkHttp platform
-keep class okhttp3.internal.platform.** { *; }

# ============================================================================
# GSON
# ============================================================================

-keep class com.google.gson.** { *; }
-keep interface com.google.gson.** { *; }

# Keep generic signatures
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Prevent Gson from stripping generic types
-keepattributes Signature

# ============================================================================
# TIMBER LOGGING
# ============================================================================

-keep class com.jakewharton.timber.** { *; }

# ============================================================================
# RXJAVA
# ============================================================================

-keep class io.reactivex.** { *; }
-keep interface io.reactivex.** { *; }
-keep class rx.** { *; }
-keep interface rx.** { *; }

# ============================================================================
# APP MODELS & SERVICES
# ============================================================================

# Keep all app models (data classes)
-keep class com.fufaji.store.models.** { *; }
-keep class com.fufaji.store.services.** { *; }
-keep class com.fufaji.store.managers.** { *; }
-keep class com.fufaji.store.utils.** { *; }
-keep class com.fufaji.store.adapters.** { *; }
-keep class com.fufaji.store.activities.** { *; }

# Keep Firebase model classes
-keep class com.fufaji.store.models.** {
    @com.google.firebase.firestore.PropertyName <fields>;
}

# ============================================================================
# GOOGLE PLAY SERVICES
# ============================================================================

-keep class com.google.android.gms.** { *; }
-keep interface com.google.android.gms.** { *; }

# ============================================================================
# NATIVE METHODS
# ============================================================================

-keepclasseswithmembernames class * {
    native <methods>;
}

# ============================================================================
# CALLBACK INTERFACES
# ============================================================================

-keep class * implements com.fufaji.store.services.FirebaseService$OnSuccessListener { *; }
-keep class * implements com.fufaji.store.services.FirebaseService$OnFailureListener { *; }

# ============================================================================
# PARCELABLE & SERIALIZABLE
# ============================================================================

-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

-keep class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ============================================================================
# OPTIMIZATION OPTIONS
# ============================================================================

# Aggressive optimization
-optimizationpasses 5
-dontusemixedcaseclassnames

# Remove logging
-assumenosideeffects class timber.log.Timber {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# ============================================================================
# DEBUG & TESTING (Remove for production)
# ============================================================================

# Keep test classes and runner
-keep class android.test.** { *; }
-keep interface android.test.** { *; }
-keep class androidx.test.** { *; }
-keep interface androidx.test.** { *; }
-keep class junit.** { *; }
-keep class org.junit.** { *; }

# ============================================================================
# WARNINGS
# ============================================================================

-dontwarn android.support.**
-dontwarn androidx.**
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**
-dontwarn com.razorpay.**
-dontwarn okhttp3.**
-dontwarn retrofit2.**
-dontwarn com.google.gson.**
-dontwarn io.reactivex.**
-dontwarn rx.**
-dontwarn sun.misc.Unsafe
-dontwarn com.google.j2objc.annotations.Weak
-dontwarn java.lang.ClassValue

# ============================================================================
# END OF PROGUARD RULES
# ============================================================================
