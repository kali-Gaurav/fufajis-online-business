package com.fufaji.store;

import android.app.Application;
import com.google.firebase.FirebaseApp;
import timber.log.Timber;
import java.util.TimeZone;

public class FujafiApplication extends Application {
    @Override
    public void onCreate() {
        super.onCreate();

        try {
            // Set default timezone to UTC for consistent date/time handling
            TimeZone.setDefault(TimeZone.getTimeZone("UTC"));

            // Initialize Firebase
            FirebaseApp.initializeApp(this);

            // Initialize Timber for logging
            if (BuildConfig.DEBUG) {
                Timber.plant(new Timber.DebugTree());
            }

            Timber.d("Fufaji Store Application started successfully");
            Timber.d("Timezone set to: %s", TimeZone.getDefault().getDisplayName());
        } catch (Exception e) {
            Timber.e(e, "Error initializing Fufaji Store Application");
            throw new RuntimeException("Failed to initialize application", e);
        }
    }
}
