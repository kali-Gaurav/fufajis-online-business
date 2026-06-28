You can use Firebase Authentication to sign in a user by sending an SMS message
to the user's phone. The user signs in using a one-time code contained in the
SMS message.

The easiest way to add phone number sign-in to your app is to use
[FirebaseUI](https://github.com/firebase/firebaseui-android/),
which includes a drop-in sign-in widget that implements sign-in flows for phone
number sign-in, as well as password-based and federated sign-in. This document
describes how to implement a phone number sign-in flow using the Firebase SDK.
Phone numbers that end users provide for authentication will be sent and stored by Google to improve our spam and abuse prevention across Google services, including but not limited to Firebase. Developers should ensure they have appropriate end-user consent prior to using the Firebase Authentication phone number sign-in service.

## Before you begin

1. If you haven't already, [add Firebase to your Android project](https://firebase.google.com/docs/android/setup).
2. In your **module (app-level) Gradle file** (usually `<project>/<app-module>/build.gradle.kts` or `<project>/<app-module>/build.gradle`), add the dependency for the Firebase Authentication library for Android. We recommend using the [Firebase Android BoM](https://firebase.google.com/docs/android/learn-more#bom) to control library versioning.

   ```
   dependencies {
       // Import the BoM for the Firebase platform
       implementation(platform("com.google.firebase:firebase-bom:34.15.0"))

       // Add the dependency for the Firebase Authentication library
       // When using the BoM, you don't specify versions in Firebase library dependencies
       implementation("com.google.firebase:firebase-auth")
   }
   ```

   By using the [Firebase Android BoM](https://firebase.google.com/docs/android/learn-more#bom),
   your app will always use compatible versions of Firebase Android libraries.
   *(Alternative)*
   Add Firebase library dependencies *without* using the BoM

   If you choose not to use the Firebase BoM, you must specify each Firebase library version
   in its dependency line.

   **Note that if you use *multiple* Firebase libraries in your app, we strongly
   recommend using the BoM to manage library versions, which ensures that all versions are
   compatible.**

   ```groovy
   dependencies {
       // Add the dependency for the Firebase Authentication library
       // When NOT using the BoM, you must specify versions in Firebase library dependencies
       implementation("com.google.firebase:firebase-auth:24.1.0")
   }
   ```
3. If you haven't yet connected your app to your Firebase project, do so from the [Firebase console](https://console.firebase.google.com/).
4. If you haven't already set your app's SHA-1 hash in the [Firebase console](https://console.firebase.google.com/), do so. See [Authenticating Your Client](https://developers.google.com/android/guides/client-auth) for information about finding your app's SHA-1 hash.

### Security concerns

Authentication using only a phone number, while convenient, is less secure
than the other available methods, because possession of a phone number
can be easily transferred between users. Also, on devices with multiple user
profiles, any user that can receive SMS messages can sign in to an account using
the device's phone number.

If you use phone number based sign-in in your app, you should offer it
alongside more secure sign-in methods, and inform users of the security
tradeoffs of using phone number sign-in.

## Enable Phone Number sign-in for your Firebase project

To sign in users by SMS, you must first enable the Phone Number sign-in
method for your Firebase project:

1. In the Firebase console, go to **Security** \> [**Authentication**](https://console.firebase.google.com/project/_/authentication/).
2. In the **Sign-in method** tab, enable the **Phone** sign-in provider.
3. Set a policy on the regions to which you want to allow or deny SMS messages to be sent. Setting an SMS region policy can help protect your apps from SMS abuse. For new projects, the default policy allows no regions.
    1. In the Firebase console, go to the **Security** \> **Authentication** \> [**Settings** tab](https://console.firebase.google.com/project/_/authentication/settings).
    2. In the **SMS region policy** section, set up your SMS region policy.

> [!CAUTION]
> By enabling phone number authentication on Android, you agree to the[Play Integrity terms
> and conditions.](https://developer.android.com/google/play/integrity/terms)

## Enable app verification

To use phone number authentication, Firebase must be able to verify that
phone number sign-in requests are coming from your app. There are three ways
Firebase Authentication accomplishes this:

- **Play Integrity API** : If a user has a device with Google Play services installed, and Firebase Authentication can verify the device as legitimate with the [Play Integrity API](https://developer.android.com/google/play/integrity), phone number sign-in can proceed. The Play Integrity API is enabled on a Google-owned project by Firebase Authentication, not on your project. This does not contribute to any Play Integrity API quotas on your project. Play Integrity Support is available with the [Authentication SDK v21.2.0+](https://firebase.google.com/support/release-notes/android#auth_v21-2-0) (Firebase BoM v31.4.0+).

  To use Play Integrity, specify your app's SHA-256 fingerprint if you
  haven't already.
    1. In the Firebase console, go to the **Settings** \> [**General** tab](https://console.firebase.google.com/project/_/settings/general/).
    2. Scroll down to the **Your apps** card, select your Android app, and add your SHA-256 fingerprint in the **SHA certificate fingerprints** field.


See
[Authenticating Your Client](https://developers.google.com/android/guides/client-auth)
for details on how to get your app's SHA fingerprint.
- **reCAPTCHA verification** : In the event that Play Integrity cannot be used, such as when a user has a device *without* Google Play services installed, Firebase Authentication uses a reCAPTCHA verification to complete the phone sign-in flow. The reCAPTCHA challenge can often be completed without the user having to solve anything. Note that this flow requires that a SHA-1 is associated with your application. This flow also requires your API Key to be unrestricted or allowlisted for `PROJECT_ID.firebaseapp.com`.

  Some scenarios where reCAPTCHA is triggered:
    - If the end-user's device does not have Google Play services installed.
    - If the app is not distributed through Google Play Store (on [Authentication SDK v21.2.0+](https://firebase.google.com/support/release-notes/android#auth_v21-2-0)).
    - If the obtained SafetyNet token was not valid (on Authentication SDK versions \< v21.2.0).

  <br />

  When SafetyNet or Play Integrity is used for App verification, the `%APP_NAME%` field in the SMS template is populated with the app name determined from Google Play Store.
  In the scenarios where reCAPTCHA is triggered, `%APP_NAME%` is populated as `PROJECT_ID.firebaseapp.com`.

  > [!NOTE]
  > Authentication SDK versions before 22.0.0 use SafetyNet as fallback if Play Integrity token fetch fails. The reCAPTCHA flow will only be triggered when Play Integrity or safetyNet is unavailable. Nonetheless, you should ensure that both scenarios are working correctly.

  > [!NOTE]
  > Starting in the [Authentication SDK v21.2.0](https://firebase.google.com/support/release-notes/android#auth_v21-2-0) (Firebase BoM v31.4.0), the activity parameter is optional. However, if the activity is not set and reCAPTCHA verification is attempted, a `FirebaseAuthMissingActivityForRecaptchaException` is thrown, which can be handled in the `onVerificationFailed` callback.

You can force the reCAPTCHA verification flow with [`forceRecaptchaFlowForTesting`](https://firebase.google.com/docs/reference/android/com/google/firebase/auth/FirebaseAuthSettings#public-abstract-void-forcerecaptchaflowfortesting-boolean-forcerecaptchaflow) You can disable app verification (when using fictional phone numbers) using [`setAppVerificationDisabledForTesting`](https://firebase.google.com/docs/reference/android/com/google/firebase/auth/FirebaseAuthSettings#public-abstract-void-setappverificationdisabledfortesting-boolean-setverificationdisabled).

### Troubleshooting

-

#### "Missing initial state" error when using reCAPTCHA for app verification

This can occur when the reCAPTCHA flow completes successfully but does not redirect the user back to the native application. If this occurs, the user is redirected to the fallback URL `PROJECT_ID.firebaseapp.com/__/auth/handler`.
On Firefox browsers, opening native app links is disabled by default. If you see the above error on Firefox, follow the steps in [Set Firefox for Android to open links in native apps](https://support.mozilla.org/en-US/kb/set-firefox-android-open-links-native-apps) to enable opening app links.

## Send a verification code to the user's phone

To initiate phone number sign-in, present the user an interface that prompts
them to type their phone number. Legal requirements vary, but as a best practice
and to set expectations for your users, you should inform them that if they use
phone sign-in, they might receive an SMS message for verification and standard
rates apply.

Then, pass their phone number to the
`PhoneAuthProvider.verifyPhoneNumber` method to request that Firebase
verify the user's phone number. For example:

### Kotlin

```kotlin
val options = PhoneAuthOptions.newBuilder(auth)
    .setPhoneNumber(phoneNumber) // Phone number to verify
    .setTimeout(60L, TimeUnit.SECONDS) // Timeout and unit
    .setActivity(this) // Activity (for callback binding)
    .setCallbacks(callbacks) // OnVerificationStateChangedCallbacks
    .build()
PhoneAuthProvider.verifyPhoneNumber(options)
```

### Java

```java
PhoneAuthOptions options = 
  PhoneAuthOptions.newBuilder(mAuth) 
      .setPhoneNumber(phoneNumber)       // Phone number to verify
      .setTimeout(60L, TimeUnit.SECONDS) // Timeout and unit
      .setActivity(this)                 // (optional) Activity for callback binding
      // If no activity is passed, reCAPTCHA verification can not be used.
      .setCallbacks(mCallbacks)          // OnVerificationStateChangedCallbacks
      .build();
  PhoneAuthProvider.verifyPhoneNumber(options);     
```

> [!NOTE]
> **Note:** See [Firebase Authentication
> Limits](https://firebase.google.com/docs/auth/limits#phone-auth) for applicable usage limits and quotas.

The `verifyPhoneNumber` method is reentrant: if you call it
multiple times, such as in an activity's `onStart` method, the
`verifyPhoneNumber` method will not send a second SMS unless the
original request has timed out.

You can use this behavior to resume the phone number sign in process if your
app closes before the user can sign in (for example, while the user is using
their SMS app). After you call `verifyPhoneNumber`, set a flag that
indicates verification is in progress. Then, save the flag in your Activity's
`onSaveInstanceState` method and restore the flag in
`onRestoreInstanceState`. Finally, in your Activity's
`onStart` method, check if verification is already in progress, and
if so, call `verifyPhoneNumber` again. Be sure to clear the flag when
verification completes or fails (see [Verification callbacks](https://firebase.google.com/docs/auth/android/phone-auth#verification-callbacks)).

To easily handle screen rotation and other instances of Activity restarts,
pass your Activity to the `verifyPhoneNumber` method. The callbacks
will be auto-detached when the Activity stops, so you can freely write UI
transition code in the callback methods.

The SMS message sent by Firebase can also be localized by specifying the
auth language via the `setLanguageCode` method on your Auth
instance.

### Kotlin

```kotlin
auth.setLanguageCode("fr")
// To apply the default app language instead of explicitly setting it.
// auth.useAppLanguage()
```

### Java

```java
auth.setLanguageCode("fr");
// To apply the default app language instead of explicitly setting it.
// auth.useAppLanguage();
```

When you call `PhoneAuthProvider.verifyPhoneNumber`, you must also
provide an instance of `OnVerificationStateChangedCallbacks`, which
contains implementations of the callback functions that handle the results of
the request. For example:

### Kotlin

```kotlin
callbacks = object : PhoneAuthProvider.OnVerificationStateChangedCallbacks() {

    override fun onVerificationCompleted(credential: PhoneAuthCredential) {
        // This callback will be invoked in two situations:
        // 1 - Instant verification. In some cases the phone number can be instantly
        //     verified without needing to send or enter a verification code.
        // 2 - Auto-retrieval. On some devices Google Play services can automatically
        //     detect the incoming verification SMS and perform verification without
        //     user action.
        Log.d(TAG, "onVerificationCompleted:$credential")
        signInWithPhoneAuthCredential(credential)
    }

    override fun onVerificationFailed(e: FirebaseException) {
        // This callback is invoked in an invalid request for verification is made,
        // for instance if the the phone number format is not valid.
        Log.w(TAG, "onVerificationFailed", e)

        if (e is FirebaseAuthInvalidCredentialsException) {
            // Invalid request
        } else if (e is FirebaseTooManyRequestsException) {
            // The SMS quota for the project has been exceeded
        } else if (e is FirebaseAuthMissingActivityForRecaptchaException) {
            // reCAPTCHA verification attempted with null Activity
        }

        // Show a message and update the UI
    }

    override fun onCodeSent(
        verificationId: String,
        token: PhoneAuthProvider.ForceResendingToken,
    ) {
        // The SMS verification code has been sent to the provided phone number, we
        // now need to ask the user to enter the code and then construct a credential
        // by combining the code with a verification ID.
        Log.d(TAG, "onCodeSent:$verificationId")

        // Save verification ID and resending token so we can use them later
        storedVerificationId = verificationId
        resendToken = token
    }
}
```

### Java

```java
mCallbacks = new PhoneAuthProvider.OnVerificationStateChangedCallbacks() {

    @Override
    public void onVerificationCompleted(@NonNull PhoneAuthCredential credential) {
        // This callback will be invoked in two situations:
        // 1 - Instant verification. In some cases the phone number can be instantly
        //     verified without needing to send or enter a verification code.
        // 2 - Auto-retrieval. On some devices Google Play services can automatically
        //     detect the incoming verification SMS and perform verification without
        //     user action.
        Log.d(TAG, "onVerificationCompleted:" + credential);

        signInWithPhoneAuthCredential(credential);
    }

    @Override
    public void onVerificationFailed(@NonNull FirebaseException e) {
        // This callback is invoked in an invalid request for verification is made,
        // for instance if the the phone number format is not valid.
        Log.w(TAG, "onVerificationFailed", e);

        if (e instanceof FirebaseAuthInvalidCredentialsException) {
            // Invalid request
        } else if (e instanceof FirebaseTooManyRequestsException) {
            // The SMS quota for the project has been exceeded
        } else if (e instanceof FirebaseAuthMissingActivityForRecaptchaException) {
            // reCAPTCHA verification attempted with null Activity
        }

        // Show a message and update the UI
    }

    @Override
    public void onCodeSent(@NonNull String verificationId,
                           @NonNull PhoneAuthProvider.ForceResendingToken token) {
        // The SMS verification code has been sent to the provided phone number, we
        // now need to ask the user to enter the code and then construct a credential
        // by combining the code with a verification ID.
        Log.d(TAG, "onCodeSent:" + verificationId);

        // Save verification ID and resending token so we can use them later
        mVerificationId = verificationId;
        mResendToken = token;
    }
};
```

### Verification callbacks

In most apps, you implement the `onVerificationCompleted`,
`onVerificationFailed`, and `onCodeSent` callbacks. You
might also implement `onCodeAutoRetrievalTimeOut`, depending on your
app's requirements.

#### onVerificationCompleted(PhoneAuthCredential)

This method is called in two situations:

- Instant verification: in some cases the phone number can be instantly verified without needing to send or enter a verification code.
- Auto-retrieval: on some devices, Google Play services can automatically detect the incoming verification SMS and perform verification without user action. (This capability might be unavailable with some carriers.) This uses the [SMS Retriever API](https://developers.google.com/identity/sms-retriever), which includes an 11 character hash at the end of the SMS message.

In either case, the user's phone number has been verified successfully, and you can use the `PhoneAuthCredential` object that's passed to the callback to [sign in the user](https://firebase.google.com/docs/auth/android/phone-auth#sign-in-the-user).

<br />

#### onVerificationFailed(FirebaseException)

This method is called in response to an invalid verification request, such
as a request that specifies an invalid phone number or verification code.

#### onCodeSent(String verificationId, PhoneAuthProvider.ForceResendingToken)

Optional. This method is called after the verification code has been sent
by SMS to the provided phone number.

When this method is called, most apps display a UI that prompts the user
to type the verification code from the SMS message. (At the same time,
auto-verification might be proceeding in the background.) Then, after the user
types the verification code, you can use the verification code and the
verification ID that was passed to the method to create a
`PhoneAuthCredential` object, which you can in turn use to sign in
the user. However, some apps might wait until
`onCodeAutoRetrievalTimeOut` is called before displaying the
verification code UI (not recommended).

#### onCodeAutoRetrievalTimeOut(String verificationId)

Optional. This method is called after the timeout duration specified to
`verifyPhoneNumber` has passed without
`onVerificationCompleted` triggering first. On devices without SIM
cards, this method is called immediately because SMS auto-retrieval isn't
possible.

Some apps block user input until the auto-verification period has timed out,
and only then display a UI that prompts the user to type the verification code
from the SMS message (not recommended).

## Create a PhoneAuthCredential object

After the user enters the verification code that Firebase sent to the user's
phone, create a `PhoneAuthCredential` object, using the verification
code and the verification ID that was passed to the `onCodeSent` or
`onCodeAutoRetrievalTimeOut` callback. (When
`onVerificationCompleted` is called, you get a
`PhoneAuthCredential` object directly, so you can skip this step.)

To create the `PhoneAuthCredential` object, call
`PhoneAuthProvider.getCredential`:

### Kotlin

```kotlin
val credential = PhoneAuthProvider.getCredential(verificationId!!, code)
```

### Java

```java
PhoneAuthCredential credential = PhoneAuthProvider.getCredential(verificationId, code);
```

> [!NOTE]
> To prevent abuse, Firebase enforces a limit on the number of SMS messages that can be sent to a single phone number within a period of time. If you exceed this limit, phone number verification requests might be throttled. If you encounter this issue during development, use a different phone number for testing, or try the request again later.

## Sign in the user

After you get a `PhoneAuthCredential` object, whether in the
`onVerificationCompleted` callback or by calling
`PhoneAuthProvider.getCredential`, complete the sign-in flow by
passing the `PhoneAuthCredential` object to
`FirebaseAuth.signInWithCredential`:

### Kotlin

```kotlin
private fun signInWithPhoneAuthCredential(credential: PhoneAuthCredential) {
    auth.signInWithCredential(credential)
        .addOnCompleteListener(this) { task ->
            if (task.isSuccessful) {
                // Sign in success, update UI with the signed-in user's information
                Log.d(TAG, "signInWithCredential:success")

                val user = task.result?.user
            } else {
                // Sign in failed, display a message and update the UI
                Log.w(TAG, "signInWithCredential:failure", task.exception)
                if (task.exception is FirebaseAuthInvalidCredentialsException) {
                    // The verification code entered was invalid
                }
                // Update UI
            }
        }
}
```

### Java

```java
private void signInWithPhoneAuthCredential(PhoneAuthCredential credential) {
    mAuth.signInWithCredential(credential)
            .addOnCompleteListener(this, new OnCompleteListener<AuthResult>() {
                @Override
                public void onComplete(@NonNull Task<AuthResult> task) {
                    if (task.isSuccessful()) {
                        // Sign in success, update UI with the signed-in user's information
                        Log.d(TAG, "signInWithCredential:success");

                        FirebaseUser user = task.getResult().getUser();
                        // Update UI
                    } else {
                        // Sign in failed, display a message and update the UI
                        Log.w(TAG, "signInWithCredential:failure", task.getException());
                        if (task.getException() instanceof FirebaseAuthInvalidCredentialsException) {
                            // The verification code entered was invalid
                        }
                    }
                }
            });
}
```

## Test with fictional phone numbers


You can set up fictional phone numbers for development using the
Firebase console. Testing with fictional phone numbers provides these
benefits:

- Test phone number authentication without consuming your usage quota.
- Test phone number authentication without sending an actual SMS message.
- Run consecutive tests with the same phone number without getting throttled. This minimizes the risk of rejection during App store review process if the reviewer happens to use the same phone number for testing.
- Test readily in development environments without any additional effort, such as the ability to develop in an iOS simulator or an Android emulator without Google Play Services.
- Write integration tests without being blocked by security checks normally applied on real phone numbers in a production environment.


Fictional phone numbers must meet these requirements:

1. Make sure you use phone numbers that are indeed fictional, and do not already exist. Firebase Authentication does not allow you to set existing phone numbers used by real users as test numbers. One option is to use 555 prefixed numbers as US test phone numbers, for example: *+1 650-555-3434*
2. Phone numbers have to be correctly formatted for length and other constraints. They will still go through the same validation as a real user's phone number.
3. You can add up to 10 phone numbers for development.
4. Use test phone numbers/codes that are hard to guess and change those frequently.

### Create fictional phone numbers and verification codes

1. In the Firebase console, go to **Security** \> [**Authentication**](https://console.firebase.google.com/project/_/authentication/).
2. In the **Sign-in method** tab, enable the **Phone** sign-in provider if you haven't already.
3. Expand the **Phone numbers for testing** section.
4. Provide the phone number you want to test, for example: `+1 650-555-3434`.
5. Provide the 6-digit verification code for that specific number, for example: `654321`.
6. Click **Add** for each number. If needed, you can delete the phone number and its code by hovering over the corresponding row and clicking the trash icon.

### Manual testing

You can directly start using a fictional phone number in your application. This allows you to
perform manual testing during development stages without running into quota issues or throttling.
You can also test directly from an iOS simulator or Android emulator without Google Play Services
installed.

When you provide the fictional phone number and send the verification code, no actual SMS is
sent. Instead, you need to provide the previously configured verification code to complete the sign
in.

On sign-in completion, a Firebase user is created with that phone number. The
user has the same behavior and properties as a real phone number user, and can access
Realtime Database/Cloud Firestore and other services the same way. The ID token minted during
this process has the same signature as a real phone number user.

> [!CAUTION]
> Because the ID token for the fictional phone number has the same signature as a real phone number user, it is important to store these numbers securely and to continuously recycle them.

Another option is to [set a test role via custom
claims](https://firebase.google.com/docs/auth/admin/custom-claims) on these users to differentiate them as fake users if you want to further restrict
access.

To manually trigger the reCAPTCHA flow for testing, use the
`forceRecaptchaFlowForTesting()` method.

```
// Force reCAPTCHA flow
FirebaseAuth.getInstance().getFirebaseAuthSettings().forceRecaptchaFlowForTesting();
```

### Integration testing

In addition to manual testing, Firebase Authentication provides APIs to help write integration tests
for phone auth testing. These APIs disable app verification by disabling the reCAPTCHA
requirement in web and silent push notifications in iOS. This makes automation testing possible in
these flows and easier to implement. In addition, they help provide the ability to test instant
verification flows on Android.

> [!NOTE]
> Make sure app verification is not disabled for production apps and that no fictional phone numbers are hardcoded in your production app.

On Android, call `setAppVerificationDisabledForTesting()` before the
`signInWithPhoneNumber` call. This disables app verification automatically,
allowing you to pass the phone number without manually solving it. Even though
Play Integrity and reCAPTCHA are disabled, using a real phone number will still fail to
complete sign in. Only fictional phone numbers can be used with this API.

```
// Turn off phone auth app verification.
FirebaseAuth.getInstance().getFirebaseAuthSettings()
   .setAppVerificationDisabledForTesting();
```

Calling `verifyPhoneNumber` with a fictional number triggers the
`onCodeSent` callback, in which you'll need to provide the corresponding verification
code. This allows testing in Android Emulators.

### Java

```java
String phoneNum = "+16505554567";
String testVerificationCode = "123456";

// Whenever verification is triggered with the whitelisted number,
// provided it is not set for auto-retrieval, onCodeSent will be triggered.
FirebaseAuth auth = FirebaseAuth.getInstance();
PhoneAuthOptions options = PhoneAuthOptions.newBuilder(auth)
        .setPhoneNumber(phoneNum)
        .setTimeout(60L, TimeUnit.SECONDS)
        .setActivity(this)
        .setCallbacks(new PhoneAuthProvider.OnVerificationStateChangedCallbacks() {
            @Override
            public void onCodeSent(@NonNull String verificationId,
                                   @NonNull PhoneAuthProvider.ForceResendingToken forceResendingToken) {
                // Save the verification id somewhere
                // ...

                // The corresponding whitelisted code above should be used to complete sign-in.
                MainActivity.this.enableUserManuallyInputCode();
            }

            @Override
            public void onVerificationCompleted(@NonNull PhoneAuthCredential phoneAuthCredential) {
                // Sign in with the credential
                // ...
            }

            @Override
            public void onVerificationFailed(@NonNull FirebaseException e) {
                // ...
            }
        })
        .build();
PhoneAuthProvider.verifyPhoneNumber(options);
```

### Kotlin

```kotlin
val phoneNum = "+16505554567"
val testVerificationCode = "123456"

// Whenever verification is triggered with the whitelisted number,
// provided it is not set for auto-retrieval, onCodeSent will be triggered.
val options = PhoneAuthOptions.newBuilder(Firebase.auth)
    .setPhoneNumber(phoneNum)
    .setTimeout(30L, TimeUnit.SECONDS)
    .setActivity(this)
    .setCallbacks(object : PhoneAuthProvider.OnVerificationStateChangedCallbacks() {

        override fun onCodeSent(
            verificationId: String,
            forceResendingToken: PhoneAuthProvider.ForceResendingToken,
        ) {
            // Save the verification id somewhere
            // ...

            // The corresponding whitelisted code above should be used to complete sign-in.
            this@MainActivity.enableUserManuallyInputCode()
        }

        override fun onVerificationCompleted(phoneAuthCredential: PhoneAuthCredential) {
            // Sign in with the credential
            // ...
        }

        override fun onVerificationFailed(e: FirebaseException) {
            // ...
        }
    })
    .build()
PhoneAuthProvider.verifyPhoneNumber(options)
```

Additionally, you can test auto-retrieval flows in Android by setting the fictional number and
its corresponding verification code for auto-retrieval by calling
`setAutoRetrievedSmsCodeForPhoneNumber`.

When `verifyPhoneNumber` is
called, it triggers `onVerificationCompleted` with the `PhoneAuthCredential`
directly. This works only with fictional phone numbers.

Make sure this is disabled and no fictional phone numbers are hardcoded in
your app when publishing your application to the Google Play store.

### Java

```java
// The test phone number and code should be whitelisted in the console.
String phoneNumber = "+16505554567";
String smsCode = "123456";

FirebaseAuth firebaseAuth = FirebaseAuth.getInstance();
FirebaseAuthSettings firebaseAuthSettings = firebaseAuth.getFirebaseAuthSettings();

// Configure faking the auto-retrieval with the whitelisted numbers.
firebaseAuthSettings.setAutoRetrievedSmsCodeForPhoneNumber(phoneNumber, smsCode);

PhoneAuthOptions options = PhoneAuthOptions.newBuilder(firebaseAuth)
        .setPhoneNumber(phoneNumber)
        .setTimeout(60L, TimeUnit.SECONDS)
        .setActivity(this)
        .setCallbacks(new PhoneAuthProvider.OnVerificationStateChangedCallbacks() {
            @Override
            public void onVerificationCompleted(@NonNull PhoneAuthCredential credential) {
                // Instant verification is applied and a credential is directly returned.
                // ...
            }

            // ...
        })
        .build();
PhoneAuthProvider.verifyPhoneNumber(options);
```

### Kotlin

```kotlin
// The test phone number and code should be whitelisted in the console.
val phoneNumber = "+16505554567"
val smsCode = "123456"

val firebaseAuth = Firebase.auth
val firebaseAuthSettings = firebaseAuth.firebaseAuthSettings

// Configure faking the auto-retrieval with the whitelisted numbers.
firebaseAuthSettings.setAutoRetrievedSmsCodeForPhoneNumber(phoneNumber, smsCode)

val options = PhoneAuthOptions.newBuilder(firebaseAuth)
    .setPhoneNumber(phoneNumber)
    .setTimeout(60L, TimeUnit.SECONDS)
    .setActivity(this)
    .setCallbacks(object : PhoneAuthProvider.OnVerificationStateChangedCallbacks() {
        override fun onVerificationCompleted(credential: PhoneAuthCredential) {
            // Instant verification is applied and a credential is directly returned.
            // ...
        }

        // ...
    })
    .build()
PhoneAuthProvider.verifyPhoneNumber(options)
```

## Next steps

After a user signs in for the first time, a new user account is created and
linked to the credentials---that is, the user name and password, phone
number, or auth provider information---the user signed in with. This new
account is stored as part of your Firebase project, and can be used to identify
a user across every app in your project, regardless of how the user signs in.

- In your apps, you can get the user's basic profile information from the
  [`FirebaseUser`](https://firebase.google.com/docs/reference/android/com/google/firebase/auth/FirebaseUser) object. See [Manage Users](https://firebase.google.com/docs/auth/android/manage-users).

- In your Firebase Realtime Database and Cloud Storage
  [Security Rules](https://firebase.google.com/docs/database/security/user-security), you can
  get the signed-in user's unique user ID from the `auth` variable,
  and use it to control what data a user can access.

You can allow users to sign in to your app using multiple authentication
providers by [linking auth provider credentials to an
existing user account.](https://firebase.google.com/docs/auth/android/account-linking)

To sign out a user, call [`signOut`](https://firebase.google.com/docs/reference/android/com/google/firebase/auth/FirebaseAuth#signOut()):

### Kotlin

```kotlin
Firebase.auth.signOut()
```

### Java

```java
FirebaseAuth.getInstance().signOut();
```


[Video](https://www.youtube.com/watch?v=FkFvQ0SaT1I)

## Prerequisites

- Install your preferred
  [editor or IDE](https://docs.flutter.dev/get-started/editor/).

- [Install Flutter](https://docs.flutter.dev/get-started/install/)
  for your specific operating system, including the following:

    - Flutter SDK
    - Supporting libraries
    - Platform-specific software and SDKs

Platform-specific prerequisites:

### Apple

- Set up a physical Apple device or use a simulator to run your app.

- Make sure that your Flutter app targets the following platform versions or
  later:

    - iOS 15
    - macOS 10.15

<br />

Do you want to use Cloud Messaging?

<br />

<br />

> For Cloud Messaging on Apple platforms, here are the prerequisites:
>
> - Set up a *physical Apple device*.
> - Obtain an Apple Push Notification Authentication Key for your [Apple Developer account](https://developer.apple.com/account).
> - Enable Push Notifications in Xcode under **App \> Capabilities**.

<br />

<br />

> [!NOTE]
> **Note:** If you're targeting macOS or macOS Catalyst, you must add the [Keychain Sharing capability](https://firebase.google.com/docs/ios/troubleshooting-faq#macos-keychain-sharing) to your target. In Xcode, navigate to your target's **Signing \& Capabilities** tab, and then click **+ Capabilities** to add a new capability.

### Android

- Set up a device or emulator for running your app.
  [Emulators](https://developer.android.com/studio/run/managing-avds)
  must use an emulator image with Google Play.

- Make sure that your app meets the following requirements:

    - Targets API level 23 (Marshmallow) or higher
    - Uses Android 6.0 or higher

### Web

No platform-specific prerequisites

If you don't already have a Flutter app, you can complete the
[Get Started: Test Drive](https://docs.flutter.dev/get-started/test-drive)
to create a new Flutter app using your preferred editor or IDE.

## **Step 1**: Install the required command line tools

1. If you haven't already,
   [install the Firebase CLI](https://firebase.google.com/docs/cli#setup_update_cli).

2. Log into Firebase using your Google Account by running the following
   command:

       firebase login

3. Install the FlutterFire CLI by running the following command from any
   directory:

       dart pub global activate flutterfire_cli

## **Step 2**: Configure your apps to use Firebase

Use the FlutterFire CLI to configure your Flutter apps to connect to Firebase.

From your Flutter project directory, run the following command to start the
app configuration workflow:

    flutterfire configure

<br />

What does this `flutterfire configure`
workflow do?

<br />

> The `flutterfire configure` workflow does the following:
>
> - Asks you to select the platforms (iOS, Android, Web) supported in your
    >   Flutter app. For each selected platform, the FlutterFire CLI creates a new
    >   Firebase app in your Firebase project.
    >
    >   You can select either to use an existing Firebase project or to create a
    >   new Firebase project. If you already have apps registered in an existing
    >   Firebase project, the FlutterFire CLI will attempt to match them based on
    >   your current Flutter project configuration.
    >
    >   > [!NOTE]
    >   > **Note:** Here are some tips about setting up and managing your Firebase project:
    >   > - Check out our [best practices](https://firebase.google.com/docs/projects/dev-workflows/general-best-practices) for adding apps to a Firebase project, including how to handle multiple variants.
    >   > - [Enable Google Analytics](https://support.google.com/firebase/answer/9289399#linkga) in your project, which provides an optimal experience using many Firebase products, like Crashlytics and Remote Config.
>
> - Creates a Firebase configuration file (`firebase_options.dart`) and adds it
    >   to your `lib/` directory.
    >
    >   > [!NOTE]
    >   > **Note:** This Firebase config file contains unique, but non-secret identifiers for each platform you selected.   
    >   > Visit [Understand Firebase Projects](https://firebase.google.com/docs/projects/learn-more#config-files-objects) to learn more about this config file.
>
> - *(for Crashlytics or Performance Monitoring on Android)* Adds the required
    >   product-specific Gradle plugins to your Flutter app.
    >
    >   > [!NOTE]
    >   > **Note:** For the FlutterFire CLI to add the appropriate Gradle plugin, the product's Flutter plugin must already be imported into your Flutter app.
>
<br />

<br />

<br />

> [!CAUTION]
> After this initial running of `flutterfire configure`, you need to re-run the command any time that you:
>
> - Start supporting a new platform in your Flutter app.
> - Start using a new Firebase service or product in your Flutter app, especially if you start using sign-in with Google, Crashlytics, Performance Monitoring, or Realtime Database.
>
>
> Re-running the command ensures that your Flutter app's Firebase
> configuration is up-to-date and (for Android) automatically adds any
> required Gradle plugins to your app.

## **Step 3**: Initialize Firebase in your app

1. From your Flutter project directory, run the following command to install
   the core plugin:

       flutter pub add firebase_core

2. From your Flutter project directory, run the following command to ensure
   that your Flutter app's Firebase configuration is up-to-date:

       flutterfire configure

3. In your `lib/main.dart` file, import the Firebase core plugin and the
   configuration file you generated earlier:

       import 'package:firebase_core/firebase_core.dart';
       import 'firebase_options.dart';

4. Also in your `lib/main.dart` file, initialize Firebase using the
   `DefaultFirebaseOptions` object exported by the configuration file:

       WidgetsFlutterBinding.ensureInitialized();
       await Firebase.initializeApp(
         options: DefaultFirebaseOptions.currentPlatform,
       );
       runApp(const MyApp());

5. Rebuild your Flutter application:

       flutter run

If you would rather use a demo project, you can start the
[Firebase Emulator](https://firebase.google.com/docs/emulator-suite) and in your `lib/main.dart` file
initialize Firebase using `demoProjectId` (it should start with `demo-`):

    await Firebase.initializeApp(
      demoProjectId: "demo-project-id",
    );

## **Step 4**: Add Firebase plugins

You access Firebase in your Flutter app through the various
[Firebase Flutter plugins](https://firebase.google.com/docs/flutter/setup#available-plugins), one for each
Firebase product
(for example: Cloud Firestore, Authentication, Analytics, etc.).

Since Flutter is a multi-platform framework, each Firebase plugin is applicable
for Apple, Android, and web platforms. So, if you add any Firebase plugin to
your Flutter app, it will be used by the Apple, Android, and web versions of
your app.

Here's how to add a Firebase Flutter plugin:

1. From your Flutter project directory, run the following command:

   ```
   flutter pub add PLUGIN_NAME
   ```
2. From your Flutter project directory, run the following command:

       flutterfire configure

   Running this command ensures that your Flutter app's Firebase configuration
   is up-to-date and, for Crashlytics and Performance Monitoring on Android, adds the
   required Gradle plugins to your app.
3. Once complete, rebuild your Flutter project:

       flutter run

You're all set! Your Flutter apps are registered and configured to use Firebase.

<br />

### Special considerations for building web
apps

<br />

#### Trusted Types support

The Firebase SDK for Flutter supports using Trusted Types to help prevent
DOM-based (client-side) XSS attacks. When you
[enable Trusted Type enforcement](https://web.dev/trusted-types/#switch-to-enforcing-content-security-policy)
for your app, the Firebase SDK injects its scripts into the DOM using custom
Trusted Type policies, named `flutterfire-firebase_core`,
`flutterfire-firebase_auth`, etc.

#### Disable Firebase JavaScript SDK auto-injection

By default, the Firebase Flutter SDK auto-injects the Firebase JavaScript SDK
when building for the web. If you don't want the Firebase JavaScript SDK to be
auto-injected, you can do the following:

1. Ignore the auto-injection script by adding the following property inside a
   `<script>` tag within the `web/index.html` file in your Flutter project:

       <!-- Add this property inside a <script> tag within your "web/index.html" file in your Flutter project -->
       <!-- Put in the names of all the plugins you wish to ignore: -->
       window.flutterfire_ignore_scripts = ['analytics', 'firestore'];

2. Load the script manually using one of the following options:

    - **Option 1** : Add the SDK explicitly to your `web/index.html` file,
      inside the `window.addEventListener` callback:

            window.addEventListener('load', async function (ev) {
              window.firebase_firestore = await import("https://www.gstatic.com/firebasejs/12.15.0/firebase-firestore.js");
              window.firebase_analytics = await import("https://www.gstatic.com/firebasejs/12.15.0/firebase-analytics.js");

              _flutter.loader.loadEntrypoint().then(function (engineInitializer) {
                // rest of the code

    - **Option 2** : Download the plugin's Firebase JavaScript SDK code from the
      `gstatic` domain, and save them to a JavaScript file to be kept within
      your project and loaded in manually:

            // "web/my-analytics.js" & "web/my-firestore.js" file loaded as a script into your "web/index.html" file:
            window.addEventListener('load', async function (ev) {
              window.firebase_analytics = await import("./my-analytics.js");
              window.firebase_firestore = await import("./my-firestore.js");

              _flutter.loader.loadEntrypoint().then(function (engineInitializer) {
                // rest of the code

<br />

<br />

<br />

*** ** * ** ***

## Available plugins

| Product | Plugin name | iOS | Android | Web | Other Apple (macOS, etc.) | Windows |
|---|---|---|---|---|---|---|
| [Firebase AI Logic](https://firebase.google.com/docs/ai-logic/get-started) ^1^ | `firebase_ai` |   |   |   | beta |   |
| [Analytics](https://firebase.google.com/docs/analytics/get-started?platform=flutter) | `firebase_analytics` |   |   |   | beta |   |
| [App Check](https://firebase.google.com/docs/app-check/flutter/default-providers) | `firebase_app_check` |   |   |   | beta |   |
| [Authentication](https://firebase.google.com/docs/auth/flutter/start) | `firebase_auth` |   |   |   | beta | beta |
| [Cloud Firestore](https://firebase.google.com/docs/firestore/quickstart) | `cloud_firestore` |   |   |   | beta | beta |
| [Cloud Functions](https://firebase.google.com/docs/functions/get-started) | `cloud_functions` |   |   |   | beta |   |
| [Cloud Messaging](https://firebase.google.com/docs/cloud-messaging/flutter/client) | `firebase_messaging` |   |   |   | beta |   |
| [Cloud Storage](https://firebase.google.com/docs/storage/flutter/start) | `firebase_storage` |   |   |   | beta | beta |
| [Crashlytics](https://firebase.google.com/docs/crashlytics/flutter/get-started) | `firebase_crashlytics` |   |   |   | beta |   |
| [SQL Connect](https://firebase.google.com/docs/sql-connect/flutter-sdk) ^2^ | `firebase_data_connect` |   |   |   |   |   |
| [Dynamic Links](https://firebase.google.com/docs/dynamic-links/flutter/create) | `firebase_dynamic_links` |   |   |   |   |   |
| [In-App Messaging](https://firebase.google.com/docs/in-app-messaging/get-started?platform=flutter) | `firebase_in_app_messaging` |   |   |   |   |   |
| [Firebase installations](https://firebase.google.com/docs/projects/manage-installations) | `firebase_app_installations` |   |   |   | beta |   |
| [ML Model Downloader](https://firebase.google.com/docs/ml/flutter/use-custom-models) | `firebase_ml_model_downloader` |   |   |   | beta |   |
| [Performance Monitoring](https://firebase.google.com/docs/perf-mon/flutter/get-started) | `firebase_performance` |   |   |   |   |   |
| [Realtime Database](https://firebase.google.com/docs/database/flutter/start) | `firebase_database` |   |   |   | beta |   |
| [Remote Config](https://firebase.google.com/docs/remote-config/get-started?platform=flutter) | `firebase_remote_config` |   |   |   | beta |   |

^**1** *Firebase AI Logic was formerly called
"Vertex AI in Firebase" with the plugin
`firebase_vertexai`.*^

^**2** *Firebase SQL Connect was formerly called
"Firebase Data Connect".*^

> [!CAUTION]
> **Caution:** Firebase on Windows is not intended for production use cases, only local development workflows.

<br />

*** ** * ** ***

## Next steps

- Get hands-on experience with the
  [Firebase Flutter Codelab](https://firebase.google.com/codelabs/firebase-get-to-know-flutter).

- Prepare to launch your app:

    - Set up [budget
      alerts](https://firebase.google.com/docs/projects/billing/avoid-surprise-bills#set-up-budget-alert-emails) for your project in the Google Cloud console.
    - Monitor the [*Usage and billing*
      dashboard](https://console.firebase.google.com/project/_/usage) in the Firebase console to get an overall picture of your project's usage across multiple Firebase services.
    - Review the [Firebase launch checklist](https://firebase.google.com/support/guides/launch-checklist)./