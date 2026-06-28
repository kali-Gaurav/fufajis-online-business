package com.fufaji.store.managers;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.TextView;

import androidx.appcompat.app.AlertDialog;

import com.fufaji.store.BuildConfig;
import com.fufaji.store.R;
import com.google.firebase.remoteconfig.FirebaseRemoteConfig;
import com.google.firebase.remoteconfig.FirebaseRemoteConfigSettings;

import timber.log.Timber;

public class UpdateManager {
    private final Activity activity;
    private final FirebaseRemoteConfig remoteConfig;

    public UpdateManager(Activity activity) {
        this.activity = activity;
        this.remoteConfig = FirebaseRemoteConfig.getInstance();

        FirebaseRemoteConfigSettings configSettings = new FirebaseRemoteConfigSettings.Builder()
                .setMinimumFetchIntervalInSeconds(3600) // Check every hour
                .build();
        remoteConfig.setConfigSettingsAsync(configSettings);
        remoteConfig.setDefaultsAsync(R.xml.remote_config_defaults);
    }

    public void checkForUpdates() {
        remoteConfig.fetchAndActivate()
                .addOnCompleteListener(activity, task -> {
                    if (task.isSuccessful()) {
                        long latestVersion = remoteConfig.getLong("latest_version_code");
                        int currentVersion = BuildConfig.VERSION_CODE;

                        if (latestVersion > currentVersion) {
                            showUpdateDialog(
                                    remoteConfig.getString("update_url"),
                                    remoteConfig.getBoolean("is_force_update")
                            );
                        }
                    } else {
                        Timber.e("Remote Config fetch failed");
                    }
                });
    }

    private void showUpdateDialog(final String updateUrl, boolean isForceUpdate) {
        AlertDialog.Builder builder = new AlertDialog.Builder(activity);
        View view = LayoutInflater.from(activity).inflate(R.layout.dialog_update, null);
        builder.setView(view);

        TextView btnUpdate = view.findViewById(R.id.btnUpdate);
        TextView btnLater = view.findViewById(R.id.btnLater);

        if (isForceUpdate) {
            btnLater.setVisibility(View.GONE);
            builder.setCancelable(false);
        }

        AlertDialog dialog = builder.create();

        btnUpdate.setOnClickListener(v -> {
            Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(updateUrl));
            activity.startActivity(intent);
            if (!isForceUpdate) dialog.dismiss();
        });

        btnLater.setOnClickListener(v -> dialog.dismiss());

        dialog.show();
    }
}
