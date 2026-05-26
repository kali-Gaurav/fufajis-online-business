# APK Distribution Folder

Use this folder for QR-code based APK distribution.

1. Build the production APK.
2. Copy the APK to this folder as:

```text
fufajis-online-release.apk
```

3. Upload `download.html` and the APK to Firebase Hosting, GitHub Pages, your website hosting, or another HTTPS server.
4. Generate one QR code for the hosted `download.html` URL.

Do not point printed QR codes directly to a changing APK filename. Keep the page URL stable and replace only the APK file when you release a new version.

