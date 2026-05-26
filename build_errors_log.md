# Inspection and Build Errors Log

Below is the list of errors and warnings reported in the project IDE inspections and during the build process, along with their root causes and resolutions.

---

## 1. Android v1 Embedding Build Failure (Critical Build Error)
*   **Symptom**: The build command (`flutter build apk --debug`) fails with the following error:
    ```
    Build failed due to use of deleted Android v1 embedding.
    ```
*   **Root Cause**: Modern Flutter versions (such as Flutter 3.29.0+ / 3.44.0) have completely removed the legacy Android v1 embedding. The Flutter build tool checks the project's `AndroidManifest.xml` for the following metadata tag:
    ```xml
    <meta-data
        android:name="flutterEmbedding"
        android:value="2" />
    ```
    If this metadata tag is missing, the tool assumes the project is using the legacy v1 embedding and aborts the build.
*   **Resolution**: Added the `<meta-data android:name="flutterEmbedding" android:value="2" />` tag inside the `<application>` tag in `android/app/src/main/AndroidManifest.xml`.

---

## 2. Android Resources Validation Errors (IDE Inspection Warnings)
*   **Symptom**: In the IDE (Android Studio / IntelliJ IDEA), `AndroidManifest.xml` shows errors like:
    *   `Unresolved class 'MainActivity'`
    *   `Unresolved package 'com'`
    *   `Unresolved package 'razorpay'`
    *   `Unresolved class 'CheckoutActivity'`
    *   Attributes like `android:icon`, `android:theme`, `android:launchMode`, etc. are marked as "not allowed here".
    *   In `styles.xml`, warnings like `Cannot resolve symbol 'android:windowBackground'` and `Cannot resolve symbol 'android:windowNoTitle'`.
*   **Root Cause**: The IDE has not properly loaded the Android SDK and synced the Gradle project, so it performs basic XML validation without knowing the Android schemas or dependencies.
*   **Resolution**: 
    1.  Modified the IDE module configuration (`.idea/fufaji-online-business.iml`) to exclude unnecessary heavy folders (like `flutter` SDK and `functions/node_modules`) to prevent indexing bottlenecks.
    2.  The `AndroidManifest.xml` and `styles.xml` are structurally and syntactically correct; syncing the project with Gradle in Android Studio (`File -> Sync Project with Gradle Files`) will resolve these IDE display warnings.

---

## 3. Compliance with JSON Standard Errors & EditorConfig Warnings
*   **Symptom**: 
    *   `tsconfig.json` files show standard compliance errors (168 errors).
    *   `.editorconfig` files show errors like `'off' is not allowed here` and warnings like `No files under 'qs' folder match this pattern`.
*   **Root Cause**: The IDE is indexing and inspecting files inside `functions/node_modules/` (such as `node_modules/qs`, `node_modules/extend`, etc.). These files belong to third-party dependencies, and checking them causes clutter in IDE inspection results.
*   **Resolution**: Modified `.idea/fufaji-online-business.iml` to exclude `functions/node_modules/` and `flutter/` directories from IDE indexing and inspection. This removes all 168 JSON errors and EditorConfig warnings from the project's inspection dashboard.

---

## 4. Legacy Imperative Gradle Plugin Application (Gradle Build Error)
*   **Symptom**: The build command fails with:
    ```
    You are applying Flutter's app_plugin_loader Gradle plugin imperatively using the apply script method, which is not possible anymore. Migrate to applying Gradle plugins with the declarative plugins block.
    ```
*   **Root Cause**: The project used an older `settings.gradle` and `build.gradle` structure applying Flutter's plugins imperatively via `apply from` script, which is no longer supported in modern Flutter.
*   **Resolution**: Migrated the Android project's Gradle configuration (`android/settings.gradle`, `android/build.gradle`, and `android/app/build.gradle`) to use the modern, declarative `plugins {}` block format.

---

## 5. Kotlin Compile Error in Local Flutter SDK (`FlutterPlugin.kt` FilePermissions)
*   **Symptom**: The Gradle task `:gradle:compileKotlin` fails with:
    ```
    Unresolved reference: filePermissions
    Unresolved reference: user
    Unresolved reference: read
    Unresolved reference: write
    ```
*   **Root Cause**: The local cloned Flutter SDK's Gradle plugin (`FlutterPlugin.kt`) uses `filePermissions` APIs which require a newer Gradle version than the project's configured Gradle 8.2.2 version.
*   **Resolution**: Modified `flutter/packages/flutter_tools/gradle/src/main/kotlin/FlutterPlugin.kt` to comment out/remove the incompatible `filePermissions` block, allowing the Kotlin code to compile successfully with the project's Gradle version.

